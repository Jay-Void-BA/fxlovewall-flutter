#!/usr/bin/env python3
"""Validate downloaded CI artifacts and assemble reviewable release assets."""

import argparse
from datetime import datetime, timezone
import hashlib
from pathlib import Path, PurePosixPath
import plistlib
import re
import shutil
import stat
import struct
import zipfile


ARM64 = 0x0100000C
BUNDLE_ID = "me.fxlove.campusWall"


def require(condition, message):
    if not condition:
        raise ValueError(message)


def checked_archive(path):
    archive = zipfile.ZipFile(path)
    try:
        names = archive.namelist()
        require(len(names) == len(set(names)), f"Duplicate archive entries: {path}")
        for name in names:
            member = PurePosixPath(name)
            require(
                bool(name) and not member.is_absolute() and ".." not in member.parts
                and "\\" not in name and not re.match(r"^[A-Za-z]:", name),
                f"Unsafe archive path in {path}: {name!r}",
            )
            info = archive.getinfo(name)
            if stat.S_ISLNK(info.external_attr >> 16):
                target = archive.read(name).decode("utf-8")
                target_path = PurePosixPath(target)
                require(bool(target) and not target_path.is_absolute() and "\\" not in target
                        and not re.match(r"^[A-Za-z]:", target),
                        f"Unsafe archive symlink in {path}: {name!r}")
                resolved = list(member.parent.parts)
                for part in target_path.parts:
                    if part == "..":
                        require(bool(resolved), f"Archive symlink escapes root: {name!r}")
                        resolved.pop()
                    elif part != ".":
                        resolved.append(part)
        bad = archive.testzip()
        require(bad is None, f"Archive CRC check failed in {path}: {bad}")
        return archive
    except Exception:
        archive.close()
        raise


def member_bytes(archive, name):
    data = archive.read(name)
    require(bool(data), f"Empty required archive member: {name}")
    return data


def is_arm64_macho(data):
    """Accept a thin arm64 image or a valid arm64 slice in a universal image."""
    if len(data) < 8:
        return False
    magic = data[:4]
    if magic in (b"\xcf\xfa\xed\xfe", b"\xfe\xed\xfa\xcf"):
        endian = "<" if magic == b"\xcf\xfa\xed\xfe" else ">"
        return len(data) >= 32 and struct.unpack_from(endian + "I", data, 4)[0] == ARM64
    fat_formats = {
        b"\xca\xfe\xba\xbe": (">", False),
        b"\xbe\xba\xfe\xca": ("<", False),
        b"\xca\xfe\xba\xbf": (">", True),
        b"\xbf\xba\xfe\xca": ("<", True),
    }
    if magic not in fat_formats:
        return False
    endian, fat64 = fat_formats[magic]
    count = struct.unpack_from(endian + "I", data, 4)[0]
    entry_size = 32 if fat64 else 20
    if not 0 < count <= 64 or 8 + count * entry_size > len(data):
        return False
    for index in range(count):
        position = 8 + index * entry_size
        cpu = struct.unpack_from(endian + "I", data, position)[0]
        offset, size = struct.unpack_from(endian + ("QQ" if fat64 else "II"), data, position + 8)
        if cpu == ARM64 and 0 < size and offset >= 8 + count * entry_size and offset + size <= len(data):
            return is_arm64_macho(data[offset:offset + size])
    return False


def check_app_info(info, version, build_number, platform):
    require(info.get("CFBundleIdentifier") == BUNDLE_ID, "Unexpected iOS bundle identifier")
    require(info.get("CFBundleShortVersionString") == version, "Unexpected iOS version")
    require(str(info.get("CFBundleVersion")) == build_number, "Unexpected iOS build number")
    require(info.get("DTPlatformName") == platform, f"Expected {platform} build")


def check_apk(path, abi):
    with checked_archive(path) as archive:
        member_bytes(archive, "AndroidManifest.xml")
        engine = member_bytes(archive, f"lib/{abi}/libflutter.so")
        require(engine[:4] == b"\x7fELF", f"Invalid Flutter engine ELF for {abi}")
        endian = "<" if engine[5] == 1 else ">"
        machine = struct.unpack_from(endian + "H", engine, 18)[0]
        expected = {"arm64-v8a": 183, "armeabi-v7a": 40, "x86_64": 62}[abi]
        require(machine == expected, f"Wrong native engine architecture for {abi}")


def check_ipa(path, version, build_number):
    prefix = "Payload/Runner.app/"
    with checked_archive(path) as archive:
        info = plistlib.loads(member_bytes(archive, prefix + "Info.plist"))
        check_app_info(info, version, build_number, "iphoneos")
        executable = info.get("CFBundleExecutable", "")
        require(bool(executable) and "/" not in executable and "\\" not in executable,
                "Invalid iOS executable name")
        program = member_bytes(archive, prefix + executable)
        require(is_arm64_macho(program), "iOS executable has no valid arm64 Mach-O image")
        for framework in ("Flutter", "App"):
            member_bytes(archive, prefix + f"Frameworks/{framework}.framework/{framework}")
        return b"UIGlassEffect" in program


def check_simulator(path, version, build_number):
    with checked_archive(path) as archive:
        info = plistlib.loads(member_bytes(archive, "Runner.app/Info.plist"))
        check_app_info(info, version, build_number, "iphonesimulator")


def checksum(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--artifacts", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--run-url", required=True)
    parser.add_argument("--commit", required=True)
    args = parser.parse_args()
    require(re.fullmatch(r"[0-9a-f]{40}", args.commit), "Expected a full Git commit SHA")
    require(re.fullmatch(r"https://github\.com/[\w.-]+/[\w.-]+/actions/runs/\d+", args.run_url),
            "Expected a GitHub Actions run URL")
    pubspec = Path(__file__).resolve().parents[1] / "pubspec.yaml"
    match = re.search(r"^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$", pubspec.read_text(), re.MULTILINE)
    require(match is not None, "Expected an explicit app version and build number in pubspec.yaml")
    version, build_number = match.groups()
    sources = []
    for abi in ("arm64-v8a", "armeabi-v7a", "x86_64"):
        apk = args.artifacts / "android-apks" / f"app-{abi}-release.apk"
        check_apk(apk, abi)
        sources.append((apk, f"fxwall-{version}-{abi}.apk"))
    ipa = args.artifacts / "ios-unsigned-ipa" / f"fxwall-{version}-unsigned.ipa"
    glass_symbol = check_ipa(ipa, version, build_number)
    sources.append((ipa, ipa.name))
    simulator = args.artifacts / "ios-simulator-app" / "ios-simulator.zip"
    check_simulator(simulator, version, build_number)
    sources.append((simulator, f"fxwall-{version}-ios-simulator.zip"))
    args.output.mkdir(parents=True, exist_ok=True)
    expected_names = {name for _, name in sources} | {"SHA256SUMS.txt", "CI_BUILD_REPORT.md"}
    require(not any(p.name not in expected_names for p in args.output.iterdir()),
            "Output directory contains unrelated files")
    assets = []
    for source, name in sources:
        destination = args.output / name
        require(source.resolve() != destination.resolve(), "Artifacts and release output must be separate")
        shutil.copyfile(source, destination)
        assets.append(destination)
    rows = "\n".join(f"| {p.name} | {p.stat().st_size} | `{checksum(p)}` |" for p in assets)
    report = (
        f"# {version}+{build_number} GitHub CI 构建记录\n\n"
        f"记录时间：{datetime.now(timezone.utc).isoformat()}\n\n"
        f"- 源码提交：`{args.commit}`\n"
        f"- 构建运行：{args.run_url}\n"
        "- Android、iOS 模拟器与 iOS 真机未签名 IPA 的构建任务已通过。\n"
        "- 所有发布 ZIP / APK / IPA 均通过 CRC 与归档路径检查。\n"
        "- Android APK 已检查清单和对应 ABI 的 Flutter 原生引擎。\n"
        f"- iOS 标识 `{BUNDLE_ID}`，版本 `{version}`，构建号 `{build_number}`；"
        "真机 IPA 包含有效 arm64 Mach-O 主程序及 Flutter / App 框架；模拟器平台标识已检查。\n"
        f"- iOS 主程序 UIGlassEffect 符号：{'已发现' if glass_symbol else '未发现（不代表已进行系统材质验证）'}。\n\n"
        "## 安装与验证范围\n\n"
        "Android 为使用 CI 测试密钥的 release 优化构建；该签名可能与旧下载包或其他 CI 运行不同，"
        "不能保证直接覆盖安装。正式更新应使用固定发行签名。\n\n"
        "iOS IPA 未签名，必须使用有效证书和相应配置签名后才能安装；模拟器包供 macOS / Xcode 使用。"
        "本记录验证编译与包结构，尚未完成 iPhone / iPad 真机性能、系统分享或 Liquid Glass 材质验证。\n\n"
        "## 文件\n\n| 文件 | 字节数 | SHA-256 |\n| --- | ---: | --- |\n"
        f"{rows}\n"
    )
    report_path = args.output / "CI_BUILD_REPORT.md"
    report_path.write_text(report, encoding="utf-8")
    assets.append(report_path)
    (args.output / "SHA256SUMS.txt").write_text(
        "".join(f"{checksum(p)}  {p.name}\n" for p in sorted(assets)), encoding="utf-8")
    print(f"Validated and prepared {len(assets)} assets plus SHA256SUMS.txt for {version}+{build_number}")


if __name__ == "__main__":
    main()

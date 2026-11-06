import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_color_utilities/material_color_utilities.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WallBackground { classic, dawn, forest, dusk, photo }

enum WallPalette { system, wallpaper, custom }

const appearanceBlue = Color(0xFF4268DB);

const backgroundGradients = <WallBackground, List<Color>>{
  WallBackground.dawn: [
    Color(0xFFF8DDD1),
    Color(0xFFEEDDF6),
    Color(0xFFD9E8FF),
  ],
  WallBackground.forest: [
    Color(0xFFD5E9DD),
    Color(0xFFD6E5EF),
    Color(0xFFF0EACD),
  ],
  WallBackground.dusk: [
    Color(0xFFE5DDF6),
    Color(0xFFDCC9E5),
    Color(0xFFF0D7DF),
  ],
};

const backgroundSeeds = <WallBackground, Color>{
  WallBackground.classic: appearanceBlue,
  WallBackground.dawn: Color(0xFFB77B97),
  WallBackground.forest: Color(0xFF527D68),
  WallBackground.dusk: Color(0xFF8B6DA9),
};

class AppearanceException implements Exception {
  final String message;
  const AppearanceException(this.message);
  @override
  String toString() => message;
}

/// A bounded PNG plus the source color selected by Material's Monet scorer.
class ProcessedBackground {
  final Uint8List png;
  final Color seed;
  const ProcessedBackground(this.png, this.seed);
}

typedef PhotoSelector = Future<XFile?> Function();
typedef BackgroundProcessor = Future<ProcessedBackground> Function(Uint8List);

/// Persistent appearance choices; only application-owned photos are managed.
class AppearanceSettings extends ChangeNotifier {
  static const preferenceKey = 'appearance.v1';
  final SharedPreferences _prefs;
  final PhotoSelector _selectPhoto;
  final Future<Directory> Function() _supportDirectory;
  final BackgroundProcessor _processImage;
  final Future<List<XFile>> Function() _retrieveLostPhotos;

  WallBackground _background = WallBackground.classic;
  WallPalette _palette = WallPalette.system;
  Color _customSeed = appearanceBlue;
  Color? _photoSeed;
  String? _photoName;
  String? _photoPath;
  double _overlay = .30;
  bool _importing = false;
  bool _disposed = false;
  int _generation = 0;
  Timer? _overlayTimer;
  Future<void> _saveQueue = Future<void>.value();

  AppearanceSettings(
    SharedPreferences prefs, {
    PhotoSelector? selectPhoto,
    Future<Directory> Function()? supportDirectory,
    BackgroundProcessor? processImage,
    Future<List<XFile>> Function()? retrieveLostPhotos,
  }) : _prefs = prefs,
       _selectPhoto = selectPhoto ?? _pickPhoto,
       _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
       _processImage = processImage ?? processBackgroundImage,
       _retrieveLostPhotos = retrieveLostPhotos ?? _recoverPicker {
    try {
      final raw = prefs.getString(preferenceKey);
      if (raw != null) {
        final decoded = jsonDecode(raw);
        if (decoded is! Map<String, dynamic>) throw const FormatException();
        _background = WallBackground.values.firstWhere(
          (v) => v.name == decoded['background'],
          orElse: () => WallBackground.classic,
        );
        _palette = WallPalette.values.firstWhere(
          (v) => v.name == decoded['palette'],
          orElse: () => WallPalette.system,
        );
        _customSeed = _readColor(decoded['customSeed']) ?? appearanceBlue;
        _photoSeed = _readColor(decoded['photoSeed']);
        final photoName = decoded['photoFile'];
        if (photoName is String && _validPhotoName(photoName)) {
          _photoName = photoName;
        }
        final overlay = decoded['overlay'];
        if (overlay is num && overlay.isFinite) {
          _overlay = overlay.toDouble().clamp(0, .8);
        }
        if (_background == WallBackground.photo && _photoName == null) {
          _background = WallBackground.classic;
          _photoSeed = null;
        }
        // Rewrite a sanitized snapshot, including unknown or corrupt fields.
        unawaited(_persist().catchError((Object _) {}));
      }
    } catch (_) {
      unawaited(_persist().catchError((Object _) {}));
    }
  }

  WallBackground get background => _background;
  WallPalette get palette => _palette;
  Color get customSeed => _customSeed;
  Color? get wallpaperSeed => _background == WallBackground.photo
      ? _photoSeed
      : backgroundSeeds[_background];
  Color get backgroundSeed => wallpaperSeed ?? appearanceBlue;
  String? get photoPath => _photoPath;
  double get overlay => _overlay;
  bool get importing => _importing;
  bool get hasBackground => _background != WallBackground.classic;

  static bool _validPhotoName(String name) =>
      RegExp(r'^background-[0-9]+\.png$').hasMatch(name);

  static Color? _readColor(Object? value) =>
      value is int && value >= 0 && value <= 0xFFFFFFFF
      ? Color(value | 0xFF000000)
      : null;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _persist() {
    final snapshot = jsonEncode({
      'background': _background.name,
      'palette': _palette.name,
      'customSeed': _customSeed.toARGB32(),
      'photoSeed': _photoSeed?.toARGB32(),
      'photoFile': _photoName,
      'overlay': _overlay,
    });
    final save = _saveQueue.catchError((Object _) {}).then((_) async {
      if (!await _prefs.setString(preferenceKey, snapshot)) {
        throw const AppearanceException('外观设置未能保存，请稍后重试。');
      }
    });
    _saveQueue = save;
    return save;
  }

  Future<void> setBackground(WallBackground value) async {
    if (value == WallBackground.photo && _photoName == null) {
      throw const AppearanceException('请先从相册选择一张背景图片。');
    }
    if (_background == value) return;
    _background = value;
    _changed();
    await _persist();
  }

  Future<void> setPalette(WallPalette value) async {
    if (_palette == value) return;
    _palette = value;
    _changed();
    await _persist();
  }

  Future<void> setCustomSeed(Color value) async {
    _customSeed = Color(value.toARGB32() | 0xFF000000);
    _changed();
    await _persist();
  }

  Future<void> setOverlay(double value) async {
    if (!value.isFinite) return;
    final next = value.clamp(0, .8).toDouble();
    if (_overlay == next) return;
    _overlay = next;
    _changed();
    _overlayTimer?.cancel();
    _overlayTimer = Timer(const Duration(milliseconds: 300), () {
      _overlayTimer = null;
      unawaited(_persist().catchError((Object _) {}));
    });
  }

  /// Flushes a pending slider change without waiting for the debounce timer.
  Future<void> flush() {
    if (_overlayTimer != null) {
      _overlayTimer?.cancel();
      _overlayTimer = null;
      return _persist();
    }
    return _saveQueue;
  }

  Future<Directory> _photoDirectory() async {
    final directory = await _supportDirectory();
    return Directory('${directory.path}${Platform.pathSeparator}appearance');
  }

  Future<void> _removePhoto(String? name) async {
    if (name == null || !_validPhotoName(name)) return;
    try {
      final directory = await _photoDirectory();
      final file = File('${directory.path}${Platform.pathSeparator}$name');
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Failure to remove an obsolete local file must not undo a new background.
    }
  }

  Future<bool> importPhoto() async {
    if (_importing || _disposed) return false;
    _importing = true;
    final generation = ++_generation;
    _changed();
    try {
      final selected = await _selectPhoto();
      if (selected == null || _disposed || generation != _generation) {
        return false;
      }
      return await _applyPhoto(selected, generation);
    } on AppearanceException {
      rethrow;
    } catch (_) {
      throw const AppearanceException('无法读取这张图片。请检查相册权限，或选择其他图片。');
    } finally {
      _importing = false;
      _changed();
    }
  }

  Future<bool> _applyPhoto(XFile selected, int generation) async {
    String? newName;
    File? temporary;
    try {
      final processed = await _processImage(await selected.readAsBytes());
      if (_disposed || generation != _generation) return false;
      if (processed.png.isEmpty) {
        throw const AppearanceException('图片内容为空，请重新选择。');
      }
      final directory = await _photoDirectory();
      await directory.create(recursive: true);
      newName = 'background-${DateTime.now().microsecondsSinceEpoch}.png';
      final destination = File(
        '${directory.path}${Platform.pathSeparator}$newName',
      );
      temporary = File('${destination.path}.tmp');
      await temporary.writeAsBytes(processed.png, flush: true);
      await temporary.rename(destination.path);
      temporary = null;
      if (_disposed || generation != _generation) {
        await _removePhoto(newName);
        return false;
      }
      final oldName = _photoName;
      final oldPath = _photoPath;
      final oldSeed = _photoSeed;
      final oldBackground = _background;
      _photoName = newName;
      _photoPath = destination.path;
      _photoSeed = Color(processed.seed.toARGB32() | 0xFF000000);
      _background = WallBackground.photo;
      try {
        await _persist();
      } catch (_) {
        _photoName = oldName;
        _photoPath = oldPath;
        _photoSeed = oldSeed;
        _background = oldBackground;
        rethrow;
      }
      _changed();
      await _removePhoto(oldName);
      return true;
    } catch (_) {
      if (newName != null && _photoName != newName) await _removePhoto(newName);
      try {
        if (temporary != null && await temporary.exists()) {
          await temporary.delete();
        }
      } catch (_) {}
      rethrow;
    }
  }

  /// Resolve the relative photo filename after startup, then recover an Android
  /// picker result if the OS destroyed the app while the gallery was open.
  Future<void> recoverLostPhoto() async {
    if (_importing || _disposed) return;
    _importing = true;
    final generation = ++_generation;
    _changed();
    try {
      final name = _photoName;
      if (name != null) {
        final directory = await _photoDirectory();
        final file = File('${directory.path}${Platform.pathSeparator}$name');
        final exists = await file.exists();
        if (_disposed || generation != _generation) return;
        if (exists) {
          _photoPath = file.path;
        } else {
          _photoName = null;
          _photoPath = null;
          _photoSeed = null;
          if (_background == WallBackground.photo) {
            _background = WallBackground.classic;
          }
          await _persist();
        }
        _changed();
      }
      final lost = await _retrieveLostPhotos();
      if (lost.isNotEmpty && !_disposed && generation == _generation) {
        await _applyPhoto(lost.first, generation);
      }
    } on AppearanceException {
      rethrow;
    } catch (_) {
      throw const AppearanceException('暂时无法恢复背景图片，请重新选择。');
    } finally {
      _importing = false;
      _changed();
    }
  }

  Future<void> clearPhoto() async {
    _generation++;
    final oldName = _photoName;
    _photoName = null;
    _photoPath = null;
    _photoSeed = null;
    if (_background == WallBackground.photo) {
      _background = WallBackground.classic;
    }
    _changed();
    await _persist();
    await _removePhoto(oldName);
  }

  Future<void> restoreDefaults() async {
    _generation++;
    _overlayTimer?.cancel();
    _overlayTimer = null;
    final oldName = _photoName;
    _photoName = null;
    _photoPath = null;
    _photoSeed = null;
    _background = WallBackground.classic;
    _palette = WallPalette.system;
    _customSeed = appearanceBlue;
    _overlay = .30;
    _changed();
    await _persist();
    await _removePhoto(oldName);
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    unawaited(flush().catchError((Object _) {}));
    super.dispose();
  }
}

Future<XFile?> _pickPhoto() => ImagePicker().pickImage(
  source: ImageSource.gallery,
  maxWidth: 2048,
  maxHeight: 2048,
  imageQuality: 90,
  requestFullMetadata: false,
);

Future<List<XFile>> _recoverPicker() async {
  if (!Platform.isAndroid) return [];
  final response = await ImagePicker().retrieveLostData();
  if (response.exception != null) {
    throw const AppearanceException('相册选择未完成，请重新选择背景图片。');
  }
  return response.files ?? [];
}

/// Decode once to a bounded image and strip metadata by writing a private PNG.
Future<ProcessedBackground> processBackgroundImage(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final codec = await ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) {
      final scale = math.min(1.0, 1600 / math.max(width, height));
      return ui.TargetImageSize(
        width: math.max(1, (width * scale).round()),
        height: math.max(1, (height * scale).round()),
      );
    },
  );
  ui.Image? image;
  ui.Image? sample;
  ui.Picture? picture;
  try {
    image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw const AppearanceException('这张图片无法转换为背景。');
    final sampleScale = math.min(
      1.0,
      112 / math.max(image.width, image.height),
    );
    final sampleWidth = math.max(1, (image.width * sampleScale).round());
    final sampleHeight = math.max(1, (image.height * sampleScale).round());
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromLTWH(0, 0, sampleWidth.toDouble(), sampleHeight.toDouble()),
      Paint()..filterQuality = FilterQuality.low,
    );
    picture = recorder.endRecording();
    sample = await picture.toImage(sampleWidth, sampleHeight);
    final rgba = await sample.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (rgba == null) throw const AppearanceException('暂时无法提取图片颜色。');
    final seed = await compute(_sourceColorFromRgba, rgba.buffer.asUint8List());
    return ProcessedBackground(png.buffer.asUint8List(), Color(seed));
  } finally {
    sample?.dispose();
    picture?.dispose();
    image?.dispose();
    codec.dispose();
  }
}

Future<int> _sourceColorFromRgba(Uint8List rgba) async {
  final colors = <int>[];
  for (var i = 0; i + 3 < rgba.length; i += 4) {
    if (rgba[i + 3] < 128) continue;
    colors.add(0xFF000000 | rgba[i] << 16 | rgba[i + 1] << 8 | rgba[i + 2]);
  }
  if (colors.isEmpty) return appearanceBlue.toARGB32();
  final result = await QuantizerCelebi().quantize(colors, 128);
  return Score.score(
    result.colorToCount,
    desired: 1,
    fallbackColorARGB: appearanceBlue.toARGB32(),
  ).first;
}

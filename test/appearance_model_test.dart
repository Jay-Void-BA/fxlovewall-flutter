import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:campus_wall/data/appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory support;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    support = await Directory.systemTemp.createTemp('wall-appearance-test-');
  });

  tearDown(() async {
    if (await support.exists()) await support.delete(recursive: true);
  });

  AppearanceSettings settings({
    PhotoSelector? select,
    BackgroundProcessor? process,
    Future<List<XFile>> Function()? lost,
  }) => AppearanceSettings(
    prefs,
    selectPhoto: select ?? () async => null,
    supportDirectory: () async => support,
    processImage:
        process ?? (bytes) async => ProcessedBackground(bytes, Colors.green),
    retrieveLostPhotos: lost ?? () async => [],
  );

  XFile image([int value = 1]) => XFile.fromData(
    Uint8List.fromList([value, 2, 3]),
    name: 'selected.jpg',
    mimeType: 'image/jpeg',
  );

  test(
    'malformed stored fields are repaired and cannot select arbitrary files',
    () async {
      await prefs.setString(
        AppearanceSettings.preferenceKey,
        jsonEncode({
          'background': 'photo',
          'palette': 'unknown',
          'customSeed': 'invalid',
          'photoSeed': -1,
          'photoFile': '../private.txt',
          'overlay': 80,
        }),
      );
      final state = settings();
      addTearDown(state.dispose);
      expect(state.background, WallBackground.classic);
      expect(state.palette, WallPalette.system);
      expect(state.customSeed, appearanceBlue);
      expect(state.photoPath, isNull);
      expect(state.overlay, .8);
      await state.flush();
      final stored = jsonDecode(
        prefs.getString(AppearanceSettings.preferenceKey)!,
      );
      expect(stored['photoFile'], isNull);
      expect(stored['background'], 'classic');
      await prefs.setInt(AppearanceSettings.preferenceKey, 17);
      final wrongType = settings();
      addTearDown(wrongType.dispose);
      await wrongType.flush();
      expect(wrongType.background, WallBackground.classic);
    },
  );

  test(
    'built-in wallpaper seed and appearance choices survive restart',
    () async {
      final state = settings();
      await state.setBackground(WallBackground.forest);
      await state.setPalette(WallPalette.wallpaper);
      await state.setCustomSeed(const Color(0xFFAD5A72));
      await state.setOverlay(.58);
      await state.flush();
      final restored = settings();
      addTearDown(restored.dispose);
      state.dispose();
      expect(restored.background, WallBackground.forest);
      expect(restored.hasBackground, isTrue);
      expect(restored.backgroundSeed, backgroundSeeds[WallBackground.forest]);
      expect(restored.palette, WallPalette.wallpaper);
      expect(restored.customSeed, const Color(0xFFAD5A72));
      expect(restored.overlay, .58);
      expect(backgroundGradients[WallBackground.forest], hasLength(3));
    },
  );

  test(
    'photo import uses a private copy and replacement removes the prior copy',
    () async {
      final state = settings(select: () async => image());
      addTearDown(state.dispose);
      expect(await state.importPhoto(), isTrue);
      final first = state.photoPath!;
      expect(
        File(first).parent.path,
        '${support.path}${Platform.pathSeparator}appearance',
      );
      expect(await File(first).readAsBytes(), [1, 2, 3]);
      expect(state.background, WallBackground.photo);
      expect(state.backgroundSeed.toARGB32(), Colors.green.toARGB32());
      final stored = jsonDecode(
        prefs.getString(AppearanceSettings.preferenceKey)!,
      );
      expect(stored['photoFile'], matches(r'^background-\d+\.png$'));
      expect(stored.toString(), isNot(contains(support.path)));
      expect(await state.importPhoto(), isTrue);
      expect(state.photoPath, isNot(first));
      expect(await File(first).exists(), isFalse);
      expect(await File(state.photoPath!).exists(), isTrue);
      expect(
        (await Directory('${support.path}/appearance').list().toList()),
        hasLength(1),
      );
    },
  );

  test(
    'cancelled or unreadable photo preserves the previous background and palette',
    () async {
      final original = settings(select: () async => image());
      expect(await original.importPhoto(), isTrue);
      await original.setPalette(WallPalette.wallpaper);
      final path = original.photoPath!;
      final previous = prefs.getString(AppearanceSettings.preferenceKey);
      original.dispose();

      final cancelled = settings();
      addTearDown(cancelled.dispose);
      await cancelled.recoverLostPhoto();
      expect(await cancelled.importPhoto(), isFalse);
      expect(cancelled.photoPath, path);
      expect(prefs.getString(AppearanceSettings.preferenceKey), previous);

      final failed = settings(
        select: () async => image(),
        process: (_) async => throw const FormatException('invalid image'),
      );
      addTearDown(failed.dispose);
      await failed.recoverLostPhoto();
      await expectLater(
        failed.importPhoto(),
        throwsA(isA<AppearanceException>()),
      );
      expect(failed.background, WallBackground.photo);
      expect(failed.palette, WallPalette.wallpaper);
      expect(failed.photoPath, path);
      expect(await File(path).exists(), isTrue);
      expect(failed.importing, isFalse);
      expect(prefs.getString(AppearanceSettings.preferenceKey), previous);
    },
  );

  test(
    'photo filenames restore against the current sandbox and missing files fall back',
    () async {
      final initial = settings(select: () async => image());
      await initial.importPhoto();
      final previousPath = initial.photoPath!;
      final newSupport = await Directory.systemTemp.createTemp(
        'wall-new-sandbox-',
      );
      addTearDown(() => newSupport.delete(recursive: true));
      final copiedDirectory = Directory('${newSupport.path}/appearance');
      await copiedDirectory.create();
      final basename = File(previousPath).uri.pathSegments.last;
      await File(previousPath).copy('${copiedDirectory.path}/$basename');
      initial.dispose();
      final restored = AppearanceSettings(
        prefs,
        supportDirectory: () async => newSupport,
        retrieveLostPhotos: () async => [],
      );
      addTearDown(restored.dispose);
      expect(restored.photoPath, isNull);
      await restored.recoverLostPhoto();
      expect(restored.photoPath, '${copiedDirectory.path}/$basename');
      expect(restored.background, WallBackground.photo);
      await File(restored.photoPath!).delete();
      await restored.recoverLostPhoto();
      expect(restored.background, WallBackground.classic);
      expect(restored.photoPath, isNull);
      expect(
        jsonDecode(
          prefs.getString(AppearanceSettings.preferenceKey)!,
        )['photoFile'],
        isNull,
      );
    },
  );

  test(
    'lost picker results are imported once and concurrent selection is ignored',
    () async {
      final pending = Completer<XFile?>();
      var selections = 0;
      final state = settings(
        select: () {
          selections++;
          return pending.future;
        },
      );
      final first = state.importPhoto();
      expect(state.importing, isTrue);
      expect(await state.importPhoto(), isFalse);
      pending.complete(image());
      expect(await first, isTrue);
      expect(selections, 1);
      expect(state.importing, isFalse);
      state.dispose();
      var recoveries = 0;
      final recovered = settings(
        lost: () async {
          recoveries++;
          return [image(7)];
        },
      );
      addTearDown(recovered.dispose);
      await recovered.recoverLostPhoto();
      expect(recoveries, 1);
      expect(await File(recovered.photoPath!).readAsBytes(), [7, 2, 3]);
    },
  );

  test(
    'removing photo and restoring defaults clean private data without changing palette unexpectedly',
    () async {
      final state = settings(select: () async => image());
      addTearDown(state.dispose);
      await state.importPhoto();
      final path = state.photoPath!;
      await state.setPalette(WallPalette.custom);
      await state.setCustomSeed(Colors.orange);
      await state.clearPhoto();
      expect(await File(path).exists(), isFalse);
      expect(state.background, WallBackground.classic);
      expect(state.palette, WallPalette.custom);
      expect(state.customSeed.toARGB32(), Colors.orange.toARGB32());
      await state.setOverlay(.7);
      await state.restoreDefaults();
      expect(state.palette, WallPalette.system);
      expect(state.customSeed, appearanceBlue);
      expect(state.overlay, .30);
      expect(state.photoPath, isNull);
      await state.flush();
      final restored = settings();
      addTearDown(restored.dispose);
      expect(restored.overlay, .30);
      expect(restored.background, WallBackground.classic);
    },
  );

  test(
    'real image processing bounds dimensions and extracts a source color',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 2000, 1000),
        Paint()..color = const Color(0xFFFF0000),
      );
      final picture = recorder.endRecording();
      final inputImage = await picture.toImage(2000, 1000);
      final input = await inputImage.toByteData(format: ui.ImageByteFormat.png);
      final processed = await processBackgroundImage(
        input!.buffer.asUint8List(),
      );
      final codec = await ui.instantiateImageCodec(processed.png);
      final outputImage = (await codec.getNextFrame()).image;
      expect(outputImage.width, 1600);
      expect(outputImage.height, 800);
      expect(processed.seed.r, greaterThan(.85));
      expect(processed.seed.g, lessThan(.25));
      expect(processed.seed.b, lessThan(.25));
      outputImage.dispose();
      codec.dispose();
      inputImage.dispose();
      picture.dispose();
    },
  );
}

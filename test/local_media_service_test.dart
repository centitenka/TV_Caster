import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hisense_caster/services/local_media_service.dart';

void main() {
  late Directory tempRoot;
  late Directory managedDir;
  late Directory sourceDir;
  late LocalMediaService service;

  String joinPath(String a, String b) {
    if (a.endsWith(Platform.pathSeparator)) return '$a$b';
    return '$a${Platform.pathSeparator}$b';
  }

  setUp(() async {
    tempRoot =
        await Directory.systemTemp.createTemp('local_media_service_test_');
    managedDir = Directory(joinPath(tempRoot.path, 'managed_media'));
    sourceDir = Directory(joinPath(tempRoot.path, 'source'));
    await sourceDir.create(recursive: true);
    service = LocalMediaService(
      managedDirectoryProvider: () async => managedDir,
    );
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  test('importFile should copy source file and return file URI', () async {
    final source = File(joinPath(sourceDir.path, 'clip.mp4'));
    await source.writeAsBytes(List<int>.generate(256, (i) => i % 255));

    final result = await service.importFile(sourcePath: source.path);
    final importedUri = Uri.parse(result.fileUri);
    final importedFile = File.fromUri(importedUri);

    expect(importedUri.scheme, 'file');
    expect(await importedFile.exists(), isTrue);
    expect(await importedFile.length(), 256);
    expect(result.displayName.toLowerCase().contains('.mp4'), isTrue);
    expect(importedFile.path.contains('managed_media'), isTrue);
  });

  test('importFile should keep unique target names for same source file',
      () async {
    final source = File(joinPath(sourceDir.path, 'same-name.mkv'));
    await source.writeAsBytes(List<int>.filled(64, 7));

    final first = await service.importFile(sourcePath: source.path);
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final second = await service.importFile(sourcePath: source.path);

    expect(first.fileUri, isNot(second.fileUri));
    expect(await File.fromUri(Uri.parse(first.fileUri)).exists(), isTrue);
    expect(await File.fromUri(Uri.parse(second.fileUri)).exists(), isTrue);
  });

  test('deleteManagedLocalFileByUri should only delete managed directory files',
      () async {
    final source = File(joinPath(sourceDir.path, 'delete-me.mp4'));
    await source.writeAsBytes(List<int>.filled(32, 1));

    final imported = await service.importFile(sourcePath: source.path);
    final importedFile = File.fromUri(Uri.parse(imported.fileUri));

    final external = File(joinPath(sourceDir.path, 'outside.mp4'));
    await external.writeAsBytes(List<int>.filled(32, 2));

    await service.deleteManagedLocalFileByUri(imported.fileUri);
    await service
        .deleteManagedLocalFileByUri(Uri.file(external.path).toString());

    expect(await importedFile.exists(), isFalse);
    expect(await external.exists(), isTrue);
  });
}

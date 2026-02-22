import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class LocalImportResult {
  final String fileUri;
  final String displayName;
  final int sizeBytes;
  final String mimeType;

  const LocalImportResult({
    required this.fileUri,
    required this.displayName,
    required this.sizeBytes,
    required this.mimeType,
  });
}

class LocalMediaService {
  LocalMediaService({
    Future<Directory> Function()? managedDirectoryProvider,
  }) : _managedDirectoryProvider = managedDirectoryProvider;

  final Future<Directory> Function()? _managedDirectoryProvider;
  final ImagePicker _imagePicker = ImagePicker();

  static const List<String> _videoExtensions = [
    'mp4',
    'mkv',
    'mov',
    'm4v',
    'webm',
    'avi',
    'flv',
    'ts',
    'm2ts',
    'm3u8',
  ];

  Future<LocalImportResult?> pickFromGalleryAndImport() async {
    final file = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (file == null) return null;

    return importFile(
      sourcePath: file.path,
      originalName: file.name,
      mimeType: _detectMimeType(file.path),
    );
  }

  Future<LocalImportResult?> pickFromFileManagerAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: _videoExtensions,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final picked = result.files.first;
    final path = picked.path;
    if (path == null || path.isEmpty) return null;

    return importFile(
      sourcePath: path,
      originalName: picked.name,
      mimeType: _detectMimeType(path),
    );
  }

  Future<LocalImportResult> importFile({
    required String sourcePath,
    String? originalName,
    String? mimeType,
  }) async {
    final sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw Exception('源文件不存在');
    }

    if (!_isSupportedVideoPath(sourcePath)) {
      throw Exception('仅支持视频文件');
    }

    final managedDir = await _getManagedDirectory();
    await managedDir.create(recursive: true);

    final sourceName = (originalName == null || originalName.trim().isEmpty)
        ? _basename(sourcePath)
        : originalName.trim();
    final safeName = _sanitizeFileName(sourceName);
    final targetName =
        '${DateTime.now().microsecondsSinceEpoch}_${safeName.isEmpty ? 'video.mp4' : safeName}';
    final targetPath = _joinPath(managedDir.path, targetName);
    final copied = await sourceFile.copy(targetPath);

    return LocalImportResult(
      fileUri: Uri.file(copied.path).toString(),
      displayName: safeName.isEmpty ? '本地视频' : safeName,
      sizeBytes: await copied.length(),
      mimeType: mimeType ?? _detectMimeType(copied.path),
    );
  }

  Future<void> deleteManagedLocalFileByUri(String fileUri) async {
    final uri = Uri.tryParse(fileUri);
    if (uri == null || uri.scheme != 'file') return;

    final file = File.fromUri(uri);
    final managedDir = await _getManagedDirectory();
    if (!_isInsideDirectory(file.path, managedDir.path)) return;

    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _getManagedDirectory() async {
    if (_managedDirectoryProvider != null) {
      return _managedDirectoryProvider!();
    }
    final appDir = await getApplicationDocumentsDirectory();
    return Directory(_joinPath(appDir.path, 'local_media'));
  }

  bool _isSupportedVideoPath(String path) {
    final lower = path.toLowerCase();
    return _videoExtensions.any((ext) => lower.endsWith('.$ext'));
  }

  bool _isInsideDirectory(String childPath, String directoryPath) {
    final normalizedDirectory = _normalizePath(directoryPath);
    final normalizedChild = _normalizePath(childPath);
    if (normalizedChild == normalizedDirectory) return true;
    return normalizedChild.startsWith('$normalizedDirectory/');
  }

  String _normalizePath(String path) {
    var normalized = path.replaceAll('\\', '/');
    while (normalized.contains('//')) {
      normalized = normalized.replaceAll('//', '/');
    }
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return File(normalized).absolute.path.replaceAll('\\', '/');
  }

  String _sanitizeFileName(String name) {
    final noSlash = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return noSlash.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _basename(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    if (segments.isEmpty) return path;
    return segments.last;
  }

  String _joinPath(String first, String second) {
    if (first.endsWith(Platform.pathSeparator)) {
      return '$first$second';
    }
    return '$first${Platform.pathSeparator}$second';
  }

  String _detectMimeType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.m3u8')) return 'application/vnd.apple.mpegurl';
    if (lower.endsWith('.mp4') || lower.endsWith('.m4v')) return 'video/mp4';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.flv')) return 'video/x-flv';
    if (lower.endsWith('.ts') || lower.endsWith('.m2ts')) return 'video/mp2t';
    return 'application/octet-stream';
  }
}

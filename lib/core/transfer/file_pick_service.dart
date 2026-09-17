/// 系统文件选择器的薄包装；读入有界，避免整块加载超大文件。
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

const maxImportFileBytes = 10 * 1024 * 1024;

class ImportFile {
  const ImportFile({
    required this.name,
    required this.size,
    required this.readBytes,
  });

  final String name;

  /// -1 表示文件提供者未报告大小，仍会在流读取时检查上限。
  final int size;
  final Future<List<int>> Function() readBytes;
}

class ImportFileException implements Exception {
  const ImportFileException(this.message);
  final String message;
}

class FilePickService {
  const FilePickService();

  Future<List<ImportFile>?> pickFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json', 'md'],
      allowMultiple: true,
      withReadStream: true,
    );
    if (result == null || result.files.isEmpty) return null;
    return [
      for (final file in result.files)
        ImportFile(
          name: file.name,
          size: file.size,
          readBytes: () {
            final stream = file.readStream;
            if (stream == null) {
              throw const ImportFileException('无法读取文件，请重新选择');
            }
            return readBoundedImportBytes(stream);
          },
        ),
    ];
  }
}

/// 同时保护未知文件大小与选择后大小发生变化的情况。
Future<List<int>> readBoundedImportBytes(Stream<List<int>> stream) async {
  final bytes = BytesBuilder(copy: false);
  await for (final chunk in stream) {
    if (bytes.length + chunk.length > maxImportFileBytes) {
      throw const ImportFileException('文件超过 10 MB');
    }
    bytes.add(chunk);
  }
  return bytes.takeBytes();
}

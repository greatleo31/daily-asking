class MigrationPackage {
  const MigrationPackage();

  static const prefix = 'DA1.';
  static const maxEntries = 2000;
  static const maxPayloadLength = 2 * 1024 * 1024;

  bool looksLikeDailyAskingPackage(String value) {
    return value.startsWith(prefix) && value.length <= maxPayloadLength;
  }

  void validateDryRun({required int entryCount, required int payloadLength}) {
    if (entryCount < 0 || entryCount > maxEntries) {
      throw const MigrationPackageException('迁移包记录数异常');
    }
    if (payloadLength <= prefix.length || payloadLength > maxPayloadLength) {
      throw const MigrationPackageException('迁移包大小异常');
    }
  }
}

class MigrationPackageException implements Exception {
  const MigrationPackageException(this.message);

  final String message;

  @override
  String toString() => message;
}

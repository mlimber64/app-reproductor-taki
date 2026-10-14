/// How much disk a piece of app-owned storage is using.
class StorageUsage {
  const StorageUsage({required this.bytes, required this.fileCount})
      : assert(bytes >= 0),
        assert(fileCount >= 0);

  static const StorageUsage empty = StorageUsage(bytes: 0, fileCount: 0);

  final int bytes;
  final int fileCount;

  bool get isEmpty => fileCount == 0;

  @override
  bool operator ==(Object other) =>
      other is StorageUsage &&
      other.bytes == bytes &&
      other.fileCount == fileCount;

  @override
  int get hashCode => Object.hash(StorageUsage, bytes, fileCount);
}

// Web implementation - File operations are not supported
import 'dart:typed_data';

class FileHelper {
  static dynamic createFile(String path) {
    throw UnsupportedError('File operations not supported on web');
  }

  static Uint8List? getFileBytes(dynamic file) {
    return null;
  }
}

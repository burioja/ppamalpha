// Mobile/Desktop implementation - File operations supported
import 'dart:io';
import 'dart:typed_data';

class FileHelper {
  static File createFile(String path) {
    return File(path);
  }

  static Uint8List? getFileBytes(File file) {
    return file.readAsBytesSync();
  }
}

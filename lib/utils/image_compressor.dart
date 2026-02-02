import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class ImageCompressor {
  /// Compresses an image file to a target quality (default 75%).
  /// Also resizes it if it exceeds minWidth/minHeight (1920x1080).
  static Future<File> compress(File file) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final path = tempDir.path;
      final name = "compressed_${DateTime.now().millisecondsSinceEpoch}.jpg";
      final targetPath = "$path/$name";

      final XFile? result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: 75, // Good balance of size vs quality
        minWidth: 1920, // Resize 4K images down to 1080p
        minHeight: 1080,
      );

      if (result == null) {
        // If compression fails, return the original file as fallback
        return file;
      }

      return File(result.path);
    } catch (e) {
      // If error (e.g. file type not supported), return original
      return file;
    }
  }
}
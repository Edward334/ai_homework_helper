import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class ImageToBase64 {
  static Future<String> convert(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', imagePath);
    }
    final bytes = await file.readAsBytes();
    final String base64Image = base64Encode(bytes);

    // Determine the MIME type based on the file extension
    String mimeType;
    final String extension = p.extension(imagePath).toLowerCase();
    switch (extension) {
      case '.png':
        mimeType = 'image/png';
        break;
      case '.jpg':
      case '.jpeg':
        mimeType = 'image/jpeg';
        break;
      case '.gif':
        mimeType = 'image/gif';
        break;
      case '.webp':
        mimeType = 'image/webp';
        break;
      default:
        // Default to jpeg if unknown, or throw an error if strict
        mimeType = 'image/jpeg';
        break;
    }

    return 'data:$mimeType;base64,$base64Image';
  }
}
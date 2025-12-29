import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as img;

class ImageToBase64 {
  static Future<String> convert(String imagePath) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw FileSystemException('File not found', imagePath);
    }
    Uint8List bytes = Uint8List.fromList(await file.readAsBytes());

    String mimeType;
    final String extension = p.extension(imagePath).toLowerCase();

    if (extension == '.webp') {
      // Decode WebP image
      img.Image? image = img.decodeWebP(bytes);
      if (image != null) {
        // Encode to PNG
        bytes = img.encodePng(image);
        mimeType = 'image/png';
      } else {
        throw Exception('Failed to decode WebP image');
      }
    } else {
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
        default:
          // Default to jpeg if unknown, or throw an error if strict
          mimeType = 'image/jpeg';
          break;
      }
    }

    final String base64Image = base64Encode(bytes);
    return 'data:$mimeType;base64,$base64Image';
  }
}
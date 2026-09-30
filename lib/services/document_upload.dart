import 'dart:convert';
import 'package:file_picker/file_picker.dart';

class DocumentUpload {
  static Future<Map<String, dynamic>?> pick({bool imageOnly = false}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: imageOnly
          ? ['jpg', 'jpeg', 'png', 'webp']
          : ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
      withData: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > 10 * 1024 * 1024 || file.bytes == null || file.size == 0) {
      throw Exception('Choose a non-empty file up to 10 MB.');
    }
    final mime = {
      'pdf': 'application/pdf',
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp'
    }[file.extension?.toLowerCase()];
    if (mime == null) throw Exception('Choose a PDF, JPEG, PNG or WEBP file.');
    return {
      'fileName': file.name,
      'mimeType': mime,
      'fileBase64': base64Encode(file.bytes!)
    };
  }
}

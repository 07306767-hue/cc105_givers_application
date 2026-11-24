import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

class CloudinaryImageService {
  CloudinaryImageService({ImagePicker? picker})
    : _picker = picker ?? ImagePicker();

  static const _cloudName = 'b0od8eqc';
  static const _uploadPreset = 'q4jxt4ce';
  static final _client = http.Client();

  final ImagePicker _picker;

  Future<String?> pickAndUploadImage() async {
    final image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return null;

    final request = http.MultipartRequest(
      'POST',
      Uri.https('api.cloudinary.com', '/v1_1/$_cloudName/image/upload'),
    );
    request.fields['upload_preset'] = _uploadPreset;
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        await image.readAsBytes(),
        filename: image.name,
        contentType: MediaType.parse(_contentType(image)),
      ),
    );

    final streamedResponse = await _client
        .send(request)
        .timeout(const Duration(minutes: 2));
    final response = await http.Response.fromStream(streamedResponse);
    final body = jsonDecode(response.body);

    if (body is! Map<String, dynamic>) {
      throw const FormatException('Cloudinary returned an invalid response.');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = body['error'];
      final message = error is Map<String, dynamic>
          ? error['message'] as String?
          : null;
      throw Exception(message ?? 'Cloudinary upload failed.');
    }

    final secureUrl = body['secure_url'];
    if (secureUrl is! String || secureUrl.isEmpty) {
      throw const FormatException('Cloudinary did not return an image URL.');
    }
    return secureUrl;
  }

  String _contentType(XFile image) {
    if (image.mimeType != null && image.mimeType!.startsWith('image/')) {
      return image.mimeType!;
    }

    switch (image.name.split('.').last.toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

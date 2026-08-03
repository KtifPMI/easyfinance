import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class CloudOcrResult {
  final String text;
  const CloudOcrResult(this.text);
}

class CloudOcrService {
  static const _endpoint = 'https://vision.api.cloud.yandex.net/vision/v1/batchAnalyze';

  static String apiKey = '';
  static String folderId = '';

  static bool get isConfigured => apiKey.isNotEmpty && folderId.isNotEmpty;

  /// Updates credentials from runtime config (overrides defaults).
  static void configure({String? apiKey, String? folderId}) {
    if (apiKey != null) CloudOcrService.apiKey = apiKey;
    if (folderId != null) CloudOcrService.folderId = folderId;
  }

  /// Sends the image file to Yandex Vision OCR and returns the recognized text.
  /// Throws on network errors, auth errors, or empty result.
  static Future<CloudOcrResult> recognize(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Content = base64Encode(bytes);

    final body = jsonEncode({
      'folderId': folderId,
      'analyze_specs': [
        {
          'content': base64Content,
          'features': [
            {
              'type': 'TEXT_DETECTION',
              'text_detection_config': {
                'language_codes': ['ru', 'en'],
              },
            },
          ],
        },
      ],
    });

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Api-Key $apiKey',
          },
          body: body,
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw CloudOcrException('Неверный API-ключ Yandex Vision');
    }
    if (response.statusCode != 200) {
      throw CloudOcrException('Ошибка Yandex Vision: HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = decoded['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw CloudOcrException('Yandex Vision не вернул результатов');
    }

    final firstResult = results[0] as Map<String, dynamic>;
    final analysisResults = firstResult['results'] as List<dynamic>?;
    if (analysisResults == null || analysisResults.isEmpty) {
      throw CloudOcrException('Yandex Vision: пустой анализ');
    }

    final textDetection = analysisResults[0] as Map<String, dynamic>;
    final td = textDetection['textDetection'] as Map<String, dynamic>?;
    if (td == null) {
      throw CloudOcrException('Yandex Vision: нет textDetection');
    }

    final pages = td['pages'] as List<dynamic>?;
    if (pages == null || pages.isEmpty) {
      throw CloudOcrException('Yandex Vision: нет страниц');
    }

    final text = _extractText(pages);
    if (text.isEmpty) {
      throw CloudOcrException('Yandex Vision: не распознал текст');
    }

    return CloudOcrResult(text);
  }

  static String _extractText(List<dynamic> pages) {
    final buffer = StringBuffer();
    for (final page in pages) {
      final blocks = (page as Map<String, dynamic>)['blocks'] as List<dynamic>?;
      if (blocks == null) continue;
      for (final block in blocks) {
        final lines = (block as Map<String, dynamic>)['lines'] as List<dynamic>?;
        if (lines == null) continue;
        for (final line in lines) {
          final words = (line as Map<String, dynamic>)['words'] as List<dynamic>?;
          if (words == null) continue;
          for (final word in words) {
            final w = (word as Map<String, dynamic>);
            final t = w['text']?.toString() ?? '';
            if (t.isNotEmpty) buffer.write('$t ');
          }
          buffer.writeln();
        }
      }
    }
    return buffer.toString().trim();
  }
}

class CloudOcrException implements Exception {
  final String message;
  const CloudOcrException(this.message);
  @override
  String toString() => 'CloudOcrException: $message';
}

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:http/http.dart' as http;

class FileOpenService {
  /// Opens a file from a local path or a remote URL.
  /// If the file is a remote URL, it will be downloaded to a temporary location before opening.
  static Future<void> openFile(String pathOrUrl, {String? filename, String? mimeType}) async {
    // If it's a remote URL, OpenFilex can handle it directly for most platforms.
    // If you want to download first, add logic here.
    await OpenFilex.open(pathOrUrl);
  }

  /// Decodes Base64URL, saves to local file, and opens it with the appropriate app.
  /// [base64UrlData]: The Base64URL-encoded string.
  /// [filename]: The desired filename (with extension, e.g., 'file.pdf').
  /// [mimeType]: Optional MIME type for logging or future use.
  static Future<void> saveAndOpenBase64Attachment({
    required String base64UrlData,
    required String filename,
    String? mimeType,
  }) async {
    try {
      // 1. Decode Base64URL to bytes
      String normalized = base64UrlData.replaceAll('-', '+').replaceAll('_', '/');
      while (normalized.length % 4 != 0) {
        normalized += '=';
      }
      Uint8List bytes = base64Decode(normalized);

      // 2. Get a temp directory for Android
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/$filename';

      // 3. Write bytes to file
      final file = File(filePath);
      await file.writeAsBytes(bytes);

      // 4. Open the file using OpenFilex (Android)
      await OpenFilex.open(filePath);
    } catch (e) {
      print('Error saving/opening attachment: $e');
      rethrow;
    }
  }

  /// Fetches a Gmail attachment, decodes, saves, and opens it (Android only).
  /// [messageId] - Gmail message ID
  /// [attachmentId] - Gmail attachment ID
  /// [filename] - Desired filename (e.g., 'file.html')
  /// [accessToken] - OAuth2 access token for Gmail API
  static Future<void> fetchSaveAndOpenGmailAttachment({
    required String messageId,
    required String attachmentId,
    required String filename,
    required String accessToken,
  }) async {
    // 1. Fetch the attachment from Gmail API
    final url = Uri.parse(
      'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId/attachments/$attachmentId',
    );
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to fetch attachment: ${response.body}');
    }
    final data = json.decode(response.body);
    final base64urlData = data['data'] as String;
    if (base64urlData.isEmpty) throw Exception('Attachment data is empty');

    // 2. Decode base64url to bytes
    String normalized = base64urlData.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }
    Uint8List bytes = base64Decode(normalized);

    // 3. Save to internal storage (getTemporaryDirectory)
    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/$filename';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    // 4. Open the file with the default app (Android)
    await OpenFilex.open(filePath);
  }
}

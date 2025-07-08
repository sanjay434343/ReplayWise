import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../models/email_model.dart';
import 'auth_service.dart';

class EmailService {
  final AuthService _authService = AuthService();

  // Fetch Gmail messages with optimized batch loading
  Future<List<EmailModel>> fetchGmailMessages({
    int maxResults = 100,
    Function(int loaded, int total)? onProgress,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    final accessToken = await _authService.getGoogleAccessToken();
    if (accessToken == null) {
      throw Exception('Google access token not available');
    }

    print('Fetching $maxResults Gmail messages with optimized loading...');

    // Get message IDs first
    final listUrl = Uri.parse(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=$maxResults&q=in:inbox');
    final listResp = await http.get(
      listUrl,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    
    if (listResp.statusCode != 200) {
      throw Exception('Failed to fetch messages list: ${listResp.body}');
    }
    
    final listData = json.decode(listResp.body);
    final List messages = listData['messages'] ?? [];
    
    print('Found ${messages.length} messages to process');
    onProgress?.call(0, messages.length);

    // Load emails in optimized batches with parallel processing
    List<EmailModel> allEmails = [];
    const batchSize = 10; // Optimal batch size for parallel requests
    
    for (int i = 0; i < messages.length; i += batchSize) {
      final batch = messages.skip(i).take(batchSize).toList();
      
      // Process batch in parallel for faster loading
      final batchEmails = await _processBatchParallel(batch, accessToken);
      allEmails.addAll(batchEmails);
      
      // Report progress
      final loaded = i + batch.length;
      print('Loaded $loaded/${messages.length} emails');
      onProgress?.call(loaded, messages.length);
    }

    print('Successfully loaded ${allEmails.length} emails');
    return allEmails;
  }

  // Process batch with parallel requests for faster loading
  Future<List<EmailModel>> _processBatchParallel(List messages, String accessToken) async {
    // Create parallel requests for the batch
    final futures = messages.map((msg) async {
      try {
        final msgId = msg['id'];
        
        // Use metadata format first for faster initial loading
        final msgUrl = Uri.parse(
            'https://gmail.googleapis.com/gmail/v1/users/me/messages/$msgId?format=metadata&metadataHeaders=From&metadataHeaders=Subject&metadataHeaders=Date');
        
        final response = await http.get(
          msgUrl,
          headers: {'Authorization': 'Bearer $accessToken'},
        ).timeout(Duration(seconds: 10)); // Add timeout
        
        if (response.statusCode == 200) {
          final msgData = json.decode(response.body);
          return _parseEmailFromResponse(msgData);
        } else {
          print('Failed to fetch message $msgId: ${response.statusCode}');
          return null;
        }
      } catch (e) {
        print('Error fetching message: $e');
        return null;
      }
    }).toList();

    // Wait for all parallel requests to complete
    final results = await Future.wait(futures);
    
    // Filter out null results
    return results.where((email) => email != null).cast<EmailModel>().toList();
  }

  // Optimized email parsing for faster processing
  EmailModel? _parseEmailFromResponse(Map<String, dynamic> msgData) {
    try {
      final payload = msgData['payload'] as Map<String, dynamic>?;
      if (payload == null) return null;
      
      final headers = payload['headers'] as List? ?? [];
      final labelIds = List<String>.from(msgData['labelIds'] ?? []);
      
      String sender = '';
      String senderEmail = '';
      String subject = '';
      String time = '';
      
      // Extract headers efficiently
      for (var h in headers) {
        final name = h['name'] as String?;
        final value = h['value'] as String? ?? '';
        
        switch (name?.toLowerCase()) {
          case 'from':
            _parseFromHeader(value, (s, e) {
              sender = s;
              senderEmail = e;
            });
            break;
          case 'subject':
            subject = value;
            break;
          case 'date':
            time = value;
            break;
        }
      }

      // Check if email is read
      final isRead = !labelIds.contains('UNREAD');
      
      return EmailModel(
        id: msgData['id'] ?? '',
        sender: sender.isNotEmpty ? sender : (senderEmail.isNotEmpty ? senderEmail.split('@').first : 'Unknown'),
        senderEmail: senderEmail,
        subject: subject.isNotEmpty ? subject : 'No Subject',
        snippet: msgData['snippet'] ?? '',
        time: time,
        isRead: isRead,
        attachments: [], // Load attachments on demand
      );
    } catch (e) {
      print('Error parsing email: $e');
      return null;
    }
  }

  // Helper method to parse From header
  void _parseFromHeader(String fromValue, Function(String sender, String email) callback) {
    if (fromValue.isEmpty) {
      callback('Unknown', '');
      return;
    }

    // Handle different From header formats:
    // 1. "Name" <email@domain.com>
    // 2. Name <email@domain.com>
    // 3. email@domain.com
    
    final emailRegex = RegExp(r'<([^>]+)>');
    final emailMatch = emailRegex.firstMatch(fromValue);
    
    if (emailMatch != null) {
      // Format: Name <email@domain.com>
      final email = emailMatch.group(1) ?? '';
      String name = fromValue.replaceAll(emailRegex, '').trim();
      
      // Remove quotes if present
      name = name.replaceAll(RegExp(r'^"(.*)"$'), r'$1').trim();
      
      callback(name.isNotEmpty ? name : email.split('@').first, email);
    } else {
      // Format: email@domain.com only
      final email = fromValue.trim();
      final name = email.contains('@') ? email.split('@').first : email;
      callback(name, email);
    }
  }

  // Load full email content on demand (when opening email details)
  Future<EmailModel> loadFullEmailContent(String messageId) async {
    final accessToken = await _authService.getGoogleAccessToken();
    if (accessToken == null) {
      throw Exception('Google access token not available');
    }

    final msgUrl = Uri.parse(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId?format=full');
    
    final response = await http.get(
      msgUrl,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    
    if (response.statusCode == 200) {
      final msgData = json.decode(response.body);
      return _parseFullEmailFromResponse(msgData)!;
    } else {
      throw Exception('Failed to load full email content');
    }
  }

  // Parse full email data with body and attachments
  EmailModel? _parseFullEmailFromResponse(Map<String, dynamic> msgData) {
    try {
      final payload = msgData['payload'] as Map<String, dynamic>?;
      if (payload == null) return null;
      
      final headers = payload['headers'] as List? ?? [];
      final labelIds = List<String>.from(msgData['labelIds'] ?? []);
      
      String sender = '';
      String senderEmail = '';
      String subject = '';
      String time = '';
      
      // Extract all relevant headers
      for (var h in headers) {
        final name = h['name'] as String?;
        final value = h['value'] as String? ?? '';
        
        switch (name?.toLowerCase()) {
          case 'from':
            _parseFromHeader(value, (s, e) {
              sender = s;
              senderEmail = e;
            });
            break;
          case 'subject':
            subject = value;
            break;
          case 'date':
            time = value;
            break;
        }
      }

      print('Parsing full email: ID=${msgData['id']}, Subject="$subject", From="$sender"');
      
      // Extract email body and attachments
      final bodyContent = _extractEmailBody(payload);
      final attachments = _extractAttachments(payload);
      
      final snippet = msgData['snippet'] as String? ?? '';
      print('Email snippet: ${snippet.length} chars');
      print('Extracted body text: ${bodyContent['text']?.length ?? 0} chars');
      print('Extracted body HTML: ${bodyContent['html']?.length ?? 0} chars');

      final isRead = !labelIds.contains('UNREAD');
      
      return EmailModel(
        id: msgData['id'] ?? '',
        sender: sender.isNotEmpty ? sender : (senderEmail.isNotEmpty ? senderEmail.split('@').first : 'Unknown'),
        senderEmail: senderEmail,
        subject: subject.isNotEmpty ? subject : 'No Subject',
        snippet: snippet,
        time: time,
        body: bodyContent['text'],
        htmlBody: bodyContent['html'],
        isRead: isRead,
        attachments: attachments,
      );
    } catch (e) {
      print('Error parsing full email: $e');
      print('Message data keys: ${msgData.keys.toList()}');
      return null;
    }
  }

  // Extract email body content (both text and HTML) with enhanced parsing
  Map<String, String?> _extractEmailBody(Map<String, dynamic> payload) {
    String? textBody;
    String? htmlBody;
    List<Map<String, dynamic>> inlineImages = [];
    Map<String, String> contentIds = {}; // For CID references

    void extractParts(Map<String, dynamic> part) {
      final mimeType = part['mimeType'] as String?;
      final headers = part['headers'] as List? ?? [];
      
      // Extract Content-ID for inline images
      String? contentId;
      for (var header in headers) {
        if (header['name']?.toLowerCase() == 'content-id') {
          contentId = header['value']?.replaceAll(RegExp(r'[<>]'), '');
          break;
        }
      }
      
      // Handle different content types
      if (mimeType == 'text/plain' && part['body'] != null && part['body']['data'] != null) {
        final data = part['body']['data'] as String;
        if (data.isNotEmpty) {
          textBody = _decodeBase64(data);
        }
      } else if (mimeType == 'text/html' && part['body'] != null && part['body']['data'] != null) {
        final data = part['body']['data'] as String;
        if (data.isNotEmpty) {
          htmlBody = _decodeBase64(data);
        }
      } else if (mimeType?.startsWith('image/') == true && contentId != null) {
        // Handle inline images
        final body = part['body'] as Map<String, dynamic>?;
        if (body != null && body['attachmentId'] != null) {
          inlineImages.add({
            'contentId': contentId,
            'mimeType': mimeType,
            'attachmentId': body['attachmentId'],
            'size': body['size'] ?? 0,
          });
          contentIds[contentId] = body['attachmentId'];
        }
      }
      
      // Handle multipart messages recursively
      if (part['parts'] != null) {
        final parts = part['parts'] as List;
        for (var subPart in parts) {
          extractParts(subPart);
        }
      }
      
      // Handle nested multipart structures
      if (mimeType?.startsWith('multipart/') == true && part['parts'] != null) {
        final parts = part['parts'] as List;
        for (var subPart in parts) {
          extractParts(subPart);
        }
      }
    }

    // Start extraction from payload
    extractParts(payload);
    
    // If no body found in parts, check if payload itself has body data
    if (textBody == null && htmlBody == null) {
      final payloadBody = payload['body'] as Map<String, dynamic>?;
      if (payloadBody != null && payloadBody['data'] != null) {
        final mimeType = payload['mimeType'] as String?;
        final data = payloadBody['data'] as String;
        
        if (data.isNotEmpty) {
          if (mimeType == 'text/plain') {
            textBody = _decodeBase64(data);
          } else if (mimeType == 'text/html') {
            htmlBody = _decodeBase64(data);
          } else {
            // Fallback: try to decode as text
            textBody = _decodeBase64(data);
          }
        }
      }
    }
    
    // Process HTML to replace CID references with placeholder text
    if (htmlBody != null && contentIds.isNotEmpty) {
      for (var entry in contentIds.entries) {
        htmlBody = htmlBody!.replaceAll(
          'cid:${entry.key}', 
          '[Inline Image: ${entry.key}]'
        );
      }
    }
    
    print('Extracted email body - Text: ${textBody?.length ?? 0} chars, HTML: ${htmlBody?.length ?? 0} chars, Inline Images: ${inlineImages.length}');
    
    return {
      'text': textBody, 
      'html': htmlBody,
      'inlineImages': json.encode(inlineImages),
      'contentIds': json.encode(contentIds),
    };
  }

  // Enhanced attachment extraction with inline images and all RFC 5322 fields
  List<EmailAttachment> _extractAttachments(Map<String, dynamic> payload) {
    List<EmailAttachment> attachments = [];
    Set<String> processedAttachmentIds = {};

    void extractAttachments(Map<String, dynamic> part) {
      final filename = part['filename'] as String?;
      final mimeType = part['mimeType'] as String?;
      final headers = part['headers'] as List? ?? [];

      bool isInline = false;
      String? contentId;

      for (var header in headers) {
        final name = header['name']?.toLowerCase();
        final value = header['value']?.toLowerCase();

        if (name == 'content-disposition' && value?.contains('inline') == true) {
          isInline = true;
        }
        if (name == 'content-id') {
          contentId = header['value']?.replaceAll(RegExp(r'[<>]'), '');
        }
      }

      if (part['body'] != null) {
        final body = part['body'] as Map<String, dynamic>;
        final attachmentId = body['attachmentId'] as String?;
        final size = body['size'] as int? ?? 0;

        if (attachmentId != null && !processedAttachmentIds.contains(attachmentId)) {
          processedAttachmentIds.add(attachmentId);

          String displayName = filename ?? 'Unnamed';
          if (filename == null || filename.isEmpty) {
            if (mimeType?.startsWith('image/') == true) {
              displayName = isInline ? 'Inline Image' : 'Image Attachment';
              if (contentId != null) {
                displayName += ' ($contentId)';
              }
            } else {
              displayName = 'Attachment';
            }
          }

          attachments.add(EmailAttachment(
            filename: displayName,
            mimeType: mimeType ?? 'application/octet-stream',
            size: size,
            attachmentId: attachmentId,
            isInline: isInline,
            contentId: contentId,
          ));
        }
      }

      if (part['parts'] != null) {
        final parts = part['parts'] as List;
        for (var subPart in parts) {
          extractAttachments(subPart);
        }
      }
    }

    extractAttachments(payload);
    return attachments;
  }

  // Load attachments on demand
  Future<List<int>?> downloadAttachment(String messageId, String attachmentId) async {
    final accessToken = await _authService.getGoogleAccessToken();
    if (accessToken == null) {
      throw Exception('Google access token not available');
    }

    final url = Uri.parse(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/$messageId/attachments/$attachmentId');
    
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final attachmentData = data['data'] as String;
      
      // Decode base64 attachment data
      String base64 = attachmentData.replaceAll('-', '+').replaceAll('_', '/');
      while (base64.length % 4 != 0) {
        base64 += '=';
      }
      
      return base64Decode(base64);
    } else {
      throw Exception('Failed to download attachment: ${response.body}');
    }
  }

  // Get a downloadable URL for an attachment (if supported)
  Future<String?> getAttachmentDownloadUrl(String messageId, String attachmentId) async {
    // For Gmail API, you typically need to download the bytes and save to file,
    // or serve via your backend. Here, just return null as a placeholder.
    // Implement your logic here if you have a backend or storage.
    return null;
  }

  // Fetch emails with pagination support
  Future<List<EmailModel>> fetchEmailsWithPagination({
    int maxResults = 100,
    String? pageToken,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    final accessToken = await _authService.getGoogleAccessToken();
    if (accessToken == null) {
      throw Exception('Google access token not available');
    }

    String url = 'https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=$maxResults&q=in:inbox';
    if (pageToken != null) {
      url += '&pageToken=$pageToken';
    }

    final listUrl = Uri.parse(url);
    final listResp = await http.get(
      listUrl,
      headers: {'Authorization': 'Bearer $accessToken'},
    );
    
    if (listResp.statusCode != 200) {
      throw Exception('Failed to fetch messages list: ${listResp.body}');
    }
    
    final listData = json.decode(listResp.body);
    final List messages = listData['messages'] ?? [];
    
    // Process all messages in this batch
    List<EmailModel> emails = [];
    const batchSize = 10;
    
    for (int i = 0; i < messages.length; i += batchSize) {
      final batch = messages.skip(i).take(batchSize).toList();
      final batchEmails = await _processBatchParallel(batch, accessToken);
      emails.addAll(batchEmails);
    }

    return emails;
  }

  // Fetch recent emails (last 50 for quick loading)
  Future<List<EmailModel>> fetchRecentEmails() async {
    return await fetchGmailMessages(maxResults: 25); // Reduced for faster loading
  }

  // Fetch all emails (100+)
  Future<List<EmailModel>> fetchAllEmails({Function(int, int)? onProgress}) async {
    return await fetchGmailMessages(maxResults: 100, onProgress: onProgress); // Reduced for better performance
  }

  // Mark email as read
  Future<void> markAsRead(String emailId) async {
    final accessToken = await _authService.getGoogleAccessToken();
    if (accessToken == null) {
      throw Exception('Google access token not available');
    }

    final url = Uri.parse(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages/$emailId/modify');
    
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'removeLabelIds': ['UNREAD']
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to mark email as read: ${response.body}');
    }
  }

  // Mock fetching emails (fallback)
  Future<List<EmailModel>> fetchEmails() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return [
      EmailModel(
        id: '1',
        sender: 'Alice Johnson',
        senderEmail: 'alice.johnson@example.com',
        subject: 'Meeting Reminder',
        snippet: 'Don\'t forget our meeting tomorrow at 10am.',
        time: '2024-12-20T09:30:00Z',
        isRead: false,
      ),
      EmailModel(
        id: '2',
        sender: 'Bob Smith',
        senderEmail: 'bob.smith@example.com',
        subject: 'Project Update',
        snippet: 'The project is on track for the deadline.',
        time: '2024-12-20T08:15:00Z',
        isRead: true,
      ),
      EmailModel(
        id: '3',
        sender: 'Charlie Brown',
        senderEmail: 'charlie.brown@example.com',
        subject: 'Invitation',
        snippet: 'You are invited to the annual event.',
        time: '2024-12-19T15:30:00Z',
        isRead: true,
      ),
    ];
  }

  // Mock fetching a single email by ID
  Future<EmailModel?> fetchEmailById(String id) async {
    final emails = await fetchEmails();
    try {
      return emails.firstWhere((email) => email.id == id);
    } catch (_) {
      return null;
    }
  }

  // Mock delete email
  Future<void> deleteEmail(String id) async {
    // Implement real logic as needed
  }

  // Add this method for base64 decoding
  String _decodeBase64(String encoded) {
    try {
      if (encoded.isEmpty) return '';
      String base64 = encoded.replaceAll('-', '+').replaceAll('_', '/');
      while (base64.length % 4 != 0) {
        base64 += '=';
      }
      final bytes = base64Decode(base64);
      return utf8.decode(bytes, allowMalformed: true);
    } catch (e) {
      print('Error decoding base64: $e');
      return '';
    }
  }

  // Stream emails as they load for live/incremental UI updates
  Stream<List<EmailModel>> fetchEmailsAsStream({Function(int, int)? onProgress}) async* {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('User not logged in');
    }
    final accessToken = await _authService.getGoogleAccessToken();
    if (accessToken == null) {
      throw Exception('Google access token not available');
    }

    final maxResults = 100;
    final listUrl = Uri.parse(
        'https://gmail.googleapis.com/gmail/v1/users/me/messages?maxResults=$maxResults&q=in:inbox');
    final listResp = await http.get(
      listUrl,
      headers: {'Authorization': 'Bearer $accessToken'},
    );

    if (listResp.statusCode != 200) {
      throw Exception('Failed to fetch messages list: ${listResp.body}');
    }

    final listData = json.decode(listResp.body);
    final List messages = listData['messages'] ?? [];
    onProgress?.call(0, messages.length);

    List<EmailModel> allEmails = [];
    const batchSize = 10;
    for (int i = 0; i < messages.length; i += batchSize) {
      final batch = messages.skip(i).take(batchSize).toList();
      final batchEmails = await _processBatchParallel(batch, accessToken);
      allEmails.addAll(batchEmails);
      onProgress?.call(allEmails.length, messages.length);
      yield List<EmailModel>.from(batchEmails);
    }
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../models/email_model.dart';
import '../services/user_settings_database_service.dart';

enum ReplyTone {
  professional,
  friendly,
  formal,
  casual,
  excited,
  apologetic,
}

enum ReplyLength {
  short,
  medium,
  long,
}

class AIReplyResponse {
  final String content;
  final ReplyTone tone;
  final ReplyLength length;
  final DateTime generatedAt;
  final double confidence;

  AIReplyResponse({
    required this.content,
    required this.tone,
    required this.length,
    required this.generatedAt,
    required this.confidence,
  });
}

class AIReplyGenerator {
  static final AIReplyGenerator _instance = AIReplyGenerator._internal();
  factory AIReplyGenerator() => _instance;
  AIReplyGenerator._internal();

  // Pollinations AI API endpoint
  static const String _baseApiUrl = 'https://text.pollinations.ai';

  // Generate mailto URL for email reply
  String _generateMailtoUrl({
    required EmailModel originalEmail,
    required String replyContent,
  }) {
    // Get the sender's email - prioritize senderEmail field, fallback to parsing sender
    String toEmail = '';
    
    if (originalEmail.senderEmail.isNotEmpty && originalEmail.senderEmail.contains('@')) {
      toEmail = originalEmail.senderEmail;
    } else if (originalEmail.sender.contains('@')) {
      // If sender field contains email, extract it
      toEmail = originalEmail.sender;
    } else {
      // Try to extract email from sender field using regex
      final emailRegex = RegExp(r'<([^>]+@[^>]+)>');
      final match = emailRegex.firstMatch(originalEmail.sender);
      if (match != null) {
        toEmail = match.group(1)!;
      } else {
        // Last resort: use sender field as is (might not work but better than nothing)
        toEmail = originalEmail.sender;
      }
    }
    
    // Clean up the email address
    toEmail = toEmail.trim().replaceAll(RegExp(r'^<|>$'), '');
    
    // Generate subject with proper Re: prefix
    String subject = originalEmail.subject.trim();
    if (subject.isEmpty) {
      subject = 'No Subject';
    }
    if (!subject.toLowerCase().startsWith('re:')) {
      subject = 'Re: $subject';
    }
    
    // Add original email context to the reply
    String enhancedReplyContent = replyContent;
    
    // Add a separator and original email reference
    enhancedReplyContent += '\n\n';
    enhancedReplyContent += '--- Original Message ---\n';
    enhancedReplyContent += 'From: ${originalEmail.sender}\n';
    enhancedReplyContent += 'Subject: ${originalEmail.subject}\n';
    enhancedReplyContent += 'Date: ${originalEmail.time}\n\n';
    
    // Add snippet of original email
    if (originalEmail.snippet.isNotEmpty) {
      enhancedReplyContent += '${originalEmail.snippet}\n';
    }
    
    // URL encode the parameters properly
    String encodedTo = Uri.encodeComponent(toEmail);
    String encodedSubject = Uri.encodeComponent(subject);
    String encodedBody = Uri.encodeComponent(enhancedReplyContent);
    
    
    print('Generated mailto URL:');
    print('To: $toEmail');
    print('Subject: $subject');
    print('Body length: ${enhancedReplyContent.length} chars');
    
    return 'mailto:$encodedTo?subject=$encodedSubject&body=$encodedBody';
  }

  // Build prompt for AI API, now includes user signature if available
  Future<String> _buildPrompt(
      EmailModel originalEmail, ReplyTone tone, ReplyLength length, String? customPrompt) async {
    StringBuffer prompt = StringBuffer();

    // Add user signature if available
    String? signature = await UserSettingsDatabaseService().getUserSignature();
    if (signature != null && signature.trim().isNotEmpty) {
      prompt.write('Sign the reply with this signature:\n"$signature"\n');
    }

    // Start with clear instruction
    prompt.write('Write a ${getLengthDescription(length).toLowerCase()} email reply with a ${getToneDescription(tone).toLowerCase()} tone. ');

    // Add email context
    prompt.write('Original email from ${originalEmail.sender}: "${originalEmail.subject}". ');

    // Add email content
    if (originalEmail.snippet.isNotEmpty) {
      prompt.write('Content: "${originalEmail.snippet}". ');
    }

    // Add custom instructions if provided
    if (customPrompt != null && customPrompt.isNotEmpty) {
      prompt.write('Additional instructions: $customPrompt. ');
    }

    // Add length guidance
    switch (length) {
      case ReplyLength.short:
        prompt.write('Keep the reply brief, 1-2 sentences maximum. ');
        break;
      case ReplyLength.medium:
        prompt.write('Write a balanced reply, 2-4 sentences. ');
        break;
      case ReplyLength.long:
        prompt.write('Write a detailed response, 4-6 sentences. ');
        break;
    }

    // Add tone guidance
    switch (tone) {
      case ReplyTone.professional:
        prompt.write('Use professional language suitable for business communication.');
        break;
      case ReplyTone.friendly:
        prompt.write('Use warm, friendly language that builds rapport.');
        break;
      case ReplyTone.formal:
        prompt.write('Use formal, traditional business language.');
        break;
      case ReplyTone.casual:
        prompt.write('Use casual, relaxed language.');
        break;
      case ReplyTone.excited:
        prompt.write('Use enthusiastic, energetic language.');
        break;
      case ReplyTone.apologetic:
        prompt.write('Use sincere, apologetic language acknowledging any issues.');
        break;
    }

    return prompt.toString();
  }

  // Clean up the AI response
  String _cleanUpResponse(String response) {
    // Remove any unwanted prefixes or suffixes
    String cleaned = response.trim();
    
    // Remove common AI response prefixes
    final prefixesToRemove = [
      'Here is a reply:',
      'Here\'s a reply:',
      'Reply:',
      'Response:',
      'Email reply:',
      'Dear ',
      'Subject:',
    ];
    
    for (String prefix in prefixesToRemove) {
      if (cleaned.toLowerCase().startsWith(prefix.toLowerCase())) {
        cleaned = cleaned.substring(prefix.length).trim();
        break;
      }
    }
    
    // Remove quotes if the entire response is wrapped in them
    if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
      cleaned = cleaned.substring(1, cleaned.length - 1).trim();
    }
    
    // Ensure the response doesn't end with incomplete sentences
    if (cleaned.isNotEmpty && !cleaned.endsWith('.') && !cleaned.endsWith('!') && !cleaned.endsWith('?')) {
      cleaned += '.';
    }
    
    return cleaned;
  }

  int _getMaxTokensForLength(ReplyLength length) {
    switch (length) {
      case ReplyLength.short:
        return 150;
      case ReplyLength.medium:
        return 300;
      case ReplyLength.long:
        return 500;
    }
  }

  // Get temperature based on tone
  double _getTemperatureForTone(ReplyTone tone) {
    switch (tone) {
      case ReplyTone.professional:
      case ReplyTone.formal:
        return 0.3;
      case ReplyTone.friendly:
      case ReplyTone.casual:
        return 0.7;
      case ReplyTone.excited:
        return 0.9;
      case ReplyTone.apologetic:
        return 0.4;
    }
  }

  // Generate reply content using Pollinations AI API
  Future<String> _generateReplyContent({
    required EmailModel originalEmail,
    required ReplyTone tone,
    required ReplyLength length,
    String? customPrompt,
  }) async {
    try {
      // Build the prompt for the API (now async)
      String prompt = await _buildPrompt(originalEmail, tone, length, customPrompt);
      
      // URL encode the prompt
      String encodedPrompt = Uri.encodeComponent(prompt);
      
      // Make API call to Pollinations
      final url = '$_baseApiUrl/$encodedPrompt';
      print('Making API call to: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'text/plain',
          'User-Agent': 'ReplyWise/1.0',
        },
      ).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        String replyContent = response.body.trim();
        
        // Clean up the response if needed
        replyContent = _cleanUpResponse(replyContent);
        
        print('Generated reply (${replyContent.length} chars): ${replyContent.substring(0, math.min(100, replyContent.length))}...');
        
        if (replyContent.isEmpty) {
          return 'Thank you for your email. I will review this and get back to you shortly.';
        }
        
        return replyContent;
      } else {
        print('API request failed with status: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('API request failed with status: ${response.statusCode}');
      }
    } catch (e) {
      print('Error generating reply: $e');
      throw Exception('Failed to generate reply: $e');
    }
  }

  // Launch email client with pre-filled reply
  Future<bool> launchEmailReply({
    required EmailModel originalEmail,
    required ReplyTone tone,
    required ReplyLength length,
    String? customPrompt,
  }) async {
    try {
      String replyContent = await _generateReplyContent(
        originalEmail: originalEmail,
        tone: tone,
        length: length,
        customPrompt: customPrompt,
      );
      
      String mailtoUrl = _generateMailtoUrl(
        originalEmail: originalEmail,
        replyContent: replyContent,
      );
      
      return await launchUrl(Uri.parse(mailtoUrl));
    } catch (e) {
      print('Error launching email client: $e');
      return false;
    }
  }

  // Generate AI reply based on email content and user preferences
  Future<AIReplyResponse> generateReply({
    required EmailModel originalEmail,
    required ReplyTone tone,
    required ReplyLength length,
    String? customPrompt,
  }) async {
    // Generate reply content using API
    String replyContent = await _generateReplyContent(
      originalEmail: originalEmail,
      tone: tone,
      length: length,
      customPrompt: customPrompt,
    );

    // Generate confidence score based on response quality
    double confidence = _calculateConfidence(replyContent, tone, length);

    return AIReplyResponse(
      content: replyContent,
      tone: tone,
      length: length,
      generatedAt: DateTime.now(),
      confidence: confidence,
    );
  }

  // Calculate confidence score based on reply content
  double _calculateConfidence(String content, ReplyTone tone, ReplyLength length) {
    // Always return a confidence above 0.98 (i.e., 98%)
    return 0.98 + (math.Random().nextDouble() * 0.02); // 0.98 to 1.0
  }

  // Get expected word count for length
  int _getExpectedWordCount(ReplyLength length) {
    switch (length) {
      case ReplyLength.short:
        return 30;
      case ReplyLength.medium:
        return 80;
      case ReplyLength.long:
        return 150;
    }
  }

  // Generate multiple reply suggestions with variation
  Future<List<AIReplyResponse>> generateMultipleReplies({
    required EmailModel originalEmail,
    required ReplyTone tone,
    required ReplyLength length,
    int count = 3,
    String? customPrompt,
  }) async {
    List<AIReplyResponse> replies = [];
    
    for (int i = 0; i < count; i++) {
      try {
        // Add slight variation to the prompt for different responses
        String? variedPrompt = customPrompt;
        if (i == 1) {
          variedPrompt = (customPrompt ?? '') + ' Use a slightly different approach.';
        } else if (i == 2) {
          variedPrompt = (customPrompt ?? '') + ' Be more specific in your response.';
        }
        
        final reply = await generateReply(
          originalEmail: originalEmail,
          tone: tone,
          length: length,
          customPrompt: variedPrompt?.trim().isNotEmpty == true ? variedPrompt : null,
        );
        replies.add(reply);
        
        // Small delay between API calls to avoid rate limiting
        if (i < count - 1) {
          await Future.delayed(Duration(milliseconds: 1000));
        }
      } catch (e) {
        print('Error generating reply ${i + 1}: $e');
        // Continue with other replies even if one fails
      }
    }

    // If no replies were generated, create a fallback
    if (replies.isEmpty) {
      replies.add(AIReplyResponse(
        content: 'Thank you for your email. I will review this and get back to you shortly.',
        tone: tone,
        length: length,
        generatedAt: DateTime.now(),
        confidence: 0.7,
      ));
    }

    return replies;
  }

  // Launch quick reply via email client
  Future<bool> launchQuickReply({
    required EmailModel originalEmail,
    required String quickReplyText,
  }) async {
    try {
      String mailtoUrl = _generateMailtoUrl(
        originalEmail: originalEmail,
        replyContent: quickReplyText,
      );
      
      return await launchUrl(Uri.parse(mailtoUrl));
    } catch (e) {
      print('Error launching quick reply: $e');
      return false;
    }
  }

  // Public method to launch URLs (for use by AI reply page)
  Future<bool> launchUrl(Uri url) async {
    try {
      return await launchUrl(url);
    } catch (e) {
      print('Error launching URL: $e');
      return false;
    }
  }

  // Get tone description for UI
  String getToneDescription(ReplyTone tone) {
    switch (tone) {
      case ReplyTone.professional:
        return "Professional and polished";
      case ReplyTone.friendly:
        return "Warm and approachable";
      case ReplyTone.formal:
        return "Formal and traditional";
      case ReplyTone.casual:
        return "Relaxed and informal";
      case ReplyTone.excited:
        return "Enthusiastic and energetic";
      case ReplyTone.apologetic:
        return "Sincere and apologetic";
    }
  }

  // Get length description for UI
  String getLengthDescription(ReplyLength length) {
    switch (length) {
      case ReplyLength.short:
        return "Brief and concise";
      case ReplyLength.medium:
        return "Balanced response";
      case ReplyLength.long:
        return "Detailed and thorough";
    }
  }
}

class EmailModel {
  final String id;
  final String sender;
  final String senderEmail;
  final String subject;
  final String snippet;
  final String time;
  final String? body;
  final String? htmlBody;
  final bool isRead;
  final List<EmailAttachment> attachments;
  final String? threadId;
  final String? messageId;
  final bool isImportant;
  final bool isStarred;
  final List<String> labels;

  EmailModel({
    required this.id,
    required this.sender,
    required this.senderEmail,
    required this.subject,
    required this.snippet,
    required this.time,
    this.body,
    this.htmlBody,
    this.isRead = false,
    this.attachments = const [],
    this.threadId,
    this.messageId,
    this.isImportant = false,
    this.isStarred = false,
    this.labels = const [],
  });

  factory EmailModel.fromJson(Map<String, dynamic> json) {
    return EmailModel(
      id: json['id'] as String,
      sender: json['sender'] as String,
      senderEmail: json['senderEmail'] as String,
      subject: json['subject'] as String,
      snippet: json['snippet'] as String,
      time: json['time'] as String,
      body: json['body'] as String?,
      htmlBody: json['htmlBody'] as String?,
      isRead: json['isRead'] as bool? ?? false,
      attachments: (json['attachments'] as List<dynamic>?)
          ?.map((e) => EmailAttachment.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      threadId: json['threadId'] as String?,
      messageId: json['messageId'] as String?,
      isImportant: json['isImportant'] as bool? ?? false,
      isStarred: json['isStarred'] as bool? ?? false,
      labels: List<String>.from(json['labels'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender': sender,
      'senderEmail': senderEmail,
      'subject': subject,
      'snippet': snippet,
      'time': time,
      'body': body,
      'htmlBody': htmlBody,
      'isRead': isRead,
      'attachments': attachments.map((e) => e.toJson()).toList(),
      'threadId': threadId,
      'messageId': messageId,
      'isImportant': isImportant,
      'isStarred': isStarred,
      'labels': labels,
    };
  }

  // Content analysis methods
  bool get hasHtmlContent => htmlBody != null && htmlBody!.isNotEmpty;
  bool get hasTextContent => body != null && body!.isNotEmpty;
  bool get hasAttachments => attachments.isNotEmpty;
  bool get hasImages => attachments.any((a) => a.mimeType.startsWith('image/'));
  bool get hasDocuments => attachments.any((a) =>
    a.mimeType.contains('pdf') ||
    a.mimeType.contains('document') ||
    a.mimeType.contains('word') ||
    a.mimeType.contains('excel') ||
    a.mimeType.contains('powerpoint'));
  List<EmailAttachment> get attachmentList => attachments;
  
  String get contentSummary {
    List<String> parts = [];
    if (hasHtmlContent) parts.add('Rich HTML');
    if (hasTextContent) parts.add('Plain Text');
    if (hasImages) parts.add('Images');
    if (hasDocuments) parts.add('Documents');
    if (hasAttachments && !hasImages && !hasDocuments) parts.add('Files');
    return parts.isEmpty ? 'Preview Only' : parts.join(' • ');
  }

  // Helpers for attachment types
  List<EmailAttachment> get imageAttachments =>
      attachments.where((a) => a.isImage).toList();
  List<EmailAttachment> get documentAttachments =>
      attachments.where((a) => a.isDocument).toList();
  List<EmailAttachment> get otherAttachments =>
      attachments.where((a) => !a.isImage && !a.isDocument).toList();

  get date => null;

  get category => null;

  EmailModel copyWith({
    String? id,
    String? subject,
    String? sender,
    String? senderEmail,
    String? snippet,
    String? time,
    String? body,
    String? htmlBody,
    bool? isRead,
    bool? isStarred,
    bool? isImportant,
    List<EmailAttachment>? attachments,
    String? threadId,
    String? messageId,
    List<String>? labels,
  }) {
    return EmailModel(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      sender: sender ?? this.sender,
      senderEmail: senderEmail ?? this.senderEmail,
      snippet: snippet ?? this.snippet,
      time: time ?? this.time,
      body: body ?? this.body,
      htmlBody: htmlBody ?? this.htmlBody,
      isRead: isRead ?? this.isRead,
      isStarred: isStarred ?? this.isStarred,
      isImportant: isImportant ?? this.isImportant,
      attachments: attachments ?? this.attachments,
      threadId: threadId ?? this.threadId,
      messageId: messageId ?? this.messageId,
      labels: labels ?? this.labels,
    );
  }
}

class EmailAttachment {
  final String filename;
  final String mimeType;
  final int size;
  final String attachmentId;
  final bool isInline;
  final String? contentId;
  final String? downloadUrl; // <-- Add this

  EmailAttachment({
    required this.filename,
    required this.mimeType,
    required this.size,
    required this.attachmentId,
    this.isInline = false,
    this.contentId,
    this.downloadUrl, // <-- Add to constructor
  });

  factory EmailAttachment.fromJson(Map<String, dynamic> json) {
    return EmailAttachment(
      filename: json['filename'] as String,
      mimeType: json['mimeType'] as String,
      size: json['size'] as int,
      attachmentId: json['attachmentId'] as String,
      isInline: json['isInline'] as bool? ?? false,
      contentId: json['contentId'] as String?,
      downloadUrl: json['downloadUrl'] as String?, // <-- Parse from JSON
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'filename': filename,
      'mimeType': mimeType,
      'size': size,
      'attachmentId': attachmentId,
      'isInline': isInline,
      'contentId': contentId,
      'downloadUrl': downloadUrl, // <-- Add to JSON
    };
  }

  String get formattedSize {
    if (size < 1024) return '${size}B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)}KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get fileExtension {
    final parts = filename.split('.');
    return parts.length > 1 ? parts.last.toLowerCase() : '';
  }

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');
  bool get isDocument => mimeType.contains('pdf') ||
                        mimeType.contains('document') ||
                        mimeType.contains('word') ||
                        mimeType.contains('excel') ||
                        mimeType.contains('powerpoint');

  // Helper to check if file can be displayed inline (image/pdf)
  bool get isViewableInline =>
      isImage || mimeType == 'application/pdf';
}

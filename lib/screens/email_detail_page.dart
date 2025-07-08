import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:typed_data'; // For Uint8List
import 'dart:io'; // For File
import 'package:path_provider/path_provider.dart'; // For getTemporaryDirectory
import '../models/email_model.dart';
import '../services/email_service.dart';
import '../services/database_service.dart';
import '../services/file_open_service.dart';
import '../services/auth_service.dart';
import 'package:replywise/widgets/ai_reply_widget.dart';

class EmailDetailPage extends StatefulWidget {
  final EmailModel email;
  final List<EmailModel>? emailList;
  final int? currentIndex;

  const EmailDetailPage({
    Key? key,
    required this.email,
    this.emailList,
    this.currentIndex,
  }) : super(key: key);

  @override
  State<EmailDetailPage> createState() => _EmailDetailPageState();
}

class _EmailDetailPageState extends State<EmailDetailPage>
    with TickerProviderStateMixin {
  late int _currentIndex;
  late List<EmailModel> _emails;
  late PageController _pageController;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isLoading = false;
  bool _headerExpanded = false;
  bool _isPersonal = false;
  bool _isImportant = false;
  bool _headerPressed = false; // Add this for live shape animation

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.currentIndex ?? 0;
    _emails = widget.emailList ?? [widget.email];
    _pageController = PageController(initialPage: _currentIndex);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _loadFullEmailIfNeeded(_emails[_currentIndex]);
    _animationController.forward();
  }

  Future<void> _loadFullEmailIfNeeded(EmailModel email) async {
    if (email.body != null && email.body!.isNotEmpty && email.attachments.isNotEmpty) return;
    setState(() => _isLoading = true);
    try {
      final fullEmail = await EmailService().loadFullEmailContent(email.id);
      final idx = _emails.indexWhere((e) => e.id == email.id);
      if (idx != -1) setState(() => _emails[idx] = fullEmail);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = _emails[_currentIndex];
    _isPersonal = DatabaseService().isPersonal(email.senderEmail);
    _isImportant = DatabaseService().isImportant(email.id);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        titleSpacing: 0,
        leading: IconButton(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedArrowLeft01,
            size: 29.sp,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // Personal Button
          IconButton(
            icon: Container(
              decoration: BoxDecoration(
                color: _isPersonal
                    ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.9)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30.r),
                border: _isPersonal
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              padding: EdgeInsets.all(4),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedUser02,
                size: 24.0,
                color: _isPersonal
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            tooltip: 'Personal',
            onPressed: () async {
              final senderEmail = email.senderEmail;
              final newValue = !DatabaseService().isPersonal(senderEmail);
              if (newValue) {
                await DatabaseService().markPersonal(senderEmail);
              } else {
                await DatabaseService().unmarkPersonal(senderEmail);
              }
              setState(() {});
            },
          ),
          // Important Button
          IconButton(
            icon: Container(
              decoration: BoxDecoration(
                color: _isImportant
                    ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.9)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(30.r),
                border: _isImportant
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
              ),
              padding: EdgeInsets.all(4),
              child: HugeIcon(
                icon: HugeIcons.strokeRoundedStar,
                size: 24.0,
                color: _isImportant
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
            tooltip: 'Important',
            onPressed: () async {
              final newValue = !DatabaseService().isImportant(email.id);
              if (newValue) {
                await DatabaseService().markImportant(email.id);
              } else {
                await DatabaseService().unmarkImportant(email.id);
              }
              setState(() {});
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
            : LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth > 600;
                  return SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 48.w : 12.w,
                        vertical: 18.h,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Subject
                          Text(
                            email.subject.isNotEmpty ? email.subject : "(no subject)",
                            style: TextStyle(
                              fontSize: isWide ? 28.sp : 22.sp,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 18.h),
                          // Sender Card (animated border radius: pill <-> boxy, live shape change)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _headerExpanded = !_headerExpanded;
                              });
                            },
                            onTapDown: (_) {
                              setState(() {
                                _headerPressed = true;
                              });
                            },
                            onTapUp: (_) {
                              setState(() {
                                _headerPressed = false;
                              });
                            },
                            onTapCancel: () {
                              setState(() {
                                _headerPressed = false;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400), // slower shape change
                              curve: Curves.easeInOut,
                              margin: EdgeInsets.zero,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(
                                  _headerPressed
                                      ? 32.r
                                      : (_headerExpanded ? 16.r : 999.r)
                                ),
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.primary.withOpacity(
                                    _headerPressed
                                      ? 0.28
                                      : (_headerExpanded ? 0.18 : 0.15)
                                  ),
                                  width: _headerPressed ? 2.2 : 1.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(_headerPressed ? 0.09 : 0.04),
                                    blurRadius: _headerPressed ? 8 : 4,
                                    offset: Offset(0, _headerPressed ? 4 : 2),
                                  ),
                                ],
                              ),
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: isWide ? 28.r : 22.r,
                                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                                    child: Text(
                                      (email.sender.isNotEmpty
                                              ? email.sender[0]
                                              : (email.subject.isNotEmpty ? email.subject[0] : '?'))
                                          .toUpperCase(),
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: isWide ? 22.sp : 18.sp,
                                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Text(
                                              email.sender.isNotEmpty ? email.sender : "Unknown Sender",
                                              style: TextStyle(
                                                fontSize: isWide ? 18.sp : 15.sp,
                                                fontWeight: FontWeight.w700,
                                                color: Theme.of(context).colorScheme.onSurface,
                                              ),
                                            ),
                                            if (_isPersonal)
                                              Padding(
                                                padding: EdgeInsets.only(left: 6.w),
                                                child: Icon(
                                                  HugeIcons.strokeRoundedUser02,
                                                  size: 16.sp,
                                                  color: Theme.of(context).colorScheme.primary,
                                                ),
                                              ),
                                            if (_isImportant)
                                              Padding(
                                                padding: EdgeInsets.only(left: 4.w),
                                                child: Icon(
                                                  HugeIcons.strokeRoundedStar,
                                                  size: 15.sp,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                          ],
                                        ),
                                        SizedBox(height: 2.h),
                                        Text(
                                          email.senderEmail,
                                          style: TextStyle(
                                            fontSize: isWide ? 14.sp : 12.sp,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                        if (_headerExpanded) ...[
                                          SizedBox(height: 10.h),
                                          Divider(height: 1, color: Theme.of(context).dividerColor),
                                          SizedBox(height: 8.h),
                                          Text(
                                            "From: ${email.senderEmail}",
                                            style: TextStyle(
                                              fontSize: isWide ? 15.sp : 13.sp,
                                              color: Theme.of(context).colorScheme.onSurface,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            "Received: ${_shortDate(DateTime.tryParse(email.time) ?? DateTime.now())}",
                                            style: TextStyle(
                                              fontSize: isWide ? 13.sp : 11.sp,
                                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  Column(
                                    children: [
                                      AnimatedRotation(
                                        turns: _headerExpanded ? 0.5 : 0.0,
                                        duration: Duration(milliseconds: 200),
                                        child: Icon(
                                          Icons.keyboard_arrow_down_rounded,
                                          size: isWide ? 32.sp : 26.sp,
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      // Only show the date if not expanded
                                      if (!_headerExpanded)
                                        Text(
                                          _shortDate(DateTime.tryParse(email.time) ?? DateTime.now()),
                                          style: TextStyle(
                                            fontSize: isWide ? 13.sp : 11.sp,
                                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 18.h),
                          // Attachments grid (if any)
                          if (email.attachments.isNotEmpty)
                            Padding(
                              padding: EdgeInsets.zero,
                              child: Container(
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.13),
                                  borderRadius: BorderRadius.circular(18.r),
                                  border: Border.all(
                                    color: Theme.of(context).colorScheme.outline.withOpacity(0.10),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.03),
                                      blurRadius: 6,
                                      offset: Offset(0, 2),
                                    ),
                                  ],
                                ),
                                // Reduce vertical padding for compactness
                                padding: EdgeInsets.symmetric(horizontal: 0, vertical: 8.h),
                                child: AttachmentGridCard(email: email),
                              ),
                            ),
                          SizedBox(height: 18.h),
                          // Email body
                          _buildBodyContent(email, isWide: isWide),
                          SizedBox(height: 32.h),
                        ],
                      ),
                      ),

                    );
                },
              ),
      ),
      floatingActionButton: Container(
        margin: EdgeInsets.only(bottom: 0, right: 8),
        width: 60.w,
        height: 60.h,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.9),
          borderRadius: BorderRadius.circular(30.r),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: GestureDetector(
            onTap: () {
              showGeneralDialog(
                context: context,
                barrierDismissible: true,
                barrierLabel: "AI Reply",
                transitionDuration: Duration.zero,
                pageBuilder: (context, anim1, anim2) {
                  return SafeArea(
                    child: Material(
                      color: Colors.transparent,
                      child: AiReplyWidget(email: email),
                    ),
                  );
                },
                transitionBuilder: (context, anim1, anim2, child) => child,
              );
            },
            child: Text(
              'RW',
              style: TextStyle(
                fontFamily: 'RW', // Use the custom font from pubspec.yaml
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  String _shortDate(DateTime dt) {
    const days = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"];
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    final dayName = days[(dt.weekday - 1) % 7];
    final monthName = months[dt.month - 1];
    return "$dayName, ${dt.day} $monthName ${dt.year}";
  }

  Widget _buildBodyContent(EmailModel email, {bool isWide = false}) {
    if (_isLoading) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(height: 16.h),
              Text(
                'Loading email content...',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }
    // Show snippet above htmlBody if both exist
    if (email.htmlBody != null &&
        email.htmlBody!.trim().isNotEmpty &&
        (email.htmlBody!.trim().startsWith('<') || email.htmlBody!.contains('<html'))) {
      final htmlContent = email.htmlBody!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (htmlContent.isEmpty && email.snippet.isEmpty) {
        return const SizedBox.shrink();
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (email.snippet.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isWide ? 18.w : 6.w, vertical: 8.h),
              child: Container(
                constraints: BoxConstraints(),
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(0),
                    child: SelectableText(
                      email.snippet,
                      style: TextStyle(
                        fontSize: isWide ? 15.sp : 13.sp,
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isWide ? 24.w : 6.w),
            child: EmailWebViewBody(htmlBody: email.htmlBody!),
          ),
        ],
      );
    }
    if (email.body != null && email.body!.trim().isNotEmpty) {
      final lineCount = '\n'.allMatches(email.body!).length + 1;
      final isSingleLine = lineCount == 1 && !email.body!.contains('\n');
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 18.w : 6.w, vertical: 8.h),
        child: Container(
          constraints: isSingleLine
              ? BoxConstraints(minHeight: 0, maxHeight: 60.h)
              : BoxConstraints(),
          padding: EdgeInsets.symmetric(vertical: isSingleLine ? 8.h : 0),
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(0),
              child: SelectableText(
                email.body!,
                style: TextStyle(
                  fontSize: isWide ? 16.sp : 14.sp,
                  height: 1.6,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: isSingleLine ? 1 : null,
              ),
            ),
          ),
        ),
      );
    }
    if (email.snippet.isNotEmpty) {
      final lineCount = '\n'.allMatches(email.snippet).length + 1;
      final isSingleLine = lineCount == 1 && !email.snippet.contains('\n');
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: isWide ? 18.w : 6.w, vertical: 8.h),
        child: Container(
          constraints: isSingleLine
              ? BoxConstraints(minHeight: 0, maxHeight: 60.h)
              : BoxConstraints(),
          padding: EdgeInsets.symmetric(vertical: isSingleLine ? 8.h : 0),
          child: Scrollbar(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(0),
              child: SelectableText(
                email.snippet,
                style: TextStyle(
                  fontSize: isWide ? 15.sp : 13.sp,
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: isSingleLine ? 1 : null,
              ),
            ),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// Redesigned Attachment Card as a responsive grid
class AttachmentGridCard extends StatelessWidget {
  final EmailModel email;
  const AttachmentGridCard({Key? key, required this.email}) : super(key: key);

  void _onAttachmentTap(BuildContext context, dynamic attachment) async {
    final mimeType = (attachment.mimeType?.toLowerCase() ?? '');
    final filename = attachment.filename ?? '';
    final fileUrl = (attachment.downloadUrl != null && attachment.downloadUrl!.isNotEmpty)
        ? attachment.downloadUrl
        : null;

    // Show loader dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 16),
              Text(
                'Opening attachment...',
                style: TextStyle(
                  fontSize: 16,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      // If fileUrl is a URL, open it in browser or viewer
      if (fileUrl != null && fileUrl.isNotEmpty && (fileUrl.startsWith('http://') || fileUrl.startsWith('https://'))) {
        await FileOpenService.openFile(fileUrl, filename: filename, mimeType: mimeType);
        Navigator.of(context, rootNavigator: true).pop();
        return;
      }

      // If fileUrl is not a URL, treat as Base64URL data (Gmail API returns base64url for attachments)
      if (fileUrl != null && fileUrl.isNotEmpty) {
        await FileOpenService.saveAndOpenBase64Attachment(
          base64UrlData: fileUrl,
          filename: filename.isNotEmpty ? filename : 'attachment',
          mimeType: mimeType,
        );
        Navigator.of(context, rootNavigator: true).pop();
        return;
      }

      // If nothing to open, try to fetch from Gmail API using messageId and attachmentId
      if (email.id.isNotEmpty && attachment.attachmentId.isNotEmpty) {
        final accessToken = await AuthService().getGoogleAccessToken();
        if (accessToken != null) {
          await FileOpenService.fetchSaveAndOpenGmailAttachment(
            messageId: email.id,
            attachmentId: attachment.attachmentId,
            filename: filename.isNotEmpty ? filename : 'attachment',
            accessToken: accessToken,
          );
          Navigator.of(context, rootNavigator: true).pop();
        } else {
          Navigator.of(context, rootNavigator: true).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Google access token not available'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No data found for this attachment.'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to open attachment: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final attachments = email.attachments;
    final crossAxisCount = MediaQuery.of(context).size.width > 600 ? 4 : 2;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: attachments.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 14.w,
        mainAxisSpacing: 14.h,
        childAspectRatio: 1.6, // More compact, less tall
      ),
      itemBuilder: (context, i) {
        final att = attachments[i];
        final isPdf = (att.mimeType.toLowerCase()).contains('pdf');
        return Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.95),
              borderRadius: BorderRadius.circular(16.r), // rounded rectangle
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            child: SizedBox(
              height: 00, // Set attachment card height to 100px
              child: SingleChildScrollView(
                physics: NeverScrollableScrollPhysics(),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPdf ? Icons.picture_as_pdf_rounded : Icons.insert_drive_file_rounded,
                      size: 30.sp,
                      color: isPdf
                          ? Colors.redAccent
                          : Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      att.filename ?? '',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _formatAttachmentSizeStatic(att.size ?? 0),
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6.h),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: Size(0, 28.h),
                          padding: EdgeInsets.symmetric(horizontal: 0),
                          shape: const StadiumBorder(),
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          textStyle: TextStyle(fontSize: 11.sp),
                          elevation: 0,
                        ),
                        onPressed: () => _onAttachmentTap(context, att),
                        child: Text('Open'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Utility for attachment size
String _formatAttachmentSizeStatic(int size) {
  if (size < 1024) return '$size B';
  if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
  return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// Enhanced PDF Viewer Page
class PDFViewerPage extends StatefulWidget {
  final String url;
  final String filename;
  
  const PDFViewerPage({
    required this.url,
    required this.filename,
    Key? key,
  }) : super(key: key);

  @override
  State<PDFViewerPage> createState() => _PDFViewerPageState();
}

class _PDFViewerPageState extends State<PDFViewerPage> {
  int _currentPage = 1;
  int _totalPages = 0;
  bool _isLoading = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.filename,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (!_isLoading && _totalPages > 0)
              Text(
                'Page $_currentPage of $_totalPages',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.download),
            onPressed: () async {
              if (await canLaunchUrl(Uri.parse(widget.url))) {
                await launchUrl(Uri.parse(widget.url));
              }
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          SfPdfViewer.network(
            widget.url,
            onDocumentLoaded: (details) {
              setState(() {
                _totalPages = details.document.pages.count;
                _isLoading = false;
              });
            },
            onPageChanged: (details) {
              setState(() {
                _currentPage = details.newPageNumber;
              });
            },
          ),
          if (_isLoading)
            Center(
              child: Container(
                padding: EdgeInsets.all(32.w),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      'Loading PDF...',
                      style: TextStyle(
                        fontSize: 16.sp,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class EmailWebViewBody extends StatefulWidget {
  final String htmlBody;
  const EmailWebViewBody({Key? key, required this.htmlBody}) : super(key: key);

  @override
  State<EmailWebViewBody> createState() => _EmailWebViewBodyState();
}

class _EmailWebViewBodyState extends State<EmailWebViewBody> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final injectedHtml = '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no, maximum-scale=1.0, minimum-scale=1.0">
  <style>
    html, body {
      height: 100%;
      margin: 0;
      padding: 0;
      font-family: sans-serif;
      box-sizing: border-box;
      width: 100vw;
      overflow-x: hidden !important;
      zoom: 1 !important;
    }
    #contentWrapper {
      min-height: 100vh;
      box-sizing: border-box;
      width: 100vw;
      overflow-x: hidden !important;
    }
    * {
      max-width: 100vw !important;
      box-sizing: border-box;
    }
    a, button { cursor: pointer !important; }
  </style>
</head>
<body>
<div id="contentWrapper">
${widget.htmlBody}
</div>
</body>
</html>
''';
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            // Only allow initial load, open all other links externally in the mobile default browser
            if (!request.url.startsWith('data:text/html')) {
              try {
                final uri = Uri.parse(request.url);
                // Always open in the default browser (external non-in-app browser)
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                // Optionally handle error (e.g., show a snackbar)
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadHtmlString(injectedHtml);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width, // fill full width
        height: MediaQuery.of(context).size.height * 0.65,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.15),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.08),
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16.r),
          child: WebViewWidget(controller: _controller),
        ),
      ),
    );
  }
}

// Add a new page for generic file preview
class FilePreviewPage extends StatelessWidget {
  final String url;
  final String filename;
  final String? mimeType;
  const FilePreviewPage({
    Key? key,
    required this.url,
    required this.filename,
    this.mimeType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isTxt = filename.toLowerCase().endsWith('.txt') || (mimeType ?? '').contains('text/plain');
    final isPy = filename.toLowerCase().endsWith('.py') || (mimeType ?? '').contains('python');
    final isHtml = filename.toLowerCase().endsWith('.html') || (mimeType ?? '').contains('text/html');
    return Scaffold(
      appBar: AppBar(
        title: Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis),
      ),
      body: FutureBuilder<http.Response>(
        future: http.get(Uri.parse(url)),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return Center(child: CircularProgressIndicator());
          }
          final content = utf8.decode(snap.data!.bodyBytes);
          if (isHtml) {
            return EmailWebViewBody(htmlBody: content);
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Scrollbar(
              child: SingleChildScrollView(
                child: SelectableText(
                  content,
                  style: TextStyle(
                    fontFamily: isPy ? 'monospace' : null,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

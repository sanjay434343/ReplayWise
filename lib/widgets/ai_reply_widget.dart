import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/email_model.dart';
import '../services/ai_reply_generator.dart';

class AiReplyWidget extends StatefulWidget {
  final EmailModel email;

  const AiReplyWidget({
    Key? key,
    required this.email,
  }) : super(key: key);

  @override
  State<AiReplyWidget> createState() => _AiReplyWidgetState();
}

class _AiReplyWidgetState extends State<AiReplyWidget>
    with TickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnimation;

  final AIReplyGenerator _aiGenerator = AIReplyGenerator();
  final TextEditingController _customPromptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  ReplyTone _selectedTone = ReplyTone.professional;
  ReplyLength _selectedLength = ReplyLength.medium;
  
  List<AIReplyResponse> _generatedReplies = [];
  List<String> _quickReplies = [];
  int _selectedReplyIndex = 0;
  bool _isGenerating = false;
  bool _showCustomPrompt = false;
  bool _showAdvancedOptions = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _loadQuickReplies();
    // Do NOT generate a reply automatically here
    // _generateInitialReply();
  }

  void _setupAnimations() {
    _slideController = AnimationController(
      duration: Duration(milliseconds: 800),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _slideController,
      curve: Curves.easeOutCubic,
    ));

    _fadeController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _bounceController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );
    _bounceAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    ));

    _shimmerController = AnimationController(
      duration: Duration(milliseconds: 1500),
      vsync: this,
    );
    _shimmerAnimation = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _shimmerController,
      curve: Curves.easeInOut,
    ));

    // Start animations
    _slideController.forward();
    _fadeController.forward();
    _bounceController.forward();
    
    if (_isGenerating) {
      _shimmerController.repeat();
    }
  }

  void _loadQuickReplies() {
    _quickReplies = [
      "Thank you! 🙏",
      "Got it, thanks! ✓",
      "Will do! 💪",
      "Sounds good! 👍",
      "Thanks for the update 📝",
      "Noted, thank you ✅",
      "Perfect, thanks! ⭐",
      "I'll get back to you soon 🔄",
    ];

    // Add context-specific quick replies based on email content
    String snippet = widget.email.snippet.toLowerCase();
    String subject = widget.email.subject.toLowerCase();

    if (snippet.contains("meeting") || subject.contains("meeting")) {
      _quickReplies.insertAll(0, [
        "I'll be there! 📅",
        "Thanks for the meeting invite 🤝",
        "Looking forward to it! 🚀",
      ]);
    }

    if (snippet.contains("deadline") || snippet.contains("urgent")) {
      _quickReplies.insertAll(0, [
        "I'll prioritize this ⚡",
        "Will handle this ASAP 🔥",
        "Understood, rushing on this 🏃",
      ]);
    }

    if (snippet.contains("question") || subject.contains("question")) {
      _quickReplies.insertAll(0, [
        "Let me check and get back to you 🔍",
        "I'll look into this for you 🕵️",
        "Good question! Let me research this 📚",
      ]);
    }

    _quickReplies = _quickReplies.take(8).toList();
  }

  Future<void> _generateInitialReply() async {
    await _generateReplies();
  }

  Future<void> _generateReplies() async {
    setState(() {
      _isGenerating = true;
    });

    _shimmerController.repeat();
    HapticFeedback.lightImpact();

    try {
      final replies = await _aiGenerator.generateMultipleReplies(
        originalEmail: widget.email,
        tone: _selectedTone,
        length: _selectedLength,
        count: 3,
        customPrompt: _customPromptController.text.trim().isNotEmpty
            ? _customPromptController.text.trim()
            : null,
      );

      setState(() {
        _generatedReplies = replies;
        _selectedReplyIndex = 0;
        _isGenerating = false;
      });

      _shimmerController.stop();
      _bounceController.reset();
      _bounceController.forward();
      HapticFeedback.mediumImpact();

      if (replies.isEmpty) {
        _showCustomSnackBar(
          'No replies could be generated. Please try again.',
          Icons.warning_amber_rounded,
          Colors.orange,
        );
      }
    } catch (e) {
      setState(() {
        _isGenerating = false;
      });
      
      _shimmerController.stop();
      HapticFeedback.heavyImpact();
      
      _showCustomSnackBar(
        'Failed to generate reply. Please check your internet connection and try again.',
        Icons.error_outline_rounded,
        Colors.red,
      );
    }
  }

  void _showCustomSnackBar(String message, IconData icon, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20.sp),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        margin: EdgeInsets.all(16.w),
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _closeWithAnimation() async {
    HapticFeedback.lightImpact();
    await _fadeController.reverse();
    await _slideController.reverse();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _slideController.dispose();
    _fadeController.dispose();
    _bounceController.dispose();
    _shimmerController.dispose();
    _customPromptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: Column(
              children: [
                _buildModernAppBar(),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    physics: BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 8.h),
                          _buildEmailContextCard(),
                          SizedBox(height: 20.h),
                          _buildQuickRepliesSection(),
                          SizedBox(height: 20.h),
                          _buildControlsSection(),
                          SizedBox(height: 20.h),
                          _buildGeneratedReplySection(),
                          SizedBox(height: 100.h), // Bottom padding for FAB
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _buildFloatingActionButtons(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildModernAppBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _closeWithAnimation,
            child: Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.arrow_back_ios_rounded,
                color: Theme.of(context).colorScheme.onSurface,
                size: 18.sp,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Container(
            width: 36.w,
            height: 36.h,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              HugeIcons.strokeRoundedArtificialIntelligence02,
              size: 20.sp,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Replywise AI',
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Smart. Fast. Polite.',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontStyle: FontStyle.italic,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _closeWithAnimation,
            child: Container(
              width: 40.w,
              height: 40.h,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                Icons.close_rounded,
                color: Theme.of(context).colorScheme.onSurface,
                size: 18.sp,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailContextCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mail_outline_rounded,
                size: 18.sp,
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(width: 8.w),
              Text(
                'Replying to',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            widget.email.sender,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            widget.email.subject,
            style: TextStyle(
              fontSize: 13.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (widget.email.snippet.isNotEmpty) ...[
            SizedBox(height: 8.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                widget.email.snippet,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickRepliesSection() {
    if (_quickReplies.isEmpty) return SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Replies',
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        SizedBox(height: 12.h),
        SizedBox(
          height: 42.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: BouncingScrollPhysics(),
            itemCount: _quickReplies.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (_, i) => _buildQuickReplyChip(_quickReplies[i]),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickReplyChip(String reply) {
    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();

        // Directly open the email app with the quick reply as the body
        final mailtoUrl = _generateMailtoUrl(
          toEmail: _extractSenderEmail(),
          subject: widget.email.subject,
          replyContent: reply,
        );
        final launched = await launchUrl(Uri.parse(mailtoUrl));

        if (launched) {
          _showCustomSnackBar(
            'Opening email client with quick reply',
            Icons.check_circle_outline_rounded,
            Colors.green,
          );
        } else {
          _showCustomSnackBar(
            'Failed to open email client',
            Icons.error_outline_rounded,
            Colors.red,
          );
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primaryContainer,
              Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              reply,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            // Remove extra gap below the text
          ],
        ),
      ),
    );
  }

  Widget _buildControlsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'AI Settings',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            Spacer(),
            GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _showAdvancedOptions = !_showAdvancedOptions);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showAdvancedOptions ? Icons.keyboard_arrow_up_rounded : Icons.tune_rounded,
                      size: 16.sp,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      _showAdvancedOptions ? 'Less' : 'More',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        _buildGenerateButton(),
        if (_showAdvancedOptions) ...[
          SizedBox(height: 16.h),
          _buildAdvancedOptions(),
        ],
      ],
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      width: double.infinity,
      height: 50.h,
      child: ElevatedButton(
        onPressed: _isGenerating ? null : _generateReplies,
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: 4,
          shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
        child: _isGenerating
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20.w,
                    height: 20.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Text(
                    'Generating...',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome_rounded, size: 20.sp),
                  SizedBox(width: 8.w),
                  Text(
                    'Generate AI Reply',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildAdvancedOptions() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdownCard(
                  'Tone',
                  _selectedTone.name.capitalize(),
                  Icons.palette_outlined,
                  () => _showToneSelector(),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildDropdownCard(
                  'Length',
                  _selectedLength.name.capitalize(),
                  Icons.short_text_rounded,
                  () => _showLengthSelector(),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() => _showCustomPrompt = !_showCustomPrompt);
            },
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: _showCustomPrompt
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                    : Theme.of(context).colorScheme.surface.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: _showCustomPrompt
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                      : Theme.of(context).colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.edit_rounded,
                    size: 18.sp,
                    color: _showCustomPrompt
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Custom Instructions',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                      color: _showCustomPrompt
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Spacer(),
                  Icon(
                    _showCustomPrompt ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    size: 18.sp,
                    color: _showCustomPrompt
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
                ],
              ),
            ),
          ),
          if (_showCustomPrompt) ...[
            SizedBox(height: 12.h),
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                ),
              ),
              child: TextField(
                controller: _customPromptController,
                decoration: InputDecoration(
                  hintText: 'Add specific instructions for the AI...',
                  hintStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14.sp,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16.w),
                ),
                maxLines: 3,
                style: TextStyle(fontSize: 14.sp),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownCard(String title, String value, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16.sp, color: Theme.of(context).colorScheme.primary),
                SizedBox(width: 6.w),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratedReplySection() {
    if (_generatedReplies.isEmpty && !_isGenerating) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.all(32.w),
        child: Column(
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 48.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            SizedBox(height: 16.h),
            Text(
              'Ready to generate your reply',
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'Tap "Generate AI Reply" to create a personalized response',
              style: TextStyle(
                fontSize: 14.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_isGenerating) {
      return _buildLoadingCard();
    }

    return _buildReplyCard();
  }

  Widget _buildLoadingCard() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return Container(
          width: double.infinity,
          height: 200.h,
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
                Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              ],
              stops: [0.0, 0.5, 1.0],
              begin: Alignment(_shimmerAnimation.value, 0.0),
              end: Alignment(_shimmerAnimation.value + 1.0, 0.0),
            ),
            borderRadius: BorderRadius.circular(20.r),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
              ),
              SizedBox(height: 20.h),
              Text(
                'AI is crafting your reply...',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'This may take a few moments',
                style: TextStyle(
                  fontSize: 14.sp,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildReplyCard() {
    final reply = _generatedReplies[_selectedReplyIndex];
    
    return ScaleTransition(
      scale: _bounceAnimation,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
              Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 18.sp,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Generated Reply',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${(reply.confidence * 100).toInt()}% confidence',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_generatedReplies.length > 1) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Text(
                      '${_selectedReplyIndex + 1}/${_generatedReplies.length}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            SizedBox(height: 20.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.1),
                ),
              ),
              child: SelectableText(
                reply.content,
                style: TextStyle(
                  fontSize: 15.sp,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.5,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (_generatedReplies.length > 1) ...[
              SizedBox(height: 16.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _selectedReplyIndex > 0
                        ? () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedReplyIndex--);
                          }
                        : null,
                    child: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: _selectedReplyIndex > 0
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        size: 20.sp,
                        color: _selectedReplyIndex > 0
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                  ),
                  SizedBox(width: 20.w),
                  ...List.generate(
                    _generatedReplies.length,
                    (index) => Container(
                      margin: EdgeInsets.symmetric(horizontal: 4.w),
                      width: 8.w,
                      height: 8.h,
                      decoration: BoxDecoration(
                        color: index == _selectedReplyIndex
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceVariant,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                  ),
                  SizedBox(width: 20.w),
                  GestureDetector(
                    onTap: _selectedReplyIndex < _generatedReplies.length - 1
                        ? () {
                            HapticFeedback.lightImpact();
                            setState(() => _selectedReplyIndex++);
                          }
                        : null,
                    child: Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: _selectedReplyIndex < _generatedReplies.length - 1
                            ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                            : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(
                        Icons.chevron_right_rounded,
                        size: 20.sp,
                        color: _selectedReplyIndex < _generatedReplies.length - 1
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    if (_generatedReplies.isEmpty) return SizedBox();
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50.h,
              child: ElevatedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  try {
                    final replyContent = _generatedReplies[_selectedReplyIndex].content;
                    await Clipboard.setData(ClipboardData(text: replyContent));
                    _showCustomSnackBar(
                      'Reply copied to clipboard',
                      Icons.check_circle_outline_rounded,
                      Colors.green,
                    );
                  } catch (e) {
                    _showCustomSnackBar(
                      'Failed to copy reply',
                      Icons.error_outline_rounded,
                      Colors.red,
                    );
                  }
                },
                icon: Icon(Icons.copy_rounded, size: 18.sp),
                label: Text(
                  'Copy',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                  foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            flex: 2,
            child: Container(
              height: 50.h,
              child: ElevatedButton.icon(
                onPressed: () => _handleSendReply(),
                icon: Icon(Icons.send_rounded, size: 18.sp),
                label: Text(
                  'Send Reply',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  elevation: 4,
                  shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSendReply() async {
    HapticFeedback.mediumImpact();
    
    // Show elegant loading overlay
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Container(
        color: Colors.black.withOpacity(0.3),
        child: Center(
          child: Container(
            margin: EdgeInsets.all(20.w),
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(20.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).colorScheme.primary),
                ),
                SizedBox(height: 20.h),
                Text(
                  'Opening Gmail...',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'Preparing your reply',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      String senderEmail = _extractSenderEmail();
      final selectedReply = _generatedReplies[_selectedReplyIndex];
      
      final mailtoUrl = _generateMailtoUrl(
        toEmail: senderEmail,
        subject: widget.email.subject,
        replyContent: selectedReply.content,
      );
      
      print('Generated mailto URL: $mailtoUrl');
      print('Replying to: $senderEmail');
      
      final launched = await launchUrl(Uri.parse(mailtoUrl));
      
      if (mounted) Navigator.of(context).pop();
      
      if (launched) {
        await _closeWithAnimation();
        _showCustomSnackBar(
          'Opening Gmail with reply to $senderEmail',
          Icons.check_circle_outline_rounded,
          Colors.green,
        );
      } else {
        _showCustomSnackBar(
          'Failed to open Gmail. Please check if Gmail is installed.',
          Icons.error_outline_rounded,
          Colors.red,
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(context).pop();
      
      print('Error launching email reply: $e');
      _showCustomSnackBar(
        'Error opening Gmail: ${e.toString()}',
        Icons.error_outline_rounded,
        Colors.red,
      );
    }
  }

  void _showToneSelector() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Select Tone',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 16.h),
            ...ReplyTone.values.map((tone) => ListTile(
              leading: Icon(
                _getToneIcon(tone),
                color: tone == _selectedTone 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(
                tone.name.capitalize(),
                style: TextStyle(
                  fontWeight: tone == _selectedTone ? FontWeight.w600 : FontWeight.normal,
                  color: tone == _selectedTone 
                      ? Theme.of(context).colorScheme.primary 
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedTone = tone);
                Navigator.pop(context);
              },
            )).toList(),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  void _showLengthSelector() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 12.h),
            Container(
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              'Select Length',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 16.h),
            ...ReplyLength.values.map((length) => ListTile(
              leading: Icon(
                _getLengthIcon(length),
                color: length == _selectedLength 
                    ? Theme.of(context).colorScheme.primary 
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              title: Text(
                length.name.capitalize(),
                style: TextStyle(
                  fontWeight: length == _selectedLength ? FontWeight.w600 : FontWeight.normal,
                  color: length == _selectedLength 
                      ? Theme.of(context).colorScheme.primary 
                      : Theme.of(context).colorScheme.onSurface,
                ),
              ),
              onTap: () {
                HapticFeedback.lightImpact();
                setState(() => _selectedLength = length);
                Navigator.pop(context);
              },
            )).toList(),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  IconData _getToneIcon(ReplyTone tone) {
    switch (tone) {
      case ReplyTone.professional:
        return Icons.business_rounded;
      case ReplyTone.casual:
        return Icons.chat_bubble_outline_rounded;
      case ReplyTone.friendly:
        return Icons.sentiment_satisfied_rounded;
      default:
        return Icons.palette_outlined;
    }
  }

  IconData _getLengthIcon(ReplyLength length) {
    switch (length) {
      case ReplyLength.short:
        return Icons.short_text_rounded;
      case ReplyLength.medium:
        return Icons.text_fields_rounded;
      case ReplyLength.long:
        return Icons.article_outlined;
      default:
        return Icons.short_text_rounded;
    }
  }

  // Helper method to extract sender's email address
  String _extractSenderEmail() {
    if (widget.email.senderEmail.isNotEmpty && 
        widget.email.senderEmail.contains('@')) {
      return widget.email.senderEmail;
    }
    final senderField = widget.email.sender;
    if (senderField.contains('@')) {
      // Check if it's in format "Name <email@domain.com>"
      final emailRegex = RegExp(r'<([^>]+@[^>]+)>');
      final match = emailRegex.firstMatch(senderField);
      if (match != null) {
        return match.group(1)!.trim();
      }
      
      // Check if it's just an email address
      final simpleEmailRegex = RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b');
      final emailMatch = simpleEmailRegex.firstMatch(senderField);
      if (emailMatch != null) {
        return emailMatch.group(0)!.trim();
      }
    }
    
    // Fallback: return the sender field as is (might not work but better than nothing)
    return widget.email.sender.isNotEmpty 
        ? widget.email.sender 
        : 'unknown@example.com';
  }

  // Helper method to generate mailto URL
  String _generateMailtoUrl({
    required String toEmail,
    required String subject,
    required String replyContent,
  }) {
    // Clean up the email address
    String cleanEmail = toEmail.trim().replaceAll(RegExp(r'^<|>$'), '');

    // Generate subject with proper Re: prefix
    String replySubject = subject.trim();
    if (replySubject.isEmpty) {
      replySubject = 'No Subject';
    }
    if (!replySubject.toLowerCase().startsWith('re:')) {
      replySubject = 'Re: $replySubject';
    }

    // Add context to the reply content
    String enhancedReplyContent = replyContent;

    // Add a separator and original email reference
    enhancedReplyContent += '\n\n';
    enhancedReplyContent += '--- Original Message ---\n';
    enhancedReplyContent += 'From: ${widget.email.sender}\n';
    enhancedReplyContent += 'Subject: ${widget.email.subject}\n';
    enhancedReplyContent += 'Date: ${widget.email.time}\n\n';
    if (widget.email.snippet.isNotEmpty) {
      enhancedReplyContent += '${widget.email.snippet}\n';
    }

    // URL encode the parameters properly
    String encodedTo = Uri.encodeComponent(cleanEmail);
    String encodedSubject = Uri.encodeComponent(replySubject);
    String encodedBody = Uri.encodeComponent(enhancedReplyContent);

    return 'mailto:$encodedTo?subject=$encodedSubject&body=$encodedBody';
  }
}

// Add this extension for capitalization
extension StringCap on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
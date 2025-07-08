import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart'; // Add this import
import '../services/user_settings_database_service.dart'; // <-- Add this import
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart'; // <-- Add this import

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  bool _isSigningOut = false;
  late AnimationController _fabAnimationController;
  late AnimationController _profileAnimationController;
  bool _showEmailPrefs = false;
  String _signature = '';
  final _signatureController = TextEditingController();
  bool _savingSignature = false;
  bool _signatureSaved = false;

  @override
  void initState() {
    super.initState();
    _fabAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _profileAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    
    // Start animations
    _profileAnimationController.forward();

    // Initialize signature with user's display name and email by default
    final user = _authService.currentUser;
    _signature = ((user?.displayName ?? '') +
        (user?.email != null ? '\n${user!.email}' : '')).trim();
    _signatureController.text = _signature;

    _loadSignature();
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    _profileAnimationController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  Future<void> _signOut() async {
    setState(() {
      _isSigningOut = true;
    });

    try {
      await _authService.signOut();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20.sp,
                ),
                SizedBox(width: 12.w),
                const Text('Signed out successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
        context.go('/login');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  Icons.error_rounded,
                  color: Colors.white,
                  size: 20.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(child: Text('Sign out failed: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  void _showSignOutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28.r),
          ),
          icon: Icon(
            Icons.logout_rounded,
            color: Theme.of(context).colorScheme.error,
            size: 32.sp,
          ),
          title: Text(
            'Sign Out',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out of your account?',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _signOut();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Sign Out'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _loadSignature() async {
    // Use the new UserSettingsDatabaseService
    final saved = await UserSettingsDatabaseService().getUserSignature();
    if (mounted) {
      setState(() {
        if (saved != null && saved.trim().isNotEmpty) {
          _signature = saved;
          _signatureController.text = saved;
          _signatureSaved = true;
        } else {
          final user = _authService.currentUser;
          _signature = ((user?.displayName ?? '') +
              (user?.email != null ? '\n${user!.email}' : '')).trim();
          _signatureController.text = _signature;
          _signatureSaved = false;
        }
      });
    }
  }

  Future<void> _saveSignature() async {
    setState(() {
      _savingSignature = true;
    });
    try {
      await UserSettingsDatabaseService().saveUserSignature(_signature);
      if (mounted) {
        setState(() {
          _signatureSaved = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Signature saved!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save signature: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _savingSignature = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _authService.currentUser;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => Scaffold(
        backgroundColor: colorScheme.background,
        body: CustomScrollView(
          slivers: [
            // Modern App Bar with custom layout
            SliverAppBar(
              backgroundColor: colorScheme.surface,
              surfaceTintColor: colorScheme.surfaceTint,
              foregroundColor: colorScheme.onSurface,
              elevation: 0,
              pinned: true,
              floating: false,
              snap: false,
              toolbarHeight: 64.h,
              automaticallyImplyLeading: false,
              titleSpacing: 0,
              title: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: HugeIcon(
                        icon: HugeIcons.strokeRoundedArrowLeft01,
                        size: 24.sp,
                        color: colorScheme.onSurface,
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      'Settings',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Main content
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Enhanced User Profile Section
                    _buildProfileSection(user, colorScheme, theme)
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 100.ms)
                        .slideY(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
                    
                    SizedBox(height: 32.h),
                    
                    // Settings Section Header
                    Text(
                      'Preferences',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onBackground,
                      ),
                    ).animate()
                        .fadeIn(duration: 600.ms, delay: 300.ms)
                        .slideX(begin: -0.2, end: 0),
                    
                    SizedBox(height: 16.h),
                    
                    // Settings Items with staggered animations
                    ..._buildSettingsItems(colorScheme, theme),
                    
                    SizedBox(height: 32.h),
                    
                    // Enhanced Sign Out Button
                    _buildSignOutButton(colorScheme, theme)
                        .animate()
                        .fadeIn(duration: 600.ms, delay: 800.ms)
                        .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
                    
                    SizedBox(height: 32.h),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection(user, ColorScheme colorScheme, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.surfaceContainerHighest,
            colorScheme.surfaceContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(
          color: colorScheme.outline.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Enhanced Profile Picture with ripple effect
          Hero(
            tag: 'profile_avatar',
            child: Container(
              width: 96.w,
              height: 96.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(48.r),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colorScheme.primary.withOpacity(0.2),
                    colorScheme.secondary.withOpacity(0.1),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withOpacity(0.2),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: user?.photoURL != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(48.r),
                      child: Image.network(
                        user!.photoURL!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Center(
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedUser,
                        size: 48.sp,
                        color: colorScheme.primary,
                      ),
                    ),
            ),
          ),
          SizedBox(height: 20.h),
          
          // User Name with enhanced typography
          Text(
            user?.displayName ?? 'Unknown User',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8.h),
          
          // User Email with chip-like styling
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(
                color: colorScheme.outline.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.email_rounded,
                  size: 16.sp,
                  color: colorScheme.onSurfaceVariant,
                ),
                SizedBox(width: 8.w),
                Text(
                  user?.email ?? 'No email',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSettingsItems(ColorScheme colorScheme, ThemeData theme) {
    final items = [
      {
        'icon': HugeIcons.strokeRoundedMail01,
        'title': 'Email Preferences',
        'subtitle': 'Configure email signature',
        'color': colorScheme.secondary,
      },
      {
        'icon': HugeIcons.strokeRoundedInformationCircle,
        'title': 'About',
        'subtitle': 'App version and information',
        'color': colorScheme.error,
      },
    ];

    List<Widget> widgets = [];

    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (item['title'] == 'Email Preferences') {
        widgets.add(
          _buildSettingsItem(
            icon: item['icon'] as IconData,
            title: item['title'] as String,
            subtitle: item['subtitle'] as String,
            iconColor: item['color'] as Color,
            onTap: () {
              setState(() {
                _showEmailPrefs = !_showEmailPrefs;
              });
            },
            trailing: Icon(
              _showEmailPrefs
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 20.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ).animate()
              .fadeIn(duration: 600.ms, delay: (400 + i * 100).ms)
              .slideX(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
        );
        if (_showEmailPrefs) {
          widgets.add(
            Padding(
              padding: EdgeInsets.only(left: 12.w, right: 12.w, bottom: 12.h),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: colorScheme.outline.withOpacity(0.08),
                  ),
                ),
                padding: EdgeInsets.all(16.w),
                child: _signatureSaved
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Signature',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                            decoration: BoxDecoration(
                              color: colorScheme.surface,
                              borderRadius: BorderRadius.circular(8.r),
                              border: Border.all(
                                color: colorScheme.outline.withOpacity(0.10),
                              ),
                            ),
                            child: Text(
                              _signature,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _signatureSaved = false;
                                });
                              },
                              icon: Icon(Icons.edit, size: 18),
                              label: Text('Edit'),
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Signature',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          TextField(
                            controller: _signatureController,
                            maxLines: 3,
                            minLines: 1,
                            decoration: InputDecoration(
                              hintText: 'Enter your email signature',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                            ),
                            onChanged: (val) {
                              setState(() {
                                _signature = val;
                              });
                            },
                          ),
                          SizedBox(height: 12.h),
                          Align(
                            alignment: Alignment.centerRight,
                            child: ElevatedButton.icon(
                              onPressed: _savingSignature ? null : _saveSignature,
                              icon: _savingSignature
                                  ? SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: colorScheme.onPrimary,
                                      ),
                                    )
                                  : Icon(Icons.save_rounded, size: 18),
                              label: Text('Save'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          );
        }
      } else if (item['title'] == 'About') {
        widgets.add(
          _buildSettingsItem(
            icon: item['icon'] as IconData,
            title: item['title'] as String,
            subtitle: item['subtitle'] as String,
            iconColor: item['color'] as Color,
            onTap: () {
              showModalBottomSheet(
                context: context,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
                ),
                backgroundColor: colorScheme.surface,
                builder: (context) => _AboutSheet(theme: theme, colorScheme: colorScheme),
              );
            },
          ).animate()
              .fadeIn(duration: 600.ms, delay: (400 + i * 100).ms)
              .slideX(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
        );
      } else {
        widgets.add(
          _buildSettingsItem(
            icon: item['icon'] as IconData,
            title: item['title'] as String,
            subtitle: item['subtitle'] as String,
            iconColor: item['color'] as Color,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${item['title']} - Coming soon'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              );
            },
          ).animate()
              .fadeIn(duration: 600.ms, delay: (400 + i * 100).ms)
              .slideX(begin: 0.3, end: 0, curve: Curves.easeOutCubic),
        );
      }
    }
    return widgets;
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(0.12),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                // Enhanced icon with background
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: icon,
                      size: 24.sp,
                      color: iconColor,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrow icon or custom trailing
                if (trailing != null) trailing,
                if (trailing == null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16.sp,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSignOutButton(ColorScheme colorScheme, ThemeData theme) {
    return Container(
      width: double.infinity,
      height: 56.h,
      decoration: BoxDecoration(
        color: colorScheme.error,
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16.r),
          onTap: _isSigningOut ? null : _showSignOutDialog,
          child: Center(
            child: _isSigningOut
                ? SizedBox(
                    width: 24.w,
                    height: 24.h,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: colorScheme.onError,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        size: 24.sp,
                        color: colorScheme.onError,
                      ),
                      SizedBox(width: 12.w),
                      Text(
                        'Sign Out',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onError,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// --- About Sheet Widget ---
class _AboutSheet extends StatefulWidget {
  final ThemeData theme;
  final ColorScheme colorScheme;
  const _AboutSheet({required this.theme, required this.colorScheme});

  @override
  State<_AboutSheet> createState() => _AboutSheetState();
}

class _AboutSheetState extends State<_AboutSheet> {
  String? avatarUrl;
  String? bio;
  String? name;
  String? username;
  bool _showEmail = false; // Add this

  @override
  void initState() {
    super.initState();
    _fetchGithubProfile();
  }

  Future<void> _fetchGithubProfile() async {
    // Set the provided image and bio directly
    setState(() {
      avatarUrl = 'https://avatars.githubusercontent.com/u/132830850?v=4';
      bio = '🌿 Web & App Developer | Crafting responsive apps and interactive web experiences using HTML, CSS, JavaScript, Firebase, Flutter & Python. Exploring UI/UX, anim';
      name = 'Sanjay';
      username = 'sanjay434343';
    });
  }

  static const String _githubUrl = 'https://github.com/sanjay434343';
  static const String _hiddenEmail = 'c2FuamF5LmRldkBnbWFpbC5jb20='; // base64 for sanjay.dev@gmail.com

  String get _decodedEmail => String.fromCharCodes(base64Decode(_hiddenEmail));

  Future<void> _launchUrlInBrowser(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      // Try external application first, fallback to in-app webview for web URLs
      if (await canLaunchUrl(uri)) {
        bool launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && (uri.scheme == 'http' || uri.scheme == 'https')) {
          // Fallback to in-app webview for web links
          await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
          );
        } else if (!launched) {
          // If not a web link, fallback to platform default
          await launchUrl(
            uri,
            mode: LaunchMode.platformDefault,
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open link')),
      );
    }
  }

  Future<void> _reportBug(BuildContext context) async {
    setState(() {
      _showEmail = true; // Show email when button is clicked
    });
    final email = _decodedEmail;
    final subject = Uri.encodeComponent('Bug Report: ReplyWise');
    final body = Uri.encodeComponent('Describe your issue here...');
    final mailto = 'mailto:$email?subject=$subject&body=$body';
    final uri = Uri.parse(mailto);
    try {
      if (await canLaunchUrl(uri)) {
        // Use platformDefault for mailto links
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open email app')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open email app')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final colorScheme = widget.colorScheme;
    final double sheetHeight = MediaQuery.of(context).size.height * 0.55;

    return Container(
      height: sheetHeight,
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 48,
              height: 5,
              margin: EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                color: colorScheme.outline.withOpacity(0.18),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: colorScheme.primary, size: 28),
              SizedBox(width: 12),
              Text(
                'About ReplyWise',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 18),
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor: colorScheme.primary.withOpacity(0.08),
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? Icon(Icons.person, color: colorScheme.primary, size: 32)
                      : null,
                ),
                SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name ?? 'Sanjay',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        username != null ? '@$username' : '@sanjay434343',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (bio != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Text(
                            bio!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                  ),
                ),
                // Removed the GitHub open button here
              ],
            ),
          ),
          SizedBox(height: 22),
          Text(
            'ReplyWise fetches your emails from Google and uses AI to generate smart replies for you. Easily manage your email preferences and signatures. Built with Flutter for a modern, responsive experience.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface,
            ),
          ),
          SizedBox(height: 28),
          Center(
            child: Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _reportBug(context),
                  icon: Icon(Icons.bug_report_rounded, color: colorScheme.onPrimary),
                  label: Text('Report a bug', style: TextStyle(color: colorScheme.onPrimary)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                    elevation: 0,
                    textStyle: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                SizedBox(height: 8),
                if (_showEmail) ...[
                  // Remove _decodedEmail, only show sanjay13649@gmail.com
                  SelectableText(
                    'sanjay13649@gmail.com',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          Spacer(),
          Center(
            child: Text(
              'Version 1.0.0',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
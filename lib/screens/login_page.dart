import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';
import '../services/auth_service.dart';
import '../main.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;
  const LoginPage({super.key, this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Remove auto-login navigation, just check for auto-login and call onLoginSuccess if needed
    _checkPersistedLogin();
  }

  Future<void> _checkPersistedLogin() async {
    final autoLogin = await _authService.tryAutoLogin();
    if (autoLogin && mounted) {
      widget.onLoginSuccess?.call();
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Starting Google Sign-In process...');
      final user = await _authService.signInWithGoogle();
      
      if (user != null && mounted) {
        print('Login successful for user: ${user.email}');
        print('User UID: ${user.uid}');
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Welcome, ${user.displayName ?? user.email}!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Instead of context.go('/home'):
        widget.onLoginSuccess?.call();
      } else {
        print('Login was cancelled by user');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Sign in was cancelled'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Login error: $e');
      if (mounted) {
        String errorMessage = 'Sign in failed';
        
        // Parse specific error messages
        if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection.';
        } else if (e.toString().contains('account-exists-with-different-credential')) {
          errorMessage = 'Account exists with different sign-in method.';
        } else if (e.toString().contains('operation-not-allowed')) {
          errorMessage = 'Google sign-in is not enabled.';
        } else if (e.toString().contains('user-disabled')) {
          errorMessage = 'This account has been disabled.';
        } else if (e.toString().contains('insufficientPermissions') ||
                   e.toString().contains('insufficient authentication scopes')) {
          errorMessage = 'Google did not grant Gmail access. Please sign out and sign in again, and allow all requested permissions.';
        } else if (e.toString().contains('hasn\'t verified this app')) {
          errorMessage = 'Google has not verified this app. Click "Advanced" and "Go to ReplyWise (unsafe)" to continue for development.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _signInWithGoogle,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 0, vertical: 24.h),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top spacer
                SizedBox(height: 24.h),
                // Centered logo
                ReplyWiseLogo(size: 100.w, animate: false),
                // Google button and policy text at the bottom
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 56.h,
                      margin: EdgeInsets.symmetric(horizontal: 24.w),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28.r),
                        border: Border.all(
                          color: _isLoading 
                            ? Theme.of(context).colorScheme.outline.withOpacity(0.5)
                            : Theme.of(context).colorScheme.outline,
                          width: 1,
                        ),
                        color: _isLoading 
                          ? Theme.of(context).colorScheme.surface.withOpacity(0.5)
                          : Colors.transparent,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(28.r),
                          onTap: _isLoading ? null : _signInWithGoogle,
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 24.w),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_isLoading)
                                  SizedBox(
                                    width: 24.w,
                                    height: 24.h,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  )
                                else ...[
                                  HugeIcon(
                                    icon: HugeIcons.strokeRoundedGoogle,
                                    size: 24.sp,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                  SizedBox(width: 12.w),
                                ],
                                SizedBox(width: 8.w),
                                AutoSizeText(
                                  _isLoading ? 'Signing in...' : 'Continue with Google',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w500,
                                    color: _isLoading 
                                      ? Theme.of(context).colorScheme.onSurface.withOpacity(0.6)
                                      : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    AutoSizeText(
                      'By continuing, you agree to our Terms of Service and Privacy Policy',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

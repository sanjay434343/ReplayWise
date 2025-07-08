import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:go_router/go_router.dart';
import 'package:replywise/screens/email_detail_page.dart';
import 'package:replywise/screens/email_search_page.dart';
import 'package:replywise/screens/settings_page.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'dart:async';

import '../main.dart';
import '../services/email_service.dart';
import '../services/database_service.dart';
import '../models/email_model.dart';
import '../widgets/email_card.dart';
import '../widgets/email_tabs_widget.dart';
import 'home_main_tab_page.dart';
import 'home_personal_page.dart';
import 'home_important_page.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  int _selectedNavIndex = 0;
  List<EmailModel> _emails = [];
  bool _loading = true;
  String? _error;
  int _loadedCount = 0;
  int _totalCount = 0;
  double _loadingProgress = 0.0;
  int _visibleCount = 0;
  late TabController _tabController;
  late PageController _pageController;
  late PageController _mainPageController;

  static List<EmailModel>? _cachedEmails;
  static int _cachedLoadedCount = 0;
  static int _cachedTotalCount = 0;

  final List<EmailTabData> _tabs = [
    EmailTabData(
      title: 'All',
      icon: HugeIcons.strokeRoundedMail01,
      filter: (emails) => emails,
    ),
    EmailTabData(
      title: 'Unread',
      icon: HugeIcons.strokeRoundedMailOpen01,
      filter: (emails) => emails.where((e) => !e.isRead).toList(),
    ),
    EmailTabData(
      title: 'Read',
      icon: HugeIcons.strokeRoundedMailOpen02,
      filter: (emails) => emails.where((e) => e.isRead).toList(),
    ),
  ];

  late AnimationController _pageAnimationController;
  late Animation<double> _pageFadeAnimation;
  late Animation<Offset> _pageSlideAnimation;

  StreamController<List<EmailModel>>? _emailStreamController;
  StreamSubscription? _emailStreamSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _pageController = PageController(initialPage: 0);
    _mainPageController = PageController(initialPage: _selectedNavIndex);
    _pageAnimationController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _pageFadeAnimation = CurvedAnimation(
      parent: _pageAnimationController,
      curve: Curves.easeInOut,
    );
    _pageSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _pageAnimationController,
      curve: Curves.easeOutCubic,
    ));
    _pageAnimationController.forward();
    if (_cachedEmails == null) {
      _startLiveEmailStream();
    } else {
      setState(() {
        _emails = _cachedEmails!;
        _loadedCount = _cachedLoadedCount;
        _totalCount = _cachedTotalCount;
        _loading = false;
        _visibleCount = _emails.length;
      });
    }
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pageController.dispose();
    _mainPageController.dispose();
    _pageAnimationController.dispose();
    _emailStreamSubscription?.cancel();
    _emailStreamController?.close();
    super.dispose();
  }

  void _onTabChanged() {
    // No-op for now, but could be used for analytics or lazy loading
  }

  void _startLiveEmailStream() {
    _emailStreamController?.close();
    // Use broadcast stream controller to allow multiple listeners
    _emailStreamController = StreamController<List<EmailModel>>.broadcast();
    _emails = [];
    _loading = true;
    _error = null;
    _loadedCount = 0;
    _totalCount = 0;
    _loadingProgress = 0.0;
    _visibleCount = 0;

    _emailStreamSubscription?.cancel();
    _emailStreamSubscription = EmailService().fetchEmailsAsStream(
      onProgress: (loaded, total) {
        setState(() {
          _loadedCount = loaded;
          _totalCount = total;
          _loadingProgress = total > 0 ? loaded / total : 0.0;
        });
      },
    ).listen((batch) {
      setState(() {
        _emails.addAll(batch);
        _visibleCount = _emails.length;
        _loading = false;
      });
      _emailStreamController?.add(List<EmailModel>.from(_emails));
    }, onError: (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }, onDone: () {
      setState(() {
        _loading = false;
      });
    });
  }

  Future<void> _refreshEmails() async {
    _startLiveEmailStream();
  }

  void _navigateToEmailDetail(EmailModel email, List<EmailModel> emailList, int index) async {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EmailDetailPage(
          email: email,
          emailList: emailList,
          currentIndex: index,
        ),
      ),
    );
  }

  Future<void> _animateToPage(int index) async {
    setState(() {
      _selectedNavIndex = index;
      // Dispose and recreate TabController with correct length
      _tabController.dispose();
      _tabController = TabController(
        length: index == 0 ? _tabs.length : 3,
        vsync: this,
      );
    });
    await _pageAnimationController.reverse();
    _mainPageController.jumpToPage(index);
    await _pageAnimationController.forward();
  }

  void _onSettingsPressed() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) => Scaffold(
        backgroundColor: Theme.of(context).colorScheme.background,
        appBar: _selectedNavIndex == 0
            ? AppBar(
                backgroundColor: Theme.of(context).colorScheme.surface,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                elevation: 0,
                titleSpacing: 16.w,
                title: Row(
                  children: [
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AutoSizeText(
                            widget.title,
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          if (_selectedNavIndex == 0 && _emails.isNotEmpty && !_loading)
                            AutoSizeText(
                              '${_emails.length} emails',
                              maxLines: 1,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                actions: [
                  IconButton(
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      size: 24.0,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => EmailSearchPage(emails: _emails),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: HugeIcon(
                      icon: HugeIcons.strokeRoundedRefresh,
                      size: 24.0,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: _loading ? null : _refreshEmails,
                  ),
                  // Remove logo from actions
                ],
                bottom: EmailTabsWidget(
                  tabController: _tabController,
                  selectedNavIndex: _selectedNavIndex,
                  tabs: _tabs,
                  emails: _emails,
                ),
              )
            : null,
        body: Stack(
          children: [
            FadeTransition(
              opacity: _pageFadeAnimation,
              child: SlideTransition(
                position: _pageSlideAnimation,
                child: PageView(
                  controller: _mainPageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _selectedNavIndex = index;
                    });
                  },
                  children: [
                    // Use StreamBuilder for live emails
                    StreamBuilder<List<EmailModel>>(
                      stream: _emailStreamController?.stream,
                      initialData: _emails,
                      builder: (context, snapshot) {
                        return HomeMainTabPage(
                          loading: _loading,
                          loadedCount: _loadedCount,
                          error: _error,
                          tabController: _tabController,
                          tabs: _tabs,
                          emails: snapshot.data ?? [],
                          refreshEmails: _refreshEmails,
                          buildEmailList: _buildEmailList,
                          buildAttachmentTab: () {
                            // TODO: Replace with actual implementation if needed
                            return Center(child: Text('Attachment Tab'));
                          },
                        );
                      },
                    ),
                    HomePersonalPage(emails: _emails),
                    HomeImportantPage(emails: _emails),
                  ],
                ),
              ),
            ),
            _FloatingNavBar(
              selectedIndex: _selectedNavIndex,
              onTabSelected: (index) async {
                if (_selectedNavIndex == index) return;
                await _animateToPage(index);
              },
              onSettingsPressed: _onSettingsPressed,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailList(List<EmailModel> emails) {
    if (emails.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedMailOpen01,
              size: 64.sp,
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
            ),
            SizedBox(height: 16.h),
            Text(
              'No emails in this category',
              style: TextStyle(
                fontSize: 16.sp,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshEmails,
      child: ListView.separated(
        padding: EdgeInsets.only(left: 12.w, right: 12.w, top: 16.h, bottom: 100.h),
        itemCount: emails.length,
        separatorBuilder: (_, __) => SizedBox(height: 10.h),
        itemBuilder: (context, index) {
          final email = emails[index];
          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: 1),
            duration: Duration(milliseconds: 350 + index * 30),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Transform.translate(
                  offset: Offset(0, (1 - value) * 30),
                  child: child,
                ),
              );
            },
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18.r),
                onTap: () => _navigateToEmailDetail(email, emails, index),
                child: Container(
                  decoration: BoxDecoration(
                    color: email.isRead
                        ? Theme.of(context).colorScheme.surface
                        : Theme.of(context).colorScheme.surface.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(18.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: EmailCard(
                    email: email,
                    showNoSubject: true,
                  ),
                ),
              ),
              ),

            );
          },
      ),
    );
  }

  IconData _getAttachmentIcon(String mimeType) {
    if (mimeType.startsWith('image/')) return Icons.image;
    if (mimeType.startsWith('video/')) return Icons.video_file;
    if (mimeType.startsWith('audio/')) return Icons.audio_file;
    if (mimeType.contains('pdf')) return Icons.picture_as_pdf;
    if (mimeType.contains('word') || mimeType.contains('document')) return Icons.description;
    if (mimeType.contains('excel') || mimeType.contains('spreadsheet')) return Icons.table_chart;
    if (mimeType.contains('powerpoint') || mimeType.contains('presentation')) return Icons.slideshow;
    if (mimeType.contains('zip') || mimeType.contains('archive')) return Icons.archive;
    return Icons.attach_file;
  }
}

class EmailTabData {
  final String title;
  final IconData icon;
  final List<EmailModel> Function(List<EmailModel>) filter;

  EmailTabData({
    required this.title,
    required this.icon,
    required this.filter,
  });
}

class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback? onSettingsPressed;

  const _FloatingNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onTabSelected,
    this.onSettingsPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 22,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              margin: EdgeInsets.only(left: 10.w),
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
                child: _BgIconButton(
                  icon: HugeIcons.strokeRoundedSetting06,
                  tooltip: 'Settings',
                  onPressed: onSettingsPressed ?? () {},
                ),
              ),
            ),
            Container(
              margin: EdgeInsets.only(left: 10.w),
              width: 170.w,
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _NavBarIcon(
                    icon: HugeIcons.strokeRoundedHome02,
                    tooltip: 'Home',
                    selected: selectedIndex == 0,
                    onTap: () => onTabSelected(0),
                  ),
                  SizedBox(width: 8.w),
                  _NavBarIcon(
                    icon: HugeIcons.strokeRoundedUser02,
                    tooltip: 'Personal',
                    selected: selectedIndex == 1,
                    onTap: () => onTabSelected(1),
                  ),
                  SizedBox(width: 8.w),
                  _NavBarIcon(
                    icon: HugeIcons.strokeRoundedStar,
                    tooltip: 'Important',
                    selected: selectedIndex == 2,
                    onTap: () => onTabSelected(2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarIcon extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool selected;
  final VoidCallback onTap;

  const _NavBarIcon({
    required this.icon,
    required this.tooltip,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          icon,
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
          size: 28,
        ),
      ),
    );
  }
}

class _BgIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _BgIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30.r),
        onTap: onPressed,
        child: Container(
          width: 48.w,
          height: 48.h,
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(30.r),
          ),
          child: Center(
            child: HugeIcon(
              icon: icon,
              size: 24.0,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}

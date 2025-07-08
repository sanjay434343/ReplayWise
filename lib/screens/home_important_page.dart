import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';
import '../models/email_model.dart';
import '../services/database_service.dart';
import '../widgets/email_card.dart';
import '../widgets/custom_email_tabs_widget.dart';
import 'email_detail_page.dart';
import 'email_search_page.dart';
import '../../main.dart' show ReplyWiseLogo; // <-- Fix import path

class HomeImportantPage extends StatefulWidget {
  final List<EmailModel> emails;
  const HomeImportantPage({Key? key, required this.emails}) : super(key: key);

  @override
  State<HomeImportantPage> createState() => _HomeImportantPageState();
}

class _HomeImportantPageState extends State<HomeImportantPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabTitles = ['Latest', 'All', 'Read', 'Unread'];

  // Use valid icons (replace with correct HugeIcons if available)
  final List<EmailTabData> _tabs = [
    EmailTabData(title: 'Latest', icon: Icons.access_time), // fallback
    EmailTabData(title: 'All', icon: Icons.mail_outline), // fallback
    EmailTabData(title: 'Read', icon: Icons.mark_email_read_outlined), // fallback
    EmailTabData(title: 'Unread', icon: Icons.mark_email_unread_outlined), // fallback
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
    _tabController.index = 1; // Focus on "All" tab by default
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<EmailModel> _getFilteredEmails(List<EmailModel> emails, int tabIndex) {
    final now = DateTime.now();
    switch (tabIndex) {
      case 0: // Latest (today)
        return emails.where((e) {
          final date = DateTime.tryParse(e.time);
          return date != null &&
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        }).toList();
      case 1: // All
        return emails;
      case 2: // Read
        return emails.where((e) => e.isRead).toList();
      case 3: // Unread
        return emails.where((e) => !e.isRead).toList();
      default:
        return emails;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
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
                  Text(
                    'Important',
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Builder(
                    builder: (context) {
                      final importantEmails = DatabaseService().importantEmailList;
                      // Sort by parsed date from 'time' field, fallback to string compare
                      importantEmails.sort((a, b) {
                        DateTime? dateA;
                        DateTime? dateB;
                        try {
                          dateA = DateTime.tryParse(a.time);
                        } catch (_) {}
                        try {
                          dateB = DateTime.tryParse(b.time);
                        } catch (_) {}
                        if (dateA != null && dateB != null) {
                          return dateB.compareTo(dateA);
                        } else if (dateA != null) {
                          return -1;
                        } else if (dateB != null) {
                          return 1;
                        } else {
                          return (b.time ?? '').compareTo(a.time ?? '');
                        }
                      });

                      return Text(
                        '${importantEmails.length} emails',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      );
                    },
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
              final importantEmails = DatabaseService().importantEmailList;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => EmailSearchPage(emails: importantEmails),
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
            onPressed: null,
          ),
          // Remove logo from actions
        ],
        bottom: CustomEmailTabsWidget(
          tabController: _tabController,
          selectedNavIndex: 0,
          tabs: _tabs,
          emails: DatabaseService().importantEmailList,
        ),
      ),
      body: Builder(
        builder: (context) {
          final importantEmails = DatabaseService().importantEmailList;
          // Sort by parsed date from 'time' field, fallback to string compare
          importantEmails.sort((a, b) {
            DateTime? dateA;
            DateTime? dateB;
            try {
              dateA = DateTime.tryParse(a.time);
            } catch (_) {}
            try {
              dateB = DateTime.tryParse(b.time);
            } catch (_) {}
            if (dateA != null && dateB != null) {
              return dateB.compareTo(dateA);
            } else if (dateA != null) {
              return -1;
            } else if (dateB != null) {
              return 1;
            } else {
              return (b.time ?? '').compareTo(a.time ?? '');
            }
          });

          final filteredEmails = _getFilteredEmails(importantEmails, _tabController.index);

          return filteredEmails.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(seconds: 1),
                        curve: Curves.elasticOut,
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, -30 * (1 - value)),
                            child: Transform.scale(
                              scale: 0.8 + 0.2 * value,
                              child: HugeIcon(
                                icon: HugeIcons.strokeRoundedStar,
                                size: 64,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 24),
                      Text(
                        _tabController.index == 0
                            ? 'No important email found today.'
                            : 'No important email found.',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: EdgeInsets.only(left: 16.w, right: 16.w, bottom: 100.h, top: 8.h),
                  children: [
                    ...filteredEmails.map((email) => Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18.r),
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (ctx) => EmailDetailPage(
                                      email: email,
                                      emailList: importantEmails,
                                      currentIndex: importantEmails.indexOf(email),
                                    ),
                                  ),
                                );
                              },
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
                        )),
                  ],
                );
        },
      ),
    );
  }
}

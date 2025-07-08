import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:replywise/screens/home_page.dart';
import '../models/email_model.dart';
import '../services/database_service.dart';

class EmailTabData {
  final String title;
  final dynamic icon; // Use dynamic to support both HugeIcons and Icons

  EmailTabData({required this.title, required this.icon});
}

class CustomEmailTabsWidget extends StatelessWidget implements PreferredSizeWidget {
  final TabController tabController;
  final int selectedNavIndex;
  final List<EmailTabData> tabs;
  final List<EmailModel> emails;

  const CustomEmailTabsWidget({
    Key? key,
    required this.tabController,
    required this.selectedNavIndex,
    required this.tabs,
    required this.emails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Animate tab bar in/out with slide and fade
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final offsetAnim = Tween<Offset>(
          begin: const Offset(0, -0.2),
          end: Offset.zero,
        ).animate(animation);
        return SlideTransition(
          position: offsetAnim,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      child: selectedNavIndex == 0
          ? SizedBox(
              key: const ValueKey('tabbar'),
              height: kToolbarHeight,
              child: TabBar(
                controller: tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                indicatorColor: Theme.of(context).colorScheme.primary,
                labelColor: Theme.of(context).colorScheme.primary,
                unselectedLabelColor: Theme.of(context).colorScheme.onSurfaceVariant,
                tabs: tabs.asMap().entries.map((entry) {
                  final index = entry.key;
                  final tab = entry.value;
                  final count = _getFilteredCount(index);
                  return _buildTab(context, tab, count);
                }).toList(),
              ),
            )
          : const SizedBox(
              key: ValueKey('empty'),
              height: 0,
            ),
    );
  }

  int _getFilteredCount(int tabIndex) {
    final now = DateTime.now();
    switch (tabIndex) {
      case 0: // Latest (today)
        return emails.where((e) {
          final date = DateTime.tryParse(e.time);
          return date != null &&
              date.year == now.year &&
              date.month == now.month &&
              date.day == now.day;
        }).length;
      case 1: // All
        return emails.length;
      case 2: // Read
        return emails.where((e) => e.isRead).length;
      case 3: // Unread
        return emails.where((e) => !e.isRead).length;
      default:
        return emails.length;
    }
  }

  Widget _buildTab(BuildContext context, EmailTabData tab, int count) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: tab.icon,
            size: 20.sp,
            color: tabController.index == tabs.indexOf(tab)
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: 8.w),
          Text(tab.title),
          SizedBox(width: 4.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);
}

// You may want to move EmailTabData to a shared location if needed.

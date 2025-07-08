import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/email_model.dart';

class HomeMainTabPage extends StatelessWidget {
  final bool loading;
  final int loadedCount;
  final String? error;
  final TabController tabController;
  final List tabs;
  final List<EmailModel> emails;
  final Future<void> Function() refreshEmails;
  final Widget Function(List<EmailModel>) buildEmailList;
  final Widget Function() buildAttachmentTab;

  const HomeMainTabPage({
    Key? key,
    required this.loading,
    required this.loadedCount,
    required this.error,
    required this.tabController,
    required this.tabs,
    required this.emails,
    required this.refreshEmails,
    required this.buildEmailList,
    required this.buildAttachmentTab,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool showSkeleton = loading || loadedCount < 100;
    return Stack(
      children: [
        showSkeleton
            ? TabBarView(
                controller: tabController,
                children: List.generate(
                  tabs.length,
                  (index) => Skeletonizer(
                    enabled: true,
                    child: ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 16.h),
                      itemCount: 6,
                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                      itemBuilder: (context, index) {
                        return Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(18.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.04),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 48.w,
                                  height: 48.w,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade300,
                                    borderRadius: BorderRadius.circular(24.r),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Container(
                                              height: 16.h,
                                              decoration: BoxDecoration(
                                                color: Colors.grey.shade300,
                                                borderRadius: BorderRadius.circular(4.r),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 8.w),
                                          Container(
                                            width: 50.w,
                                            height: 12.h,
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade300,
                                              borderRadius: BorderRadius.circular(4.r),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 8.h),
                                      Container(
                                        width: 120.w,
                                        height: 14.h,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                      ),
                                      SizedBox(height: 6.h),
                                      Container(
                                        width: double.infinity,
                                        height: 12.h,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Container(
                                        width: 200.w,
                                        height: 12.h,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius: BorderRadius.circular(4.r),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              )
            : error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64.sp,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'Failed to load emails',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32.w),
                          child: Text(
                            error!,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14.sp),
                          ),
                        ),
                        SizedBox(height: 16.h),
                        ElevatedButton(
                          onPressed: refreshEmails,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  )
                : TabBarView(
                    controller: tabController,
                    children: List.generate(
                      tabs.length,
                      (index) {
                        // Always show filtered email list for each tab
                        return buildEmailList(tabs[index].filter(emails));
                      },
                    ),
                  ),
      ]
    );
  }
}

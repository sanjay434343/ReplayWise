import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/email_model.dart';
import '../widgets/email_card.dart';
import 'email_detail_page.dart';
import '../services/database_service.dart';

enum EmailFilter { all, unread, read, important, personal, latest }

class EmailSearchPage extends StatefulWidget {
  final List<EmailModel> emails;
  const EmailSearchPage({Key? key, required this.emails}) : super(key: key);

  @override
  State<EmailSearchPage> createState() => _EmailSearchPageState();
}

class _EmailSearchPageState extends State<EmailSearchPage> {
  String _query = '';
  EmailFilter _selectedFilter = EmailFilter.all;
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  List<EmailModel> get _filteredEmails {
    List<EmailModel> emails = widget.emails;

    final db = DatabaseService();

    // Apply filter
    switch (_selectedFilter) {
      case EmailFilter.unread:
        emails = emails.where((e) => !e.isRead).toList();
        break;
      case EmailFilter.read:
        emails = emails.where((e) => e.isRead).toList();
        break;
      case EmailFilter.important:
        final importantIds = db.importantEmailIds;
        emails = emails.where((e) => importantIds.contains(e.id)).toList();
        break;
      case EmailFilter.personal:
        final personalEmails = db.personalEmails;
        emails = emails.where((e) => personalEmails.contains(e.senderEmail)).toList();
        break;
      case EmailFilter.latest:
        emails = List.from(emails)
          ..sort((a, b) {
            // Parse DateTime from 'time' string, fallback to original order if parsing fails
            DateTime? dateA = DateTime.tryParse(a.time);
            DateTime? dateB = DateTime.tryParse(b.time);
            if (dateA != null && dateB != null) {
              return dateB.compareTo(dateA);
            } else if (dateA != null) {
              return -1;
            } else if (dateB != null) {
              return 1;
            } else {
              return 0;
            }
          });
        emails = emails.take(20).toList();
        break;
      case EmailFilter.all:
      default:
        break;
    }

    // Apply search query
    if (_query.isEmpty) return emails;
    final q = _query.toLowerCase();
    return emails.where((e) =>
      (e.subject?.toLowerCase().contains(q) ?? false) ||
      (e.sender?.toLowerCase().contains(q) ?? false) ||
      (e.body?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  String _getFilterLabel(EmailFilter filter) {
    switch (filter) {
      case EmailFilter.all:
        return 'All';
      case EmailFilter.unread:
        return 'Unread';
      case EmailFilter.read:
        return 'Read';
      case EmailFilter.important:
        return 'Important';
      case EmailFilter.personal:
        return 'Personal';
      case EmailFilter.latest:
        return 'Latest';
    }
  }

  IconData _getFilterIcon(EmailFilter filter) {
    switch (filter) {
      case EmailFilter.all:
        return Icons.all_inbox_outlined;
      case EmailFilter.unread:
        return Icons.mark_email_unread_outlined;
      case EmailFilter.read:
        return Icons.mark_email_read_outlined;
      case EmailFilter.important:
        return Icons.star_outline;
      case EmailFilter.personal:
        return Icons.person_outline;
      case EmailFilter.latest:
        return Icons.schedule_outlined;
    }
  }

  void _clearSearch() {
    setState(() {
      _query = '';
      _searchController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 3,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: colorScheme.surfaceTint,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: SearchBar(
          controller: _searchController,
          focusNode: _searchFocusNode,
          hintText: 'Search emails...',
          backgroundColor: WidgetStateProperty.all(
            colorScheme.surfaceContainerHighest,
          ),
          overlayColor: WidgetStateProperty.all(
            colorScheme.onSurface.withOpacity(0.08),
          ),
          shadowColor: WidgetStateProperty.all(Colors.transparent),
          side: WidgetStateProperty.all(BorderSide.none),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28.r),
            ),
          ),
          padding: WidgetStateProperty.all(
            EdgeInsets.symmetric(horizontal: 16.w),
          ),
          textStyle: WidgetStateProperty.all(
            TextStyle(
              fontSize: 16.sp,
              color: colorScheme.onSurface,
            ),
          ),
          hintStyle: WidgetStateProperty.all(
            TextStyle(
              fontSize: 16.sp,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          leading: Icon(
            Icons.search,
            color: colorScheme.onSurfaceVariant,
            size: 24.sp,
          ),
          trailing: _query.isNotEmpty
              ? [
                  IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onPressed: _clearSearch,
                  ),
                ]
              : null,
          onChanged: (value) => setState(() => _query = value),
        ),
      ),
      body: Column(
        children: [
          // Filter Chips Section
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12.h),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                children: EmailFilter.values.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: EdgeInsets.only(right: 8.w),
                    child: FilterChip(
                      selected: isSelected,
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _getFilterIcon(filter),
                            size: 18.sp,
                            color: isSelected
                                ? colorScheme.onSecondaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            _getFilterLabel(filter),
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      onSelected: (selected) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                      backgroundColor: colorScheme.surface,
                      selectedColor: colorScheme.secondaryContainer,
                      labelStyle: TextStyle(
                        color: isSelected
                            ? colorScheme.onSecondaryContainer
                            : colorScheme.onSurfaceVariant,
                      ),
                      side: BorderSide(
                        color: isSelected
                            ? colorScheme.secondary
                            : colorScheme.outline,
                        width: 1,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 8.h,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          // Results Section
          Expanded(
            child: _filteredEmails.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_outlined,
                          size: 64.sp,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'No emails found',
                          style: TextStyle(
                            fontSize: 18.sp,
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          _query.isNotEmpty
                              ? 'Try adjusting your search or filters'
                              : 'No emails match the selected filter',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.all(16.w),
                    itemCount: _filteredEmails.length,
                    itemBuilder: (context, index) {
                      final email = _filteredEmails[index];
                      return Padding(
                        padding: EdgeInsets.only(bottom: 12.h),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16.r),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (ctx) => EmailDetailPage(
                                    email: email,
                                    emailList: _filteredEmails,
                                    currentIndex: index,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                color: email.isRead
                                    ? colorScheme.surfaceContainerLow
                                    : colorScheme.surfaceContainerHigh,
                                borderRadius: BorderRadius.circular(16.r),
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
          ),
        ],
      ),
    );
  }
}
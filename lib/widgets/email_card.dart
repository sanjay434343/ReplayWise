import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:intl/intl.dart';
import '../models/email_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animations/animations.dart';
import '../screens/email_detail_page.dart';

class EmailCard extends StatefulWidget {
  final EmailModel email;
  final VoidCallback? onTap;
  final bool showNoSubject;

  const EmailCard({
    Key? key,
    required this.email,
    this.onTap,
    this.showNoSubject = false,
  }) : super(key: key);

  @override
  State<EmailCard> createState() => _EmailCardState();
}

class _EmailCardState extends State<EmailCard> {
  bool _isHovered = false;

  String _formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return "";

    try {
      final dt = _parseEmailDate(timeStr);
      if (dt != null) {
        final now = DateTime.now();
        final difference = now.difference(dt);

        if (difference.inDays == 0) {
          // Use 12-hour format with AM/PM
          return DateFormat('h:mm a').format(dt);
        } else if (difference.inDays == 1) {
          return 'Yesterday';
        } else if (difference.inDays < 7) {
          return DateFormat('E').format(dt); // Mon, Tue, etc.
        } else if (difference.inDays < 365) {
          return DateFormat('MMM d').format(dt); // Jan 15
        } else {
          return DateFormat('M/d/yy').format(dt); // 1/15/24
        }
      }

      // Fallback: extract readable parts from the original string
      return _extractDateParts(timeStr);
    } catch (e) {
      // Silent fallback without logging
      return _extractDateParts(timeStr);
    }
  }

  DateTime? _parseEmailDate(String dateStr) {
    try {
      // Clean up the date string
      String cleaned = dateStr.trim();
      
      // Remove timezone abbreviations in parentheses: (UTC), (CDT), etc.
      cleaned = cleaned.replaceAll(RegExp(r'\s*\([^)]*\)\s*'), ' ').trim();
      
      // Remove "GMT" if it appears at the end
      cleaned = cleaned.replaceAll(RegExp(r'\s+GMT\s*$'), ' +0000').trim();
      
      // Normalize timezone formats
      // Convert -0000 to +0000
      cleaned = cleaned.replaceAll('-0000', '+0000');
      
      // Handle missing day format: "3 Jul" -> "03 Jul"
      cleaned = cleaned.replaceAllMapped(RegExp(r'\b(\d)\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\b'), 
                                  (match) => '0${match.group(1)} ${match.group(2)}');
      
      // Handle single digit day with comma: "Thu, 3 Jul" -> "Thu, 03 Jul"
      cleaned = cleaned.replaceAllMapped(RegExp(r'(\w{3}),\s+(\d)\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)'), 
                                  (match) => '${match.group(1)}, 0${match.group(2)} ${match.group(3)}');
      
      // Try parsing with different formats
      final formats = [
        // RFC 2822 standard formats
        'EEE, dd MMM yyyy HH:mm:ss Z',     // Thu, 03 Jul 2025 14:40:33 -0600
        'EEE, d MMM yyyy HH:mm:ss Z',      // Thu, 3 Jul 2025 14:40:33 -0600
        'dd MMM yyyy HH:mm:ss Z',          // 03 Jul 2025 16:21:29 -0000
        'd MMM yyyy HH:mm:ss Z',           // 3 Jul 2025 16:21:29 -0000
        'EEE, dd MMM yyyy HH:mm:ss',       // Thu, 03 Jul 2025 14:40:33
        'EEE, d MMM yyyy HH:mm:ss',        // Thu, 3 Jul 2025 14:40:33
        'yyyy-MM-dd HH:mm:ss Z',           // 2025-07-03 14:40:33 -0600
        'yyyy-MM-ddTHH:mm:ssZ',            // 2025-07-03T14:40:33Z
        'yyyy-MM-ddTHH:mm:ss.SSSZ',        // 2025-07-03T14:40:33.123Z
      ];
      
      for (String format in formats) {
        try {
          return DateFormat(format).parse(cleaned);
        } catch (_) {
          continue;
        }
      }
      
      // Try manual parsing for complex cases
      return _manualDateParse(cleaned);
    } catch (e) {
      return null;
    }
  }

  DateTime? _manualDateParse(String dateStr) {
    try {
      // Extract components using regex
      final regex = RegExp(
        r'(?:(\w{3}),?\s+)?(\d{1,2})\s+(\w{3})\s+(\d{4})\s+(\d{1,2}):(\d{2}):(\d{2})\s*([+-]\d{4}|\w{3,4})?'
      );
      
      final match = regex.firstMatch(dateStr);
      if (match == null) return null;
      
      final day = int.parse(match.group(2)!);
      final monthStr = match.group(3)!;
      final year = int.parse(match.group(4)!);
      final hour = int.parse(match.group(5)!);
      final minute = int.parse(match.group(6)!);
      final second = int.parse(match.group(7)!);
      final timezoneStr = match.group(8);
      
      // Convert month name to number
      final monthMap = {
        'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
        'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
      };
      
      final month = monthMap[monthStr];
      if (month == null) return null;
      
      // Create DateTime in UTC then adjust for timezone
      var dt = DateTime.utc(year, month, day, hour, minute, second);
      
      // Handle timezone offset
      if (timezoneStr != null && timezoneStr.startsWith(RegExp(r'[+-]'))) {
        final sign = timezoneStr[0] == '+' ? 1 : -1;
        final offsetHours = int.parse(timezoneStr.substring(1, 3));
        final offsetMinutes = int.parse(timezoneStr.substring(3, 5));
        final offsetDuration = Duration(hours: offsetHours, minutes: offsetMinutes);
        dt = dt.subtract(Duration(milliseconds: sign * offsetDuration.inMilliseconds));
      }
      
      return dt;
    } catch (e) {
      return null;
    }
  }

  String _extractDateParts(String timeStr) {
    try {
      // Try to extract day and month for display
      final dayMonthRegex = RegExp(r'(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)');
      final match = dayMonthRegex.firstMatch(timeStr);
      
      if (match != null) {
        final day = match.group(1)!;
        final month = match.group(2)!;
        return '$month $day';
      }
      
      // Extract day of week if available
      final dayRegex = RegExp(r'^(\w{3}),?');
      final dayMatch = dayRegex.firstMatch(timeStr.trim());
      if (dayMatch != null) {
        return dayMatch.group(1)!;
      }
      
      // Last resort: show first few characters
      return timeStr.length > 8 ? timeStr.substring(0, 8) : timeStr;
    } catch (e) {
      return timeStr.length > 8 ? timeStr.substring(0, 8) : timeStr;
    }
  }

  Color _getAvatarColor(BuildContext context) {
    final colors = [
      Theme.of(context).colorScheme.primaryContainer,
      Theme.of(context).colorScheme.secondaryContainer,
      Theme.of(context).colorScheme.tertiaryContainer,
    ];
    final hash = (widget.email.sender?.hashCode ?? 0) % colors.length;
    return colors[hash];
  }

  Color _getAvatarTextColor(BuildContext context) {
    final colors = [
      Theme.of(context).colorScheme.onPrimaryContainer,
      Theme.of(context).colorScheme.onSecondaryContainer,
      Theme.of(context).colorScheme.onTertiaryContainer,
    ];
    final hash = (widget.email.sender?.hashCode ?? 0) % colors.length;
    return colors[hash];
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _formatTime(widget.email.time ?? "");
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return OpenContainer(
      transitionType: ContainerTransitionType.fadeThrough,
      transitionDuration: const Duration(milliseconds: 400),
      openColor: colorScheme.surface,
      closedColor: Colors.transparent,
      closedElevation: 0,
      openElevation: 0,
      closedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      openShape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      tappable: true,
      closedBuilder: (context, openContainer) {
        return MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: widget.email.isRead 
                  ? Colors.transparent 
                  : colorScheme.surfaceContainerHighest.withOpacity(0.3),
              borderRadius: BorderRadius.circular(999.r), // pill shape
              border: Border.all(
                color: _isHovered
                    ? colorScheme.outline.withOpacity(0.5)
                    : colorScheme.outline.withOpacity(0.15),
                width: 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(999.r), // pill shape
              child: InkWell(
                borderRadius: BorderRadius.circular(999.r), // pill shape
                onTap: openContainer,
                splashColor: colorScheme.primary.withOpacity(0.1),
                highlightColor: colorScheme.primary.withOpacity(0.05),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Enhanced Avatar with better colors
                      Container(
                        width: 44.w,
                        height: 44.w,
                        decoration: BoxDecoration(
                          color: _getAvatarColor(context),
                          borderRadius: BorderRadius.circular(22.r),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.shadow.withOpacity(0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            widget.email.sender?.substring(0, 1).toUpperCase() ?? "?",
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 18.sp,
                              color: _getAvatarTextColor(context),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      
                      // Main content with improved spacing
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Enhanced header row with better typography
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Sender name with Material 3 typography
                                      AutoSizeText(
                                        widget.email.sender ?? 'ReplyWise',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: widget.email.isRead ? FontWeight.w500 : FontWeight.w600,
                                          color: colorScheme.onSurface,
                                          height: 1.2,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4.h),
                                      
                                      // Subject with better styling
                                      if (widget.email.subject != null && widget.email.subject!.trim().isNotEmpty)
                                        AutoSizeText(
                                          widget.email.subject!,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: widget.email.isRead ? FontWeight.w400 : FontWeight.w500,
                                            color: widget.email.isRead 
                                                ? colorScheme.onSurfaceVariant 
                                                : colorScheme.onSurface,
                                            height: 1.3,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        )
                                      else if (widget.showNoSubject)
                                        Text(
                                          "No Subject",
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontStyle: FontStyle.italic,
                                            color: colorScheme.onSurfaceVariant,
                                            height: 1.3,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                
                                // Time and status indicators
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    // Time with better styling
                                    Text(
                                      dateStr,
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: colorScheme.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(height: 6.h),
                                    
                                    // Status indicators row
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // Unread indicator
                                        if (!widget.email.isRead)
                                          Container(
                                            width: 8.w,
                                            height: 8.w,
                                            decoration: BoxDecoration(
                                              color: colorScheme.primary,
                                              borderRadius: BorderRadius.circular(4.r),
                                            ),
                                          ),
                                        if (!widget.email.isRead) SizedBox(width: 6.w),
                                        
                                        // Star icon
                                        if (widget.email.isImportant || widget.email.isStarred)
                                          Icon(
                                            widget.email.isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                                            color: widget.email.isStarred 
                                                ? colorScheme.primary 
                                                : colorScheme.onSurfaceVariant,
                                            size: 20.sp,
                                          ),
                                        if ((widget.email.isImportant || widget.email.isStarred) && widget.email.hasAttachments) 
                                          SizedBox(width: 4.w),
                                        
                                        // Attachment icon
                                        if (widget.email.hasAttachments)
                                          Icon(
                                            Icons.attach_file_rounded,
                                            color: colorScheme.onSurfaceVariant,
                                            size: 18.sp,
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ).animate().fadeIn(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        ).slideY(
          begin: 0.1,
          end: 0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      },
      openBuilder: (context, _) {
        return EmailDetailPage(
          email: widget.email,
        );
      },
    );
  }
}
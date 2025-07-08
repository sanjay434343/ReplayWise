import 'package:flutter/foundation.dart';
import '../models/email_model.dart';
import 'email_service.dart';

class EmailStateManager extends ChangeNotifier {
  static final EmailStateManager _instance = EmailStateManager._internal();
  factory EmailStateManager() => _instance;
  EmailStateManager._internal();

  List<EmailModel> _emails = [];
  bool _isLoading = false;
  bool _hasInitiallyLoaded = false;
  String? _error;
  DateTime? _lastFetchTime;

  List<EmailModel> get emails => _emails;
  bool get isLoading => _isLoading;
  bool get hasInitiallyLoaded => _hasInitiallyLoaded;
  String? get error => _error;

  // Cache duration - 5 minutes
  static const Duration _cacheDuration = Duration(minutes: 5);

  bool get _shouldRefetch {
    if (_lastFetchTime == null) return true;
    return DateTime.now().difference(_lastFetchTime!) > _cacheDuration;
  }

  Future<List<EmailModel>> getEmails({bool forceRefresh = false}) async {
    // If we have cached data and don't need to refresh, return it
    if (!forceRefresh && _hasInitiallyLoaded && _emails.isNotEmpty && !_shouldRefetch) {
      return _emails;
    }

    // If already loading, wait for current operation to complete
    if (_isLoading) {
      // Wait for loading to complete and return the result
      while (_isLoading) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
      return _emails;
    }

    return await _fetchEmails();
  }

  Future<List<EmailModel>> _fetchEmails() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final emails = await EmailService().fetchAllEmails(
        onProgress: (loaded, total) {
          // You can add progress callback here if needed
        },
      );
      
      _emails = emails;
      _hasInitiallyLoaded = true;
      _lastFetchTime = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
      // Don't clear existing emails on error, keep the cached ones
      if (_emails.isEmpty) {
        _emails = [];
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _emails;
  }

  Future<void> refreshEmails() async {
    await _fetchEmails();
  }

  void clearCache() {
    _emails = [];
    _hasInitiallyLoaded = false;
    _lastFetchTime = null;
    _error = null;
    notifyListeners();
  }

  // Mark email as read
  void markAsRead(String emailId) {
    final index = _emails.indexWhere((email) => email.id == emailId);
    if (index != -1 && !_emails[index].isRead) {
      _emails[index] = _emails[index].copyWith(isRead: true);
      notifyListeners();
    }
  }
}

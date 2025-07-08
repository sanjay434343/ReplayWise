import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/email_model.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _db;

  // In-memory sets for demo; replaced with persistent storage
  final Set<String> _personalEmails = {};
  final Set<String> _importantEmailIds = {};
  List<EmailModel> _allEmails = [];

  // --- SQLite initialization ---
  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'replywise.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE emails (
            id TEXT PRIMARY KEY,
            sender TEXT,
            senderEmail TEXT,
            subject TEXT,
            snippet TEXT,
            time TEXT,
            body TEXT,
            htmlBody TEXT,
            isRead INTEGER,
            isImportant INTEGER,
            isStarred INTEGER,
            labels TEXT,
            attachments TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE personal_emails (email TEXT PRIMARY KEY)
        ''');
        await db.execute('''
          CREATE TABLE important_emails (emailId TEXT PRIMARY KEY)
        ''');
        await db.execute('''
          CREATE TABLE user_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
      onOpen: (db) async {
        // Ensure user_settings table exists even if DB was created before this table was added
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
    await _loadPersonalAndImportant();
    await _loadAllEmails();
  }

  Future<void> _loadPersonalAndImportant() async {
    if (_db == null) return;
    final personalRows = await _db!.query('personal_emails');
    _personalEmails.clear();
    _personalEmails.addAll(personalRows.map((e) => e['email'] as String));
    final importantRows = await _db!.query('important_emails');
    _importantEmailIds.clear();
    _importantEmailIds.addAll(importantRows.map((e) => e['emailId'] as String));
  }

  Future<void> _loadAllEmails() async {
    if (_db == null) return;
    final rows = await _db!.query('emails');
    _allEmails = rows.map((e) => EmailModel.fromJson(_fromDbMap(e))).toList();
  }

  Map<String, dynamic> _fromDbMap(Map<String, dynamic> map) {
    // Convert DB map to EmailModel JSON
    return {
      ...map,
      'isRead': map['isRead'] == 1,
      'isImportant': map['isImportant'] == 1,
      'isStarred': map['isStarred'] == 1,
      'labels': map['labels'] != null ? (map['labels'] as String).split(',') : [],
      'attachments': [], // For simplicity, not storing attachments in DB here
    };
  }

  // --- Email storage ---
  Future<void> saveEmails(List<EmailModel> emails) async {
    await init();
    final batch = _db!.batch();
    for (final email in emails) {
      batch.insert(
        'emails',
        {
          'id': email.id,
          'sender': email.sender,
          'senderEmail': email.senderEmail,
          'subject': email.subject,
          'snippet': email.snippet,
          'time': email.time,
          'body': email.body,
          'htmlBody': email.htmlBody,
          'isRead': email.isRead ? 1 : 0,
          'isImportant': email.isImportant ? 1 : 0,
          'isStarred': email.isStarred ? 1 : 0,
          'labels': email.labels.join(','),
          'attachments': '', // Not storing attachments for now
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
    await _loadAllEmails();
  }

  // --- Personal/Important ---
  Set<String> get personalEmails => _personalEmails;
  Set<String> get importantEmailIds => _importantEmailIds;

  bool isPersonal(String senderEmail) => _personalEmails.contains(senderEmail);
  bool isImportant(String emailId) => _importantEmailIds.contains(emailId);

  Future<void> markPersonal(String senderEmail) async {
    await init();
    _personalEmails.add(senderEmail);
    await _db!.insert('personal_emails', {'email': senderEmail},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> unmarkPersonal(String senderEmail) async {
    await init();
    _personalEmails.remove(senderEmail);
    await _db!.delete('personal_emails', where: 'email = ?', whereArgs: [senderEmail]);
  }

  Future<void> markImportant(String emailId) async {
    await init();
    _importantEmailIds.add(emailId);
    await _db!.insert('important_emails', {'emailId': emailId},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> unmarkImportant(String emailId) async {
    await init();
    _importantEmailIds.remove(emailId);
    await _db!.delete('important_emails', where: 'emailId = ?', whereArgs: [emailId]);
  }

  // --- Counts for tabs ---
  int get allEmailCount => _allEmails.length;
  int get unreadEmailCount => _allEmails.where((e) => !e.isRead).length;
  int get readEmailCount => _allEmails.where((e) => e.isRead).length;
  int get attachmentEmailCount => _allEmails.where((e) => e.hasAttachments).length;

  // --- For detail/other pages ---
  List<EmailModel> get allEmails => _allEmails;
  List<EmailModel> get personalEmailList =>
      _allEmails.where((e) => _personalEmails.contains(e.senderEmail)).toList();
  List<EmailModel> get importantEmailList =>
      _allEmails.where((e) => _importantEmailIds.contains(e.id)).toList();

  get allEmailList => null;

  int get importantEmailCount => _allEmails.where((e) => _importantEmailIds.contains(e.id)).length;

  // --- User signature ---
  Future<void> saveUserSignature(String signature) async {
    await init();
    await _db!.insert(
      'user_settings',
      {'key': 'signature', 'value': signature},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getUserSignature() async {
    await init();
    final result = await _db!.query(
      'user_settings',
      where: 'key = ?',
      whereArgs: ['signature'],
      limit: 1,
    );
    if (result.isNotEmpty) {
      return result.first['value'] as String?;
    }
    return null;
  }

  // Add this method to provide the open database instance
  Future<Database> getDatabase() async {
    // Replace with your actual database initialization logic
    // Example assumes you use sqflite and have a path set up
    final databasesPath = await getDatabasesPath();
    final path = '$databasesPath/replywise.db';
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        // Create user_settings table if not exists
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        // ...create other tables as needed...
      },
    );
  }

  Future<void> ensureUserSettingsTable() async {
    final db = await getDatabase();
    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_settings (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');
  }
}

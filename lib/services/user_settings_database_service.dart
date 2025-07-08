import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class UserSettingsDatabaseService {
  static final UserSettingsDatabaseService _instance = UserSettingsDatabaseService._internal();
  factory UserSettingsDatabaseService() => _instance;
  UserSettingsDatabaseService._internal();

  Database? _db;

  Future<void> init() async {
    if (_db != null) return;
    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      join(dbPath, 'replywise_user_settings.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE user_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
  }

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
}

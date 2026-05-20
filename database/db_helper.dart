import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  factory DBHelper() => _instance;

  DBHelper._internal();

  static const String _dbName = 'vitalmate.db';

  static const int _dbVersion = 5;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> getDB() async => await database;

  Future<Database> _initDB() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, _dbName);
    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON;');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      await _createUserProfileTable(txn);
      await _createHealthProfileTable(txn);
      await _createMeasurementsTable(txn);
      await _createRemindersTable(txn);
      await _createChatSessionsTable(txn);
      await _createChatTable(txn);
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Version 5: add value_3 + notes to measurements (non-destructive ALTER)
    if (oldVersion < 5) {
      await db.transaction((txn) async {
        // Try each ALTER separately — sqflite throws if column already exists,
        // so we swallow those specific errors gracefully.
        try {
          await txn.execute('ALTER TABLE measurements ADD COLUMN value_3 REAL');
        } catch (_) {
          // Column already exists — safe to ignore
        }
        try {
          await txn.execute('ALTER TABLE measurements ADD COLUMN notes TEXT');
        } catch (_) {
          // Column already exists — safe to ignore
        }
      });
      return;
    }

    // Full rebuild for any other version jump (shouldn't happen in normal flow)
    await db.transaction((txn) async {
      await txn.execute('DROP TABLE IF EXISTS chat_messages');
      await txn.execute('DROP TABLE IF EXISTS chat_sessions');
      await txn.execute('DROP TABLE IF EXISTS reminders');
      await txn.execute('DROP TABLE IF EXISTS measurements');
      await txn.execute('DROP TABLE IF EXISTS health_profile');
      await txn.execute('DROP TABLE IF EXISTS evaluation_rules');
      await txn.execute('DROP TABLE IF EXISTS user_profile');

      await _createUserProfileTable(txn);
      await _createHealthProfileTable(txn);
      await _createMeasurementsTable(txn);
      await _createRemindersTable(txn);
      await _createChatSessionsTable(txn);
      await _createChatTable(txn);
    });
  }

  // Table creation

  Future<void> _createUserProfileTable(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE user_profile (
        user_id             INTEGER PRIMARY KEY AUTOINCREMENT,
        full_name           TEXT    NOT NULL,
        age                 INTEGER,
        gender              TEXT,
        height_cm           REAL,
        weight_kg           REAL,
        profile_image_url   TEXT,
        created_at          DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _createHealthProfileTable(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE health_profile (
        health_profile_id     INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id               INTEGER UNIQUE,
        has_diabetes          INTEGER DEFAULT 0,
        has_hypertension      INTEGER DEFAULT 0,
        allergies             TEXT,
        existing_conditions   TEXT,
        medications           TEXT,
        created_at            DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES user_profile(user_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createMeasurementsTable(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE measurements (
        measurement_id    INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id           INTEGER NOT NULL,
        measurement_type  TEXT,
        value_1           REAL    NOT NULL,
        value_2           REAL,
        value_3           REAL,
        is_fasting        INTEGER,
        measured_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES user_profile(user_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createRemindersTable(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE reminders (
        reminder_id    INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id        INTEGER NOT NULL,
        reminder_type  TEXT,
        message        TEXT,
        reminder_time  DATETIME,
        repeat_type    TEXT,
        is_completed   INTEGER DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES user_profile(user_id) ON DELETE CASCADE
      )
    ''');
  }

  // Each conversation is a session. Title = first user message (capped 40 chars).
  Future<void> _createChatSessionsTable(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE chat_sessions (
        session_id  INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     INTEGER NOT NULL,
        title       TEXT    NOT NULL DEFAULT 'New chat',
        created_at  DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id) REFERENCES user_profile(user_id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> _createChatTable(Transaction txn) async {
    await txn.execute('''
      CREATE TABLE chat_messages (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id     INTEGER NOT NULL,
        session_id  INTEGER NOT NULL,
        message     TEXT    NOT NULL,
        sender      TEXT    NOT NULL,
        timestamp   DATETIME DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (user_id)    REFERENCES user_profile(user_id)       ON DELETE CASCADE,
        FOREIGN KEY (session_id) REFERENCES chat_sessions(session_id)   ON DELETE CASCADE
      )
    ''');
  }

  // Measurement methods
  Future<int> insertMeasurement(Map<String, dynamic> data) async {
    final db = await database;
    return await db.insert(
      'measurements',
      data,
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Returns the most recent measurement of [type] for [userId].
  Future<Map<String, Object?>?> getLatestMeasurement(
    int userId,
    String type,
  ) async {
    final db = await database;
    final rows = await db.query(
      'measurements',
      where: 'user_id = ? AND measurement_type = ?',
      whereArgs: [userId, type],
      orderBy: 'measured_at DESC',
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Returns all measurements of [type] for [userId], newest first.
  Future<List<Map<String, Object?>>> getMeasurementHistory(
    int userId,
    String type, {
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      'measurements',
      where: 'user_id = ? AND measurement_type = ?',
      whereArgs: [userId, type],
      orderBy: 'measured_at DESC',
      limit: limit,
    );
  }

  /// Deletes a single measurement by its primary key.
  Future<int> deleteMeasurement(int measurementId) async {
    final db = await database;
    return await db.delete(
      'measurements',
      where: 'measurement_id = ?',
      whereArgs: [measurementId],
    );
  }

  // Health score

  Future<double> calculateHealthScore(int userId) async {
    final health = await getHealthProfile(userId);
    if (health == null) return 70.0;

    double score = 90.0;
    if (health['has_diabetes'] == 1) score -= 10;
    if (health['has_hypertension'] == 1) score -= 10;

    // Adjust score based on latest readings
    final bp = await getLatestMeasurement(userId, 'Blood Pressure');
    if (bp != null) {
      final sys = (bp['value_1'] as num?)?.toInt() ?? 0;
      final dia = (bp['value_2'] as num?)?.toInt() ?? 0;
      if (sys >= 140 || dia >= 90) {
        score -= 10; // High BP
      } else if (sys >= 130 || dia >= 85) {
        score -= 5; // Elevated
      }
    }

    final bs = await getLatestMeasurement(userId, 'Blood Sugar');
    if (bs != null) {
      final sugar = (bs['value_1'] as num?)?.toInt() ?? 0;
      if (sugar >= 200) {
        score -= 10; // High sugar
      } else if (sugar >= 140) {
        score -= 5; // Elevated
      }
    }

    return score.clamp(0.0, 100.0);
  }

  // Session methods

  Future<int> createChatSession(int userId, {String title = 'New chat'}) async {
    final db = await database;
    return await db.insert('chat_sessions', {
      'user_id': userId,
      'title': title,
    });
  }

  Future<void> updateSessionTitle(int sessionId, String title) async {
    final db = await database;
    final trimmed = title.length > 40 ? '${title.substring(0, 40)}...' : title;
    await db.update(
      'chat_sessions',
      {'title': trimmed},
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  Future<List<Map<String, Object?>>> getChatSessions(int userId) async {
    final db = await database;
    return await db.query(
      'chat_sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> deleteChatSession(int sessionId) async {
    final db = await database;
    await db.delete(
      'chat_sessions',
      where: 'session_id = ?',
      whereArgs: [sessionId],
    );
  }

  // Message methods

  Future<List<Map<String, Object?>>> getChatHistory(
    int userId, {
    required int sessionId,
  }) async {
    final db = await database;
    return await db.query(
      'chat_messages',
      where: 'user_id = ? AND session_id = ?',
      whereArgs: [userId, sessionId],
      orderBy: 'timestamp ASC',
    );
  }

  Future<int> insertMessage(
    int userId,
    String message,
    String sender, {
    required int sessionId,
  }) async {
    final db = await database;
    return await db.insert('chat_messages', {
      'user_id': userId,
      'session_id': sessionId,
      'message': message,
      'sender': sender,
    });
  }

  // User / Health profile methods

  Future<bool> hasExistingUser() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM user_profile',
    );
    final count = Sqflite.firstIntValue(result) ?? 0;
    return count > 0;
  }

  Future<Map<String, Object?>?> getFirstUser() async {
    final db = await database;
    final rows = await db.query(
      'user_profile',
      orderBy: 'created_at ASC',
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<Map<String, Object?>?> getHealthProfile(int userId) async {
    final db = await database;
    final rows = await db.query(
      'health_profile',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<int> insertUserProfile({
    required String fullName,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? profileImageUrl,
  }) async {
    final db = await database;
    return db.insert('user_profile', {
      'full_name': fullName,
      'age': age,
      'gender': gender,
      'height_cm': heightCm,
      'weight_kg': weightKg,
      'profile_image_url': profileImageUrl,
    });
  }

  Future<int> insertHealthProfile({
    required int userId,
    required bool hasDiabetes,
    required bool hasHypertension,
    String? allergies,
    String? existingConditions,
    String? medications,
  }) async {
    final db = await database;
    return db.insert('health_profile', {
      'user_id': userId,
      'has_diabetes': hasDiabetes ? 1 : 0,
      'has_hypertension': hasHypertension ? 1 : 0,
      'allergies': allergies,
      'existing_conditions': existingConditions,
      'medications': medications,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, Object?>>> getUserProfiles() async {
    final db = await database;
    return db.query('user_profile', orderBy: 'created_at DESC');
  }

  Future<int> updateUserProfile({
    required int userId,
    String? fullName,
    int? age,
    String? gender,
    double? heightCm,
    double? weightKg,
    String? profileImageUrl,
  }) async {
    final db = await database;
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (age != null) data['age'] = age;
    if (gender != null) data['gender'] = gender;
    if (heightCm != null) data['height_cm'] = heightCm;
    if (weightKg != null) data['weight_kg'] = weightKg;
    if (profileImageUrl != null) data['profile_image_url'] = profileImageUrl;
    if (data.isEmpty) return 0;
    return db.update(
      'user_profile',
      data,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<int> updateHealthProfile({
    required int userId,
    bool? hasDiabetes,
    bool? hasHypertension,
    String? allergies,
    String? existingConditions,
    String? medications,
  }) async {
    final db = await database;
    final data = <String, dynamic>{};
    if (hasDiabetes != null) data['has_diabetes'] = hasDiabetes ? 1 : 0;
    if (hasHypertension != null) {
      data['has_hypertension'] = hasHypertension ? 1 : 0;
    }
    if (allergies != null) data['allergies'] = allergies;
    if (existingConditions != null) {
      data['existing_conditions'] = existingConditions;
    }
    if (medications != null) data['medications'] = medications;
    if (data.isEmpty) return 0;
    return db.update(
      'health_profile',
      data,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // These cover full CRUD for the reminders table.
  Future<int> insertReminder({
    required int userId,
    required String reminderType,
    required String message,
    required DateTime reminderTime,
    required String repeatType,
  }) async {
    final db = await database;
    return await db.insert('reminders', {
      'user_id': userId,
      'reminder_type': reminderType,
      'message': message,
      'reminder_time': reminderTime.toIso8601String(),
      'repeat_type': repeatType,
      'is_completed': 0,
    });
  }

  Future<List<Map<String, Object?>>> getReminders(int userId) async {
    final db = await database;
    return await db.query(
      'reminders',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'reminder_time ASC',
    );
  }

  Future<int> markReminderCompleted(int reminderId) async {
    final db = await database;
    return await db.update(
      'reminders',
      {'is_completed': 1},
      where: 'reminder_id = ?',
      whereArgs: [reminderId],
    );
  }

  Future<int> deleteReminder(int reminderId) async {
    final db = await database;
    return await db.delete(
      'reminders',
      where: 'reminder_id = ?',
      whereArgs: [reminderId],
    );
  }

  Future<int> deleteAllReminders(int userId) async {
    final db = await database;
    return await db.delete(
      'reminders',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  // Utility

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}

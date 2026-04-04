import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

class PendingMeasurement {
  final int? dbId;
  final int? apartmentId;
  final String meterId;
  final String apartmentInfo;
  final String value;
  final String ocrValue;
  final bool modifiedByUser;
  final String photoPath;
  final String capturedAt;
  final int retryCount;
  final String? lastError;

  PendingMeasurement({
    this.dbId,
    this.apartmentId,
    required this.meterId,
    required this.apartmentInfo,
    required this.value,
    this.ocrValue = '',
    this.modifiedByUser = false,
    required this.photoPath,
    required this.capturedAt,
    this.retryCount = 0,
    this.lastError,
  });

  Map<String, dynamic> toMap() {
    return {
      if (dbId != null) 'id': dbId,
      'apartment_id': apartmentId,
      'meter_id': meterId,
      'apartment_info': apartmentInfo,
      'value': value,
      'ocr_value': ocrValue,
      'modified_by_user': modifiedByUser ? 1 : 0,
      'photo_path': photoPath,
      'captured_at': capturedAt,
      'retry_count': retryCount,
      'last_error': lastError,
    };
  }

  factory PendingMeasurement.fromMap(Map<String, dynamic> map) {
    return PendingMeasurement(
      dbId: map['id'] as int?,
      apartmentId: map['apartment_id'] as int?,
      meterId: map['meter_id'] as String,
      apartmentInfo: map['apartment_info'] as String,
      value: map['value'] as String,
      ocrValue: map['ocr_value'] as String? ?? '',
      modifiedByUser: (map['modified_by_user'] as int? ?? 0) == 1,
      photoPath: map['photo_path'] as String,
      capturedAt: map['captured_at'] as String,
      retryCount: map['retry_count'] as int? ?? 0,
      lastError: map['last_error'] as String?,
    );
  }

  PendingMeasurement copyWith({int? retryCount, String? lastError}) {
    return PendingMeasurement(
      dbId: dbId,
      apartmentId: apartmentId,
      meterId: meterId,
      apartmentInfo: apartmentInfo,
      value: value,
      ocrValue: ocrValue,
      modifiedByUser: modifiedByUser,
      photoPath: photoPath,
      capturedAt: capturedAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }
}

class PendingMeasurementDb {
  static const String _dbName = 'hydroscan_pending.db';
  static const String _table = 'pending_measurements';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, _dbName);

    debugPrint('[DB] Opening database at $path');

    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            apartment_id INTEGER,
            meter_id TEXT NOT NULL,
            apartment_info TEXT NOT NULL,
            value TEXT NOT NULL,
            ocr_value TEXT DEFAULT '',
            modified_by_user INTEGER DEFAULT 0,
            photo_path TEXT NOT NULL,
            captured_at TEXT NOT NULL,
            retry_count INTEGER DEFAULT 0,
            last_error TEXT,
            created_at TEXT DEFAULT CURRENT_TIMESTAMP
          )
        ''');
        debugPrint('[DB] Table $_table created');
      },
    );
  }

  Future<int> insert(PendingMeasurement m) async {
    final db = await database;
    final id = await db.insert(_table, m.toMap());
    debugPrint('[DB] Inserted pending measurement #$id (meter: ${m.meterId})');
    return id;
  }

  Future<List<PendingMeasurement>> getAll() async {
    final db = await database;
    final maps = await db.query(_table, orderBy: 'created_at ASC');
    return maps.map((m) => PendingMeasurement.fromMap(m)).toList();
  }

  Future<int> count() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM $_table');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> delete(int id) async {
    final db = await database;
    await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    debugPrint('[DB] Deleted pending measurement #$id');
  }

  Future<void> updateRetry(int id, int retryCount, String error) async {
    final db = await database;
    await db.update(
      _table,
      {'retry_count': retryCount, 'last_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}

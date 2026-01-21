import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'receipt.dart';

class ReceiptDatabase {
  ReceiptDatabase._();

  static final ReceiptDatabase instance = ReceiptDatabase._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = p.join(dir.path, 'receiptonce.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE receipts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            merchant TEXT NOT NULL,
            total_cents INTEGER,
            purchase_date TEXT,
            category TEXT,
            image_path TEXT,
            raw_text TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
      },
    );
  }

  Future<int> insertReceipt(Receipt receipt) async {
    final db = await database;
    return db.insert('receipts', receipt.toMap());
  }

  Future<List<Receipt>> fetchReceipts() async {
    final db = await database;
    final rows = await db.query(
      'receipts',
      orderBy: 'created_at DESC',
    );
    return rows.map(Receipt.fromMap).toList();
  }

  Future<int> getScanCount() async {
    final db = await database;
    final rows =
        await db.query('app_settings', where: 'key = ?', whereArgs: ['scan_count']);
    if (rows.isEmpty) return 0;
    final value = rows.first['value'] as String?;
    return int.tryParse(value ?? '') ?? 0;
  }

  Future<void> incrementScanCount() async {
    final db = await database;
    final current = await getScanCount();
    await db.insert(
      'app_settings',
      {'key': 'scan_count', 'value': '${current + 1}'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isPro() async {
    final db = await database;
    final rows =
        await db.query('app_settings', where: 'key = ?', whereArgs: ['is_pro']);
    if (rows.isEmpty) return false;
    final value = (rows.first['value'] as String?) ?? 'false';
    return value.toLowerCase() == 'true';
  }

  Future<void> setPro(bool isPro) async {
    final db = await database;
    await db.insert(
      'app_settings',
      {'key': 'is_pro', 'value': isPro ? 'true' : 'false'},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

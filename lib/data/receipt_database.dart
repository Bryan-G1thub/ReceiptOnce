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
      version: 3,
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
            note TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE app_settings (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await _createIndexes(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createIndexes(db);
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE receipts ADD COLUMN note TEXT');
        }
      },
    );
  }

  Future<void> _createIndexes(Database db) async {
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_receipts_created_at ON receipts(created_at)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_receipts_category ON receipts(category)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_receipts_total_cents ON receipts(total_cents)',
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

  Future<List<Receipt>> searchReceipts({
    String query = '',
    String category = 'All',
    String sort = 'Newest',
  }) async {
    final db = await database;
    final whereParts = <String>[];
    final whereArgs = <Object?>[];

    if (category != 'All') {
      whereParts.add('category = ?');
      whereArgs.add(category);
    }

    final trimmedQuery = query.trim();
    if (trimmedQuery.isNotEmpty) {
      final likeQuery = '%$trimmedQuery%';
      final conditions = <String>[
        'merchant LIKE ?',
        'category LIKE ?',
        'purchase_date LIKE ?',
        'raw_text LIKE ?',
        'note LIKE ?',
        'created_at LIKE ?',
      ];
      whereArgs.addAll([
        likeQuery,
        likeQuery,
        likeQuery,
        likeQuery,
        likeQuery,
        likeQuery,
      ]);
      final cents = _parseQueryCents(trimmedQuery);
      if (cents != null) {
        conditions.add('total_cents = ?');
        whereArgs.add(cents);
      }
      whereParts.add('(${conditions.join(' OR ')})');
    }

    final whereClause =
        whereParts.isEmpty ? null : whereParts.join(' AND ');

    return (await db.query(
      'receipts',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: _orderByForSort(sort),
    ))
        .map(Receipt.fromMap)
        .toList();
  }

  String _orderByForSort(String sort) {
    switch (sort) {
      case 'Oldest':
        return 'created_at ASC';
      case 'Amount high to low':
        return 'CASE WHEN total_cents IS NULL THEN 1 ELSE 0 END, total_cents DESC, created_at DESC';
      case 'Amount low to high':
        return 'CASE WHEN total_cents IS NULL THEN 1 ELSE 0 END, total_cents ASC, created_at DESC';
      case 'Newest':
      default:
        return 'created_at DESC';
    }
  }

  int? _parseQueryCents(String query) {
    final cleaned = query.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    final value = double.tryParse(cleaned);
    if (value == null) return null;
    return (value * 100).round();
  }

  Future<int> updateReceipt(Receipt receipt) async {
    final db = await database;
    final id = receipt.id;
    if (id == null) return 0;
    final data = receipt.toMap();
    data.remove('id');
    return db.update(
      'receipts',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteReceipt(int id) async {
    final db = await database;
    return db.delete(
      'receipts',
      where: 'id = ?',
      whereArgs: [id],
    );
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

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../models/operation.dart';

class OperationsDb {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  static Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, 'easyfinance_operations.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE operations (
            id TEXT PRIMARY KEY,
            client_id TEXT,
            type TEXT,
            amount REAL,
            transfer_amount REAL,
            currency TEXT,
            account_id TEXT,
            to_account_id TEXT,
            category_id TEXT,
            date TEXT,
            comment TEXT,
            tags TEXT,
            is_deleted INTEGER DEFAULT 0,
            is_pending INTEGER DEFAULT 0,
            updated_at TEXT
          )
        ''');
        await db.execute('CREATE INDEX idx_operations_date ON operations(date)');
        await db.execute('CREATE INDEX idx_operations_account ON operations(account_id)');
      },
    );
  }

  static Future<void> saveAll(List<Operation> operations) async {
    final db = await database;
    final batch = db.batch();
    for (final op in operations) {
      batch.insert(
        'operations',
        _opToMap(op),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  static Future<List<Operation>> getAll() async {
    final db = await database;
    final rows = await db.query('operations', orderBy: 'date DESC');
    return rows.map(_mapToOp).toList();
  }

  static Future<List<Operation>> getByDateRange(String from, String to) async {
    final db = await database;
    final rows = await db.query(
      'operations',
      where: 'date >= ? AND date <= ?',
      whereArgs: [from, to],
      orderBy: 'date DESC',
    );
    return rows.map(_mapToOp).toList();
  }

  static Future<int> count() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as cnt FROM operations');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  static Future<void> deleteAll() async {
    final db = await database;
    await db.delete('operations');
  }

  static Map<String, dynamic> _opToMap(Operation op) {
    return {
      'id': op.id,
      'client_id': op.clientId,
      'type': op.type,
      'amount': op.amount,
      'transfer_amount': op.transferAmount,
      'currency': op.currency,
      'account_id': op.accountId,
      'to_account_id': op.toAccountId,
      'category_id': op.categoryId,
      'date': op.date,
      'comment': op.comment,
      'tags': op.tags,
      'is_deleted': op.isDeleted ? 1 : 0,
      'is_pending': op.isPending ? 1 : 0,
      'updated_at': op.updatedAt,
    };
  }

  static Operation _mapToOp(Map<String, dynamic> r) {
    return Operation(
      id: r['id'] as String? ?? '',
      clientId: r['client_id'] as String?,
      type: r['type'] as String? ?? 'expense',
      amount: (r['amount'] as num?)?.toDouble() ?? 0,
      transferAmount: (r['transfer_amount'] as num?)?.toDouble(),
      currency: r['currency'] as String? ?? 'RUB',
      accountId: r['account_id'] as String? ?? '',
      toAccountId: r['to_account_id'] as String?,
      categoryId: r['category_id'] as String?,
      date: r['date'] as String? ?? '',
      comment: r['comment'] as String?,
      tags: r['tags'] as String?,
      isDeleted: (r['is_deleted'] as int?) == 1,
      isPending: (r['is_pending'] as int?) == 1,
      updatedAt: r['updated_at'] as String?,
    );
  }
}

import 'package:sqflite/sqflite.dart';
import '../models/asset.dart';
import '../models/expense.dart';
import 'database_service.dart';

class AssetRepository {
  Future<Database> get _db async => await DatabaseService.database;

  // 创建资产记录
  Future<int> createRecord(AssetRecord record, List<AssetItem> items) async {
    final db = await _db;
    
    return await db.transaction((txn) async {
      // 插入主记录
      int recordId = await txn.insert('records', record.toMap());
      
      // 插入明细项
      for (var item in items) {
        await txn.insert('items', {
          ...item.toMap(),
          'record_id': recordId,
        });
      }
      
      return recordId;
    });
  }

  // 获取所有月份
  Future<List<String>> getMonths() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT month FROM records ORDER BY month DESC
    ''');
    return maps.map((m) => m['month'] as String).toList();
  }

  // 获取指定月份的记录
  Future<AssetRecord?> getRecordByMonth(String month) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'records',
      where: 'month = ?',
      whereArgs: [month],
    );
    
    if (maps.isEmpty) return null;
    
    final record = AssetRecord.fromMap(maps.first);
    final items = await getItemsByRecordId(record.id!);
    
    return AssetRecord.fromMap(maps.first, items: items);
  }

  // 获取所有记录
  Future<List<AssetRecord>> getAllRecords() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'records',
      orderBy: 'month DESC',
    );
    
    List<AssetRecord> records = [];
    for (var map in maps) {
      final items = await getItemsByRecordId(map['id']);
      records.add(AssetRecord.fromMap(map, items: items));
    }
    
    return records;
  }

  // 获取记录明细
  Future<List<AssetItem>> getItemsByRecordId(int recordId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'items',
      where: 'record_id = ?',
      whereArgs: [recordId],
    );
    return maps.map((m) => AssetItem.fromMap(m)).toList();
  }

  // 删除记录
  Future<void> deleteRecord(int id) async {
    final db = await _db;
    await db.delete('records', where: 'id = ?', whereArgs: [id]);
  }
}

class ExpenseRepository {
  Future<Database> get _db async => await DatabaseService.database;

  // 创建支出记录
  Future<int> createExpense(Expense expense) async {
    final db = await _db;
    return await db.insert('expenses', expense.toMap());
  }

  // 获取支出列表
  Future<List<Expense>> getExpenses({String? month, int limit = 100}) async {
    final db = await _db;
    
    List<Map<String, dynamic>> maps;
    if (month != null) {
      maps = await db.rawQuery('''
        SELECT * FROM expenses 
        WHERE strftime('%Y-%m', date) = ?
        ORDER BY date DESC, timestamp DESC
        LIMIT ?
      ''', [month, limit]);
    } else {
      maps = await db.query(
        'expenses',
        orderBy: 'date DESC, timestamp DESC',
        limit: limit,
      );
    }
    
    return maps.map((m) => Expense.fromMap(m)).toList();
  }

  // 获取月度汇总
  Future<Map<String, dynamic>> getSummary(String month) async {
    final db = await _db;
    
    // 按分类汇总
    final categoryMaps = await db.rawQuery('''
      SELECT category, SUM(amount) as total, COUNT(*) as count
      FROM expenses WHERE strftime('%Y-%m', date) = ?
      GROUP BY category
      ORDER BY total DESC
    ''', [month]);
    
    double totalAmount = 0;
    for (var m in categoryMaps) {
      totalAmount += (m['total'] as num).toDouble();
    }
    
    // 按日期汇总
    final dateMaps = await db.rawQuery('''
      SELECT date, SUM(amount) as total, COUNT(*) as count
      FROM expenses WHERE strftime('%Y-%m', date) = ?
      GROUP BY date
      ORDER BY date ASC
    ''', [month]);
    
    return {
      'month': month,
      'total': totalAmount,
      'by_category': categoryMaps,
      'by_date': dateMaps,
      'record_count': dateMaps.fold(0, (sum, m) => sum + (m['count'] as int)),
    };
  }

  // 获取有记录的月份
  Future<List<String>> getMonths() async {
    final db = await _db;
    final maps = await db.rawQuery('''
      SELECT DISTINCT strftime('%Y-%m', date) as month
      FROM expenses ORDER BY month DESC
    ''');
    return maps.map((m) => m['month'] as String).toList();
  }

  // 删除支出记录
  Future<void> deleteExpense(int id) async {
    final db = await _db;
    await db.delete('expenses', where: 'id = ?', whereArgs: [id]);
  }
}

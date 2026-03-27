import 'package:sqflite/sqflite.dart';
import '../models/asset.dart';
import '../models/expense.dart';
import '../services/database_service.dart';

class AssetRepository {
  Future<Database> get _db async => await DatabaseService.database;

  // 创建或更新资产记录（同月份合并）
  Future<int> createRecord(AssetRecord record) async {
    final db = await _db;
    
    return await db.transaction((txn) async {
      // 检查该月份是否已有记录
      final existing = await txn.query(
        'records',
        where: 'month = ?',
        whereArgs: [record.month],
      );
      
      int recordId;
      
      if (existing.isNotEmpty) {
        // 更新现有记录
        recordId = existing.first['id'] as int;
        final oldItems = await txn.query(
          'items',
          where: 'record_id = ?',
          whereArgs: [recordId],
        );
        
        // 合并金额
        double totalAssets = record.totalAssets;
        double totalLiabilities = record.totalLiabilities;
        
        for (var item in oldItems) {
          final amount = (item['amount'] as num).toDouble();
          // 根据分类判断是资产还是负债
          final category = item['category'] as String;
          if (_isLiability(category)) {
            totalLiabilities += amount;
          } else {
            totalAssets += amount;
          }
        }
        
        await txn.update(
          'records',
          {
            'total_assets': totalAssets,
            'total_liabilities': totalLiabilities,
            'net_assets': totalAssets - totalLiabilities,
            'timestamp': DateTime.now().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [recordId],
        );
        
        // 添加新的明细项
        for (var item in record.items) {
          await txn.insert('items', {
            ...item.toMap(),
            'record_id': recordId,
          });
        }
      } else {
        // 创建新记录
        recordId = await txn.insert('records', record.toMap());
        
        // 插入明细项
        for (var item in record.items) {
          await txn.insert('items', {
            ...item.toMap(),
            'record_id': recordId,
          });
        }
      }
      
      return recordId;
    });
  }
  
  bool _isLiability(String category) {
    const liabilityCategories = ['信用卡', '花呗', '借呗', '房贷', '车贷', '其他负债'];
    return liabilityCategories.contains(category);
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

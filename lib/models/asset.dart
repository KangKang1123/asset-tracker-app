class AssetRecord {
  final int? id;
  final String month;
  final String timestamp;
  final double totalAssets;
  final double totalLiabilities;
  final double netAssets;
  final List<AssetItem> items;

  AssetRecord({
    this.id,
    required this.month,
    required this.timestamp,
    this.totalAssets = 0,
    this.totalLiabilities = 0,
    this.netAssets = 0,
    this.items = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'month': month,
      'timestamp': timestamp,
      'total_assets': totalAssets,
      'total_liabilities': totalLiabilities,
      'net_assets': netAssets,
    };
  }

  factory AssetRecord.fromMap(Map<String, dynamic> map, {List<AssetItem> items = const []}) {
    return AssetRecord(
      id: map['id'],
      month: map['month'],
      timestamp: map['timestamp'],
      totalAssets: map['total_assets'] ?? 0,
      totalLiabilities: map['total_liabilities'] ?? 0,
      netAssets: map['net_assets'] ?? 0,
      items: items,
    );
  }
}

class AssetItem {
  final int? id;
  final int recordId;
  final String category;
  final String name;
  final double amount;

  AssetItem({
    this.id,
    required this.recordId,
    required this.category,
    required this.name,
    required this.amount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'record_id': recordId,
      'category': category,
      'name': name,
      'amount': amount,
    };
  }

  factory AssetItem.fromMap(Map<String, dynamic> map) {
    return AssetItem(
      id: map['id'],
      recordId: map['record_id'],
      category: map['category'],
      name: map['name'],
      amount: map['amount'],
    );
  }
}

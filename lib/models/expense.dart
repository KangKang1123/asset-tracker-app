class Expense {
  final int? id;
  final String date;
  final String category;
  final String name;
  final double amount;
  final String note;
  final String timestamp;

  Expense({
    this.id,
    required this.date,
    required this.category,
    required this.name,
    required this.amount,
    this.note = '',
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date,
      'category': category,
      'name': name,
      'amount': amount,
      'note': note,
      'timestamp': timestamp,
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      date: map['date'],
      category: map['category'],
      name: map['name'],
      amount: map['amount'],
      note: map['note'] ?? '',
      timestamp: map['timestamp'],
    );
  }
}

// 支出分类
class ExpenseCategory {
  final String value;
  final String label;
  final String icon;

  const ExpenseCategory({
    required this.value,
    required this.label,
    required this.icon,
  });
}

const List<ExpenseCategory> expenseCategories = [
  ExpenseCategory(value: '餐饮', label: '🍜 餐饮', icon: '🍜'),
  ExpenseCategory(value: '交通', label: '🚗 交通', icon: '🚗'),
  ExpenseCategory(value: '服饰', label: '👕 服饰', icon: '👕'),
  ExpenseCategory(value: '购物', label: '🛒 购物', icon: '🛒'),
  ExpenseCategory(value: '运动', label: '🏃 运动', icon: '🏃'),
  ExpenseCategory(value: '娱乐', label: '🎬 娱乐', icon: '🎬'),
  ExpenseCategory(value: '学习', label: '📚 学习', icon: '📚'),
  ExpenseCategory(value: '医疗', label: '💊 医疗', icon: '💊'),
  ExpenseCategory(value: '居住', label: '🏠 居住', icon: '🏠'),
  ExpenseCategory(value: '社交', label: '💝 社交', icon: '💝'),
  ExpenseCategory(value: '宠物', label: '🐾 宠物', icon: '🐾'),
  ExpenseCategory(value: '其他', label: '💰 其他', icon: '💰'),
];

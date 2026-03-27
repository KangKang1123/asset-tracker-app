import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'models/expense.dart';
import 'repositories/repository.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '资产管家',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;
  
  final List<Widget> _pages = [
    const AssetPage(),
    const ExpensePage(),
    const TrendPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.account_balance_wallet), label: '资产'),
          NavigationDestination(icon: Icon(Icons.shopping_cart), label: '支出'),
          NavigationDestination(icon: Icon(Icons.trending_up), label: '趋势'),
        ],
      ),
    );
  }
}

// ==================== 资产页面 ====================
class AssetPage extends StatefulWidget {
  const AssetPage({super.key});

  @override
  State<AssetPage> createState() => _AssetPageState();
}

class _AssetPageState extends State<AssetPage> {
  final AssetRepository _repository = AssetRepository();
  List<String> _months = [];
  AssetRecord? _currentRecord;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    _months = await _repository.getMonths();
    if (_months.isNotEmpty) {
      _currentRecord = await _repository.getRecordByMonth(_months.first);
    }
    
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('资产概览'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddDialog(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_currentRecord == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('暂无资产记录', style: TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddDialog(),
              icon: const Icon(Icons.add),
              label: const Text('添加记录'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 16),
          _buildItemsCard(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final record = _currentRecord!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本月概览 · ${record.month}', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem('总资产', record.totalAssets, Colors.green),
                ),
                Expanded(
                  child: _buildStatItem('总负债', record.totalLiabilities, Colors.red),
                ),
                Expanded(
                  child: _buildStatItem('净资产', record.netAssets, Colors.blue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '¥${value.toStringAsFixed(0)}',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }

  Widget _buildItemsCard() {
    final items = _currentRecord?.items ?? [];
    final groupedItems = <String, List<AssetItem>>{};
    
    for (var item in items) {
      groupedItems.putIfAbsent(item.category, () => []).add(item);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('资产明细', style: Theme.of(context).textTheme.titleMedium),
            const Divider(),
            ...groupedItems.entries.map((entry) {
              final categoryTotal = entry.value.fold<double>(0, (sum, item) => sum + item.amount);
              return ExpansionTile(
                title: Text(entry.key),
                trailing: Text('¥${categoryTotal.toStringAsFixed(0)}', 
                  style: const TextStyle(fontWeight: FontWeight.bold)),
                children: entry.value.map((item) => ListTile(
                  title: Text(item.name),
                  trailing: Text('¥${item.amount.toStringAsFixed(0)}'),
                )).toList(),
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('添加资产记录'),
        content: const Text('请在Web版添加资产记录，手机端暂只支持查看。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }
}

// ==================== 支出页面 ====================
class ExpensePage extends StatefulWidget {
  const ExpensePage({super.key});

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> {
  final ExpenseRepository _repository = ExpenseRepository();
  List<Expense> _expenses = [];
  Map<String, dynamic>? _summary;
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    
    _expenses = await _repository.getExpenses(month: _selectedMonth);
    _summary = await _repository.getSummary(_selectedMonth);
    
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('支出记录'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddExpenseDialog(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddExpenseDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 16),
          _buildCategoryChart(),
          const SizedBox(height: 16),
          _buildExpenseList(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    final total = _summary?['total'] ?? 0;
    final count = _summary?['record_count'] ?? 0;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text('本月支出', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  '¥${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red),
                ),
              ],
            ),
            Column(
              children: [
                const Text('记录笔数', style: TextStyle(color: Colors.grey)),
                const SizedBox(height: 4),
                Text(
                  '$count 笔',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChart() {
    final byCategory = _summary?['by_category'] as List? ?? [];
    
    if (byCategory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('分类统计', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...byCategory.map((item) {
              final percent = (_summary?['total'] ?? 0) > 0 
                  ? (item['total'] as num) / _summary!['total'] * 100 
                  : 0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(item['category'] as String),
                    ),
                    Expanded(
                      flex: 3,
                      child: LinearProgressIndicator(value: percent / 100),
                    ),
                    Expanded(
                      child: Text('¥${(item['total'] as num).toStringAsFixed(0)}', 
                        textAlign: TextAlign.right),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildExpenseList() {
    if (_expenses.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey),
              const SizedBox(height: 8),
              Text('本月暂无支出记录', style: TextStyle(color: Colors.grey[600])),
            ],
          ),
        ),
      );
    }

    return Card(
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _expenses.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final expense = _expenses[index];
          return ListTile(
            leading: CircleAvatar(
              child: Text(_getCategoryIcon(expense.category)),
            ),
            title: Text(expense.name),
            subtitle: Text(expense.date),
            trailing: Text(
              '-¥${expense.amount.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            onLongPress: () => _deleteExpense(expense),
          );
        },
      ),
    );
  }

  String _getCategoryIcon(String category) {
    for (var cat in expenseCategories) {
      if (cat.value == category) return cat.icon;
    }
    return '💰';
  }

  void _showAddExpenseDialog() {
    String selectedCategory = '餐饮';
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('记一笔'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 日期选择
                ListTile(
                  title: const Text('日期'),
                  trailing: Text(DateFormat('MM-dd').format(selectedDate)),
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => selectedDate = date);
                    }
                  },
                ),
                // 分类选择
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  decoration: const InputDecoration(labelText: '分类'),
                  items: expenseCategories.map((cat) => DropdownMenuItem(
                    value: cat.value,
                    child: Text(cat.label),
                  )).toList(),
                  onChanged: (value) {
                    setState(() => selectedCategory = value!);
                  },
                ),
                // 金额输入
                TextField(
                  controller: amountController,
                  decoration: const InputDecoration(labelText: '金额'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                // 备注输入
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(labelText: '备注（可选）'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('请输入有效金额')),
                  );
                  return;
                }

                await _repository.createExpense(Expense(
                  date: DateFormat('yyyy-MM-dd').format(selectedDate),
                  category: selectedCategory,
                  name: _getCategoryLabel(selectedCategory),
                  amount: amount,
                  note: noteController.text,
                  timestamp: DateTime.now().toIso8601String(),
                ));

                if (mounted) {
                  Navigator.pop(context);
                  _loadData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('记录成功')),
                  );
                }
              },
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryLabel(String category) {
    for (var cat in expenseCategories) {
      if (cat.value == category) return cat.label;
    }
    return category;
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录'),
        content: Text('确定删除这笔 ¥${expense.amount.toStringAsFixed(2)} 的支出记录吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.deleteExpense(expense.id!);
      _loadData();
    }
  }
}

// ==================== 趋势页面 ====================
class TrendPage extends StatefulWidget {
  const TrendPage({super.key});

  @override
  State<TrendPage> createState() => _TrendPageState();
}

class _TrendPageState extends State<TrendPage> {
  final AssetRepository _repository = AssetRepository();
  List<AssetRecord> _records = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    _records = await _repository.getAllRecords();
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('资产趋势'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_records.isEmpty) {
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
      );
    }

    // 只取最近6个月
    final recentRecords = _records.take(6).toList().reversed.toList();
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('净资产趋势', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 60,
                            getTitlesWidget: (value, meta) {
                              if (value >= 10000) {
                                return Text('${(value / 10000).toStringAsFixed(0)}万', 
                                  style: const TextStyle(fontSize: 10));
                              }
                              return Text(value.toStringAsFixed(0), 
                                style: const TextStyle(fontSize: 10));
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (value, meta) {
                              if (value.toInt() < recentRecords.length) {
                                final month = recentRecords[value.toInt()].month;
                                return Text(month.split('-').last, 
                                  style: const TextStyle(fontSize: 10));
                              }
                              return const Text('');
                            },
                          ),
                        ),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          isCurved: true,
                          spots: recentRecords.asMap().entries.map((e) {
                            return FlSpot(e.key.toDouble(), e.value.netAssets);
                          }).toList(),
                          color: Colors.blue,
                          barWidth: 3,
                          dotData: const FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _records.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final record = _records[index];
              return ListTile(
                title: Text(record.month),
                subtitle: Text('净资产: ¥${record.netAssets.toStringAsFixed(0)}'),
                trailing: Text('总资产: ¥${record.totalAssets.toStringAsFixed(0)}'),
              );
            },
          ),
        ),
      ],
    );
  }
}

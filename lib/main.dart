import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import 'models/asset.dart';
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
      builder: (context) => _AddAssetDialog(
        repository: _repository,
        onSaved: () {
          _loadData();
        },
      ),
    );
  }
}

// 添加资产对话框
class _AddAssetDialog extends StatefulWidget {
  final AssetRepository repository;
  final VoidCallback onSaved;

  const _AddAssetDialog({required this.repository, required this.onSaved});

  @override
  State<_AddAssetDialog> createState() => _AddAssetDialogState();
}

class _AddAssetDialogState extends State<_AddAssetDialog> {
  final _formKey = GlobalKey<FormState>();
  String _selectedMonth = DateFormat('yyyy-MM').format(DateTime.now());
  final List<_AssetInput> _assetInputs = [];
  final List<_AssetInput> _liabilityInputs = [];
  bool _saving = false;

  // 资产分类
  static const assetCategories = ['现金', '银行卡', '支付宝', '微信', '基金', '股票', '房产', '车辆', '其他资产'];
  // 负债分类
  static const liabilityCategories = ['信用卡', '花呗', '借呗', '房贷', '车贷', '其他负债'];

  @override
  void initState() {
    super.initState();
    _addAssetInput(isAsset: true);
  }

  void _addAssetInput({required bool isAsset}) {
    setState(() {
      if (isAsset) {
        _assetInputs.add(_AssetInput(
          category: assetCategories.first,
          nameController: TextEditingController(),
          amountController: TextEditingController(),
        ));
      } else {
        _liabilityInputs.add(_AssetInput(
          category: liabilityCategories.first,
          nameController: TextEditingController(),
          amountController: TextEditingController(),
        ));
      }
    });
  }

  void _removeAssetInput(int index, {required bool isAsset}) {
    setState(() {
      if (isAsset && _assetInputs.length > 1) {
        _assetInputs[index].nameController.dispose();
        _assetInputs[index].amountController.dispose();
        _assetInputs.removeAt(index);
      } else if (!isAsset && _liabilityInputs.length > 1) {
        _liabilityInputs[index].nameController.dispose();
        _liabilityInputs[index].amountController.dispose();
        _liabilityInputs.removeAt(index);
      }
    });
  }

  @override
  void dispose() {
    for (var input in [..._assetInputs, ..._liabilityInputs]) {
      input.nameController.dispose();
      input.amountController.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    try {
      // 计算总额
      double totalAssets = 0;
      double totalLiabilities = 0;

      final items = <AssetItem>[];

      for (var input in _assetInputs) {
        final amount = double.parse(input.amountController.text);
        if (amount > 0) {
          totalAssets += amount;
          items.add(AssetItem(
            recordId: 0,
            category: input.category,
            name: input.nameController.text.isEmpty ? input.category : input.nameController.text,
            amount: amount,
          ));
        }
      }

      for (var input in _liabilityInputs) {
        final amount = double.parse(input.amountController.text);
        if (amount > 0) {
          totalLiabilities += amount;
          items.add(AssetItem(
            recordId: 0,
            category: input.category,
            name: input.nameController.text.isEmpty ? input.category : input.nameController.text,
            amount: amount,
          ));
        }
      }

      if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请至少添加一项资产或负债')),
        );
        setState(() => _saving = false);
        return;
      }

      final record = AssetRecord(
        month: _selectedMonth,
        timestamp: DateTime.now().toIso8601String(),
        totalAssets: totalAssets,
        totalLiabilities: totalLiabilities,
        netAssets: totalAssets - totalLiabilities,
        items: items,
      );

      await widget.repository.createRecord(record);

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('保存成功')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加资产记录'),
      content: SizedBox(
        width: double.maxFinite,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 月份选择
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('记录月份'),
                  trailing: Text(_selectedMonth),
                  onTap: () async {
                    final now = DateTime.now();
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(now.year + 1, 12),
                    );
                    if (date != null) {
                      setState(() => _selectedMonth = DateFormat('yyyy-MM').format(date));
                    }
                  },
                ),
                const SizedBox(height: 16),

                // 资产部分
                Row(
                  children: [
                    const Text('💰 资产', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _addAssetInput(isAsset: true),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加'),
                    ),
                  ],
                ),
                ..._assetInputs.asMap().entries.map((e) => _buildAssetInput(e.key, e.value, isAsset: true)),

                const SizedBox(height: 16),

                // 负债部分
                Row(
                  children: [
                    const Text('📉 负债', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _addAssetInput(isAsset: false),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('添加'),
                    ),
                  ],
                ),
                if (_liabilityInputs.isEmpty)
                  TextButton(
                    onPressed: () => _addAssetInput(isAsset: false),
                    child: const Text('+ 添加负债项'),
                  )
                else
                  ..._liabilityInputs.asMap().entries.map((e) => _buildAssetInput(e.key, e.value, isAsset: false)),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('保存'),
        ),
      ],
    );
  }

  Widget _buildAssetInput(int index, _AssetInput input, {required bool isAsset}) {
    final categories = isAsset ? assetCategories : liabilityCategories;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: input.category,
                    decoration: const InputDecoration(labelText: '分类', isDense: true),
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => input.category = v!),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: input.amountController,
                    decoration: const InputDecoration(labelText: '金额', isDense: true),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      if (v == null || v.isEmpty) return '必填';
                      if (double.tryParse(v) == null) return '请输入数字';
                      return null;
                    },
                  ),
                ),
                if ((isAsset && _assetInputs.length > 1) || (!isAsset && _liabilityInputs.length > 1))
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => _removeAssetInput(index, isAsset: isAsset),
                  ),
              ],
            ),
            TextFormField(
              controller: input.nameController,
              decoration: const InputDecoration(labelText: '备注（可选）', isDense: true),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssetInput {
  String category;
  final TextEditingController nameController;
  final TextEditingController amountController;

  _AssetInput({
    required this.category,
    required this.nameController,
    required this.amountController,
  });
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

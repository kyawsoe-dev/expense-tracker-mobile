import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_app_bar.dart';
import '../../../expenses/domain/entities/expense.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../expenses/presentation/screens/add_expense_screen.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  static const _pageSize = 20;

  String _selectedCategory = 'All';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  Timer? _searchDebounce;
  List<Expense> _expenses = const [];
  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _total = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    _loadInitialCacheFirst();
  }

  Future<void> _loadInitialCacheFirst() async {
    try {
      final page = await ref.read(expenseRepositoryProvider).getExpenseHistory(
            take: _pageSize,
            skip: 0,
            search: _searchController.text,
            category: _selectedCategory == 'All' ? null : _selectedCategory,
            forceUpdate: false,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _expenses = page.items;
        _total = page.total;
        _hasMore = page.hasMore;
        _isInitialLoading = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      await _loadInitial();
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(recentExpensesProvider);
    ref.invalidate(monthOverviewProvider);
    ref.invalidate(yearAnalyticsProvider);
    await _loadInitial();
  }

  void _handleScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      _loadInitial();
    });
  }

  Future<void> _loadInitial() async {
    final existingExpenses = _expenses;
    setState(() {
      _isInitialLoading = existingExpenses.isEmpty;
      _errorMessage = null;
      _hasMore = true;
    });

    try {
      final page = await ref.read(expenseRepositoryProvider).getExpenseHistory(
            take: _pageSize,
            skip: 0,
            search: _searchController.text,
            category: _selectedCategory == 'All' ? null : _selectedCategory,
            forceUpdate: true,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _expenses = page.items;
        _total = page.total;
        _hasMore = page.hasMore;
        _isInitialLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      if (existingExpenses.isNotEmpty) {
        setState(() => _isInitialLoading = false);
        return;
      }
      setState(() {
        _errorMessage = _friendlyError(error);
        _expenses = const [];
        _total = 0;
        _hasMore = false;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) {
      return;
    }

    setState(() => _isLoadingMore = true);

    try {
      final page = await ref.read(expenseRepositoryProvider).getExpenseHistory(
            take: _pageSize,
            skip: _expenses.length,
            search: _searchController.text,
            category: _selectedCategory == 'All' ? null : _selectedCategory,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _expenses = [..._expenses, ...page.items];
        _total = page.total;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _editExpense(Expense expense) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddExpenseScreen(initialExpense: expense),
      ),
    );

    if (updated == true) {
      await _refresh();
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete expense'),
        content: Text('Delete "${expense.title}" permanently?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.accent,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      final repo = ref.read(expenseRepositoryProvider);
      await repo.deleteExpense(expense.id);
      await _refresh();
    } on DioException {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to delete expense. Please try again.'),
        ),
      );
    }
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      final serverMessage = error.response?.data is Map<String, dynamic>
          ? error.response?.data['message'] as String?
          : null;
      if (serverMessage != null && serverMessage.trim().isNotEmpty) {
        return serverMessage;
      }

      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Cannot connect to API. Try again.';
      }
    }

    return 'Could not load history right now.';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final categories = <String>{'All', ..._expenses.map((e) => e.category)};

    return Scaffold(
      backgroundColor: palette.background,
      appBar: const ModernAppBar(
        title: 'History',
        subtitle: 'Filter and review every record',
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 110),
          children: [
            _HistoryHeader(
              expenses: _expenses,
              selectedCategory: _selectedCategory,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search title, note, category, or group',
                prefixIcon: const Icon(Icons.search_rounded),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                filled: true,
                fillColor: palette.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Categories',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories.map((category) {
                final selected = _selectedCategory == category;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : palette.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) {
                    setState(() => _selectedCategory = category);
                    _loadInitial();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            _CategoryChartCard(
              expenses: _expenses,
              selectedCategory: _selectedCategory,
            ),
            const SizedBox(height: 18),
            _SectionHeader(
              title: 'Recent records',
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '$_total items',
                  style: TextStyle(
                    color: palette.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_isInitialLoading)
              const Center(
                  child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ))
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: context.appCardDecoration(),
                child: Text(
                  _errorMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: palette.textPrimary,
                      ),
                ),
              )
            else if (_expenses.isEmpty)
              _HistoryEmptyState(
                hasSearch: _searchController.text.trim().isNotEmpty,
                selectedCategory: _selectedCategory,
              )
            else ...[
              ..._expenses.map(
                (expense) => _HistoryCard(
                  expense: expense,
                  onEdit: () => _editExpense(expense),
                  onDelete: () => _deleteExpense(expense),
                ),
              ),
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: Text(
                      'Scroll for more records',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  final List<Expense> expenses;
  final String selectedCategory;

  const _HistoryHeader({
    required this.expenses,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final total = expenses.fold<double>(0, (sum, e) => sum + e.amount);
    final amount = NumberFormat.currency(symbol: 'MMK ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: context.heroGradient,
        borderRadius: const BorderRadius.all(Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: palette.heroStart.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    selectedCategory == 'All'
                        ? 'All categories'
                        : selectedCategory,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  amount.format(total),
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  '${expenses.length} transactions selected',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withValues(alpha: 0.74),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.pie_chart_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChartCard extends StatelessWidget {
  final List<Expense> expenses;
  final String selectedCategory;

  const _CategoryChartCard({
    required this.expenses,
    required this.selectedCategory,
  });

  Color _colorForCategory(String category, AppPalette palette) {
    final colors = [
      palette.accent,
      palette.primary,
      const Color(0xFF2D325A),
      palette.success,
      const Color(0xFFFFC857),
      const Color(0xFF3AAED8),
    ];
    final normalized = category.trim().toLowerCase();
    final hash = normalized.runes.fold<int>(0, (value, rune) => value + rune);
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final grouped = <String, double>{};
    for (final expense in expenses) {
      grouped.update(expense.category, (value) => value + expense.amount,
          ifAbsent: () => expense.amount);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
    final amount = NumberFormat.currency(symbol: 'MMK ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: context.appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Analytics',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                selectedCategory == 'All' ? 'Top categories' : 'Filtered view',
                style: TextStyle(
                  color: palette.textMuted,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (entries.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: palette.surfaceSoft,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'No analytics available for this category yet.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          else
            SizedBox(
              height: 220,
              child: Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 42,
                      sections: List.generate(entries.take(4).length, (index) {
                        final entry = entries[index];
                        final percentage =
                            total == 0 ? 0 : (entry.value / total) * 100;
                        return PieChartSectionData(
                          value: entry.value,
                          color: _colorForCategory(entry.key, palette),
                          radius: 68,
                          title: '${percentage.toStringAsFixed(0)}%',
                          titleStyle: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
              ),
            ),
          if (entries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 12,
              children: List.generate(entries.take(4).length, (index) {
                final entry = entries[index];
                return Container(
                  constraints: const BoxConstraints(minWidth: 136),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: palette.surfaceSoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _colorForCategory(entry.key, palette),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: palette.textPrimary,
                            ),
                          ),
                          Text(
                            amount.format(entry.value),
                            style: TextStyle(
                              color: palette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget trailing;

  const _SectionHeader({
    required this.title,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        trailing,
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Expense expense;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _HistoryCard({
    required this.expense,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final amount = NumberFormat.currency(symbol: 'MMK ', decimalDigits: 0);
    final date = DateFormat('dd MMM yyyy').format(expense.date.toLocal());

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: context.appCardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: palette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${expense.category} • $date',
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
                if (expense.groupName != null &&
                    expense.groupName!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.accentSoft,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      expense.groupName!,
                      style: TextStyle(
                        color: palette.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                if (expense.note != null &&
                    expense.note!.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    expense.note!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: palette.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (value) {
              if (value == 'edit') {
                onEdit();
              } else if (value == 'delete') {
                onDelete();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem<String>(
                value: 'edit',
                child: Text('Edit'),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text('Delete'),
              ),
            ],
          ),
          const SizedBox(width: 4),
          Text(
            amount.format(expense.amount),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: palette.success,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  final bool hasSearch;
  final String selectedCategory;

  const _HistoryEmptyState({
    required this.hasSearch,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: context.appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: palette.accentSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.search_off_rounded,
              color: palette.accent,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            hasSearch
                ? 'No expenses match your search yet.'
                : 'No expenses match this category yet.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            hasSearch
                ? 'Try another keyword or clear search to load more records.'
                : selectedCategory == 'All'
                    ? 'Add a new expense to start building your history.'
                    : 'Try another category or add a new expense to see it here.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

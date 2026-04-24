import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/dio_provider.dart';
import '../../../../core/session/session_user.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_app_bar.dart';
import '../../domain/entities/expense.dart';
import '../../domain/entities/expense_month_summary.dart';
import '../../domain/entities/expense_year_analytics.dart';
import '../providers/expense_providers.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  final VoidCallback onOpenProfile;
  final Future<void> Function() onSignOut;

  const DashboardScreen({
    super.key,
    required this.onOpenProfile,
    required this.onSignOut,
  });

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  late DateTime _selectedMonth;
  late int _selectedAnalyticsYear;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month);
    _selectedAnalyticsYear = now.year;
  }

  Future<void> _refresh() async {
    ref.invalidate(recentExpensesProvider);
    ref.invalidate(monthOverviewProvider);
    ref.invalidate(yearAnalyticsProvider);
    await Future.wait([
      ref.read(recentExpensesProvider.future),
      ref.read(monthOverviewProvider(_selectedMonth).future),
      ref.read(yearAnalyticsProvider(_selectedAnalyticsYear).future),
    ]).timeout(
      const Duration(seconds: 10),
      onTimeout: () => [],
    );
  }

  Future<SessionUser> _loadUser() async {
    final storage = ref.read(tokenStorageProvider);
    final name = await storage.readUserName();
    final email = await storage.readUserEmail();

    if ((name != null && name.trim().isNotEmpty) ||
        (email != null && email.trim().isNotEmpty)) {
      return SessionUser.fromStoredProfile(email: email, name: name);
    }

    final accessToken = await storage.readAccessToken();
    return SessionUser.fromAccessToken(accessToken);
  }

  String _friendlyError(Object error) {
    if (error is DioException) {
      if (error.type == DioExceptionType.connectionError ||
          error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout) {
        return 'Cannot connect to API. Start backend at port 3000 and try again.';
      }
      if (error.response?.statusCode == 401) {
        return 'Session expired. Please log in again.';
      }

      final serverMessage = error.response?.data is Map<String, dynamic>
          ? (error.response!.data['message'] as String?)
          : null;
      if (serverMessage != null && serverMessage.trim().isNotEmpty) {
        return serverMessage;
      }
    }

    return 'Something went wrong. Please try again.';
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final expensesAsync = ref.watch(recentExpensesProvider);
    final monthSummaryAsync = ref.watch(monthOverviewProvider(_selectedMonth));
    final yearAnalyticsAsync =
        ref.watch(yearAnalyticsProvider(_selectedAnalyticsYear));

    return Scaffold(
      backgroundColor: palette.background,
      appBar: ModernAppBar(
        title: 'Home',
        subtitle: DateFormat('EEEE, dd MMM').format(DateTime.now()),
        actions: [
          FutureBuilder<SessionUser>(
            future: _loadUser(),
            builder: (context, snapshot) {
              final user = snapshot.data ?? const SessionUser();
              final seedText = (user.name ?? user.email ?? 'U').trim();
              final initial = seedText.isEmpty
                  ? 'U'
                  : seedText.substring(0, 1).toUpperCase();
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: widget.onOpenProfile,
                  child: CircleAvatar(
                    radius: 19,
                    backgroundColor: palette.primary,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: expensesAsync.when(
          data: (expenses) {
            return FutureBuilder<SessionUser>(
              future: _loadUser(),
              builder: (context, snapshot) {
                final user = snapshot.data ?? const SessionUser();
                final displayName = user.name ?? user.email ?? 'there';

                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 6, 18, 110),
                  children: [
                    Text(
                      '${_greeting()}, $displayName',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Track your MMK spending with a cleaner snapshot of each month and the full year ahead.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
                    monthSummaryAsync.when(
                      data: (summary) => _BalanceCard(
                        summary: summary,
                        selectedMonth: _selectedMonth,
                        availableMonths: _monthOptions(),
                        onSelectedMonth: (month) {
                          setState(() => _selectedMonth = month);
                        },
                      ),
                      loading: () => _BalanceCardSkeleton(
                        selectedMonth: _selectedMonth,
                        availableMonths: _monthOptions(),
                        onSelectedMonth: (month) {
                          setState(() => _selectedMonth = month);
                        },
                      ),
                      error: (error, _) => _InlineError(
                        message: _friendlyError(error),
                        onRetry: _refresh,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _SyncReadyCard(),
                    const SizedBox(height: 18),
                    _SectionHeader(
                      title: 'Analytics',
                      trailing: _YearFilterChip(
                        selectedYear: _selectedAnalyticsYear,
                        years: _yearOptions(),
                        onSelected: (year) {
                          setState(() => _selectedAnalyticsYear = year);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    yearAnalyticsAsync.when(
                      data: (analytics) => _AnalyticsCard(analytics: analytics),
                      loading: () => const _AnalyticsLoadingCard(),
                      error: (error, _) => _InlineError(
                        message: _friendlyError(error),
                        onRetry: _refresh,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _SectionHeader(
                      title: 'Recent transactions',
                      trailing: TextButton(
                        onPressed: widget.onOpenProfile,
                        child: const Text('Profile'),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (expenses.isEmpty)
                      const _EmptyState()
                    else
                      ...expenses.take(5).map(
                            (expense) => _TransactionCard(expense: expense),
                          ),
                    if (expenses.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      OutlinedButton.icon(
                        onPressed: widget.onSignOut,
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign out'),
                      ),
                    ],
                  ],
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _InlineError(
                message: _friendlyError(error),
                onRetry: _refresh,
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<DateTime> _monthOptions() {
    final now = DateTime.now();
    return List.generate(
      24,
      (index) => DateTime(now.year, now.month - index),
    );
  }

  List<int> _yearOptions() {
    final now = DateTime.now().year;
    return List.generate(6, (index) => now - index);
  }
}

class _BalanceCard extends StatelessWidget {
  final ExpenseMonthSummary summary;
  final DateTime selectedMonth;
  final List<DateTime> availableMonths;
  final ValueChanged<DateTime> onSelectedMonth;

  const _BalanceCard({
    required this.summary,
    required this.selectedMonth,
    required this.availableMonths,
    required this.onSelectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final amount = NumberFormat.currency(symbol: 'MMK ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.all(Radius.circular(30)),
        gradient: context.heroGradient,
        boxShadow: [
          BoxShadow(
            color: palette.heroStart.withValues(alpha: 0.24),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  'Monthly overview',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              _MonthFilterChip(
                selectedMonth: selectedMonth,
                months: availableMonths,
                onSelected: onSelectedMonth,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            amount.format(summary.total),
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Your selected month total across all tracked expenses.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.74),
                ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _BalanceMeta(
                  label: 'Transactions',
                  value: '${summary.transactionCount}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _BalanceMeta(
                  label: 'Top category',
                  value: summary.topCategory ?? 'No spending yet',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceCardSkeleton extends StatelessWidget {
  final DateTime selectedMonth;
  final List<DateTime> availableMonths;
  final ValueChanged<DateTime> onSelectedMonth;

  const _BalanceCardSkeleton({
    required this.selectedMonth,
    required this.availableMonths,
    required this.onSelectedMonth,
  });

  @override
  Widget build(BuildContext context) {
    return _BalanceCard(
      summary: ExpenseMonthSummary(
        year: selectedMonth.year,
        month: selectedMonth.month,
        total: 0,
        transactionCount: 0,
        topCategory: null,
        byCategory: const [],
      ),
      selectedMonth: selectedMonth,
      availableMonths: availableMonths,
      onSelectedMonth: onSelectedMonth,
    );
  }
}

class _SyncReadyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: context.appCardDecoration(
        color: palette.surfaceSoft,
        radius: 24,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.sync_rounded,
              color: palette.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Offline-ready flow',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your latest expenses and groups can stay visible offline. New offline changes are prepared to sync when the app reconnects.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceMeta extends StatelessWidget {
  final String label;
  final String value;

  const _BalanceMeta({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final ExpenseYearAnalytics analytics;

  const _AnalyticsCard({required this.analytics});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final labels = analytics.byMonth.map((item) => item.label).toList();
    final values = analytics.byMonth.map((item) => item.total).toList();
    final maxValue =
        values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final amount =
        NumberFormat.compactCurrency(symbol: 'MMK ', decimalDigits: 0);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      decoration: context.appCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _AnalyticsMeta(
                  label: 'Year total',
                  value: amount.format(analytics.total),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AnalyticsMeta(
                  label: 'Top category',
                  value: analytics.topCategory ?? 'No data yet',
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 230,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxValue == 0 ? 1 : maxValue * 1.25,
                borderData: FlBorderData(show: false),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxValue == 0 ? 1 : maxValue / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: palette.border,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) => Text(
                        amount.format(value),
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.textMuted,
                        ),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= labels.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[index],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: palette.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => palette.textPrimary,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final label = groupIndex >= 0 && groupIndex < labels.length
                          ? labels[groupIndex]
                          : '';
                      return BarTooltipItem(
                        '$label\n${amount.format(rod.toY)}',
                        const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.w700),
                      );
                    },
                  ),
                ),
                barGroups: List.generate(values.length, (index) {
                  final isPeak = values[index] == maxValue;
                  return BarChartGroupData(
                    x: index,
                    barRods: [
                      BarChartRodData(
                        toY: values[index],
                        width: 18,
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          colors: isPeak
                              ? [palette.primary, palette.primaryDark]
                              : [palette.accentStart, palette.accent],
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AnalyticsLoadingCard extends StatelessWidget {
  const _AnalyticsLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _AnalyticsCard(
      analytics: ExpenseYearAnalytics(
        year: 0,
        total: 0,
        averageMonthly: 0,
        topCategory: null,
        byMonth: [
          ExpenseMonthPoint(month: 1, label: 'Jan', total: 0),
          ExpenseMonthPoint(month: 2, label: 'Feb', total: 0),
          ExpenseMonthPoint(month: 3, label: 'Mar', total: 0),
          ExpenseMonthPoint(month: 4, label: 'Apr', total: 0),
          ExpenseMonthPoint(month: 5, label: 'May', total: 0),
          ExpenseMonthPoint(month: 6, label: 'Jun', total: 0),
          ExpenseMonthPoint(month: 7, label: 'Jul', total: 0),
          ExpenseMonthPoint(month: 8, label: 'Aug', total: 0),
          ExpenseMonthPoint(month: 9, label: 'Sep', total: 0),
          ExpenseMonthPoint(month: 10, label: 'Oct', total: 0),
          ExpenseMonthPoint(month: 11, label: 'Nov', total: 0),
          ExpenseMonthPoint(month: 12, label: 'Dec', total: 0),
        ],
        byCategory: [],
      ),
    );
  }
}

class _AnalyticsMeta extends StatelessWidget {
  final String label;
  final String value;

  const _AnalyticsMeta({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: palette.surfaceSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: palette.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthFilterChip extends StatelessWidget {
  final DateTime selectedMonth;
  final List<DateTime> months;
  final ValueChanged<DateTime> onSelected;

  const _MonthFilterChip({
    required this.selectedMonth,
    required this.months,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DateTime>(
      initialValue: selectedMonth,
      onSelected: onSelected,
      itemBuilder: (context) => months
          .map(
            (month) => PopupMenuItem<DateTime>(
              value: month,
              child: Text(DateFormat('MMM yyyy').format(month)),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DateFormat('MMM yyyy').format(selectedMonth),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.expand_more_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _YearFilterChip extends StatelessWidget {
  final int selectedYear;
  final List<int> years;
  final ValueChanged<int> onSelected;

  const _YearFilterChip({
    required this.selectedYear,
    required this.years,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return PopupMenuButton<int>(
      initialValue: selectedYear,
      onSelected: onSelected,
      itemBuilder: (context) => years
          .map(
            (year) => PopupMenuItem<int>(
              value: year,
              child: Text('$year'),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: palette.accentSoft,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$selectedYear',
              style: TextStyle(
                color: palette.accent,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.expand_more_rounded, color: palette.accent, size: 16),
          ],
        ),
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

class _TransactionCard extends StatelessWidget {
  final Expense expense;

  const _TransactionCard({required this.expense});

  IconData _categoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
      case 'restaurant':
        return Icons.lunch_dining_rounded;
      case 'transport':
      case 'travel':
        return Icons.directions_car_filled_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'health':
        return Icons.health_and_safety_rounded;
      case 'entertainment':
        return Icons.movie_filter_rounded;
      default:
        return Icons.account_balance_wallet_rounded;
    }
  }

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
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _categoryIcon(expense.category),
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
          const SizedBox(width: 10),
          Text(
            amount.format(expense.amount),
            style: TextStyle(
              color: palette.success,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.inbox_rounded,
              color: palette.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'No expenses yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Tap the add button to create your first expense and unlock analytics.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;

  const _InlineError({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      decoration: context.appCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: palette.accentSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.wifi_off_outlined,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

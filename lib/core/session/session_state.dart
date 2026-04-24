import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/expenses/presentation/providers/expense_providers.dart';
import '../../features/groups/presentation/providers/group_providers.dart';

void resetSignedInData(WidgetRef ref) {
  ref.invalidate(expenseRepositoryProvider);
  ref.invalidate(recentExpensesProvider);
  ref.invalidate(monthOverviewProvider);
  ref.invalidate(yearAnalyticsProvider);
  ref.invalidate(groupExpensesProvider);
  ref.invalidate(groupRepositoryProvider);
  ref.invalidate(groupsProvider);
  ref.invalidate(groupDetailProvider);
}

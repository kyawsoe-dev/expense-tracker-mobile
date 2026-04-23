import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/modern_app_bar.dart';
import '../../../groups/presentation/providers/group_providers.dart';
import '../../domain/entities/expense.dart';
import '../providers/expense_providers.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final Expense? initialExpense;

  const AddExpenseScreen({
    super.key,
    this.initialExpense,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  bool _submitting = false;
  String? _selectedGroupId;

  bool get _isEditMode => widget.initialExpense != null;

  @override
  void initState() {
    super.initState();
    final expense = widget.initialExpense;
    if (expense != null) {
      _titleCtrl.text = expense.title;
      _amountCtrl.text = expense.amount.toStringAsFixed(0);
      _categoryCtrl.text = expense.category;
      _noteCtrl.text = expense.note ?? '';
      _selectedDate = expense.date;
      _selectedGroupId = expense.groupId;
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _categoryCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) return;

    setState(() => _submitting = true);
    try {
      final repo = ref.read(expenseRepositoryProvider);
      if (_isEditMode) {
        await repo.updateExpense(
          id: widget.initialExpense!.id,
          title: _titleCtrl.text.trim(),
          amount: amount,
          category: _categoryCtrl.text.trim(),
          date: _selectedDate,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          groupId: _selectedGroupId,
        );
      } else {
        await repo.createExpense(
          title: _titleCtrl.text.trim(),
          amount: amount,
          category: _categoryCtrl.text.trim(),
          date: _selectedDate,
          note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
          groupId: _selectedGroupId,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on DioException catch (e) {
      if (!mounted) return;
      final serverMessage = e.response?.data is Map<String, dynamic>
          ? (e.response!.data['message'] as String?)
          : null;
      final status = e.response?.statusCode;

      final message = status == 400
          ? (serverMessage ?? 'Invalid expense data. Please check your inputs.')
          : 'Failed to save expense. Please try again.';

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final groupsAsync = ref.watch(groupsProvider);
    final formattedDate =
        '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

    return Scaffold(
      backgroundColor: palette.background,
      appBar: ModernAppBar(
        title: _isEditMode ? 'Edit Expense' : 'Add Expense',
        subtitle: _isEditMode
            ? 'Update the details and save your changes'
            : 'Capture a new transaction in a few steps',
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: context.heroGradient,
                  borderRadius: const BorderRadius.all(Radius.circular(28)),
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
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.receipt_long_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isEditMode ? 'Update expense' : 'New expense',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: Colors.white,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Keep category, amount, and date clear so analytics stay accurate.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.76),
                                ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: context.appCardDecoration(),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                        hintText: 'Lunch, taxi, groceries...',
                        prefixIcon: Icon(Icons.title_rounded),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Enter a title'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                        hintText: '0',
                        prefixIcon: Icon(Icons.payments_outlined),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Enter an amount';
                        }
                        final parsed = double.tryParse(value.trim());
                        if (parsed == null || parsed <= 0) {
                          return 'Enter a valid positive amount';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _categoryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Category',
                        hintText: 'Food, transport, shopping...',
                        prefixIcon: Icon(Icons.category_rounded),
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Enter a category'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    groupsAsync.when(
                      data: (groups) => DropdownButtonFormField<String?>(
                        initialValue: _selectedGroupId,
                        decoration: const InputDecoration(
                          labelText: 'Group (optional)',
                          prefixIcon: Icon(Icons.group_work_rounded),
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Personal expense'),
                          ),
                          ...groups.map(
                            (group) => DropdownMenuItem<String?>(
                              value: group.id,
                              child: Text(group.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedGroupId = value);
                        },
                      ),
                      loading: () => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(
                          minHeight: 2,
                          color: palette.primary,
                        ),
                      ),
                      error: (_, __) => Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Groups unavailable right now. You can still save a personal expense.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _pickDate,
                      child: Ink(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: palette.surfaceSoft,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: palette.border),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: palette.surfaceMuted,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                Icons.calendar_month_rounded,
                                color: palette.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Date',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: palette.textPrimary,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: palette.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        hintText: 'Add context for this expense',
                        prefixIcon: Icon(Icons.notes_rounded),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _isEditMode ? 'Update Expense' : 'Save Expense'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

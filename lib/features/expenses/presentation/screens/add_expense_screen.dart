import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/ai/ai_providers.dart';
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
  late final TextEditingController _dateCtrl;
  DateTime _selectedDate = DateTime.now();
  bool _submitting = false;
  String? _selectedGroupId;
  String? _aiSuggestion;
  bool _isFetchingSuggestion = false;
  Timer? _debounceTimer;

  bool get _isEditMode => widget.initialExpense != null;

  static final _localCategoryKeywords = {
    'Food': ['lunch', 'dinner', 'breakfast', 'restaurant', 'cafe', 'coffee', 'pizza', 'burger', 'meal', 'snack', 'food', 'eat', 'dining', 'mcdonald', 'kfc', 'starbucks'],
    'Transport': ['taxi', 'uber', 'grab', 'bus', 'train', 'fuel', 'gas', 'parking', 'toll', 'metro', 'subway', 'flight', 'plane', 'ticket', 'transport', 'travel'],
    'Shopping': ['shopping', 'mall', 'amazon', 'clothes', 'shirt', 'shoes', 'dress', 'store', 'market', 'buy', 'purchase', 'retail'],
    'Health': ['doctor', 'hospital', 'pharmacy', 'medicine', 'medical', 'health', 'clinic', 'dental', 'eye', 'glasses', 'vitamin'],
    'Entertainment': ['movie', 'cinema', 'netflix', 'spotify', 'game', 'concert', 'music', 'theatre', 'fun', 'party', 'bar', 'club'],
    'Bills': ['electricity', 'water', 'internet', 'phone', 'bill', 'rent', 'mortgage', 'insurance', 'subscription', 'netflix', 'spotify'],
    'Education': ['book', 'course', 'tuition', 'school', 'university', 'college', 'study', 'exam', 'class', 'training', 'workshop'],
    'Groceries': ['grocery', 'supermarket', 'vegetable', 'fruit', 'meat', 'fish', 'milk', 'bread', 'eggs', 'rice', 'market'],
    'Travel': ['hotel', 'airbnb', 'vacation', 'holiday', 'tour', 'trip', 'flight', 'passport', 'visa', 'luggage'],
  };

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

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
    _dateCtrl = TextEditingController(text: _formatDate(_selectedDate));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _categoryCtrl.dispose();
    _noteCtrl.dispose();
    _dateCtrl.dispose();
    _debounceTimer?.cancel();
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
      setState(() {
        _selectedDate = picked;
        _dateCtrl.text = _formatDate(picked);
      });
    }
  }

  Future<void> _fetchAiSuggestion() async {
    final title = _titleCtrl.text.trim();
    if (title.length < 3) return;

    // Try local keyword matching first for instant results
    final localSuggestion = _findLocalSuggestion(title);
    if (localSuggestion != null && _categoryCtrl.text.trim().isEmpty) {
      setState(() {
        _aiSuggestion = localSuggestion;
        _categoryCtrl.text = localSuggestion;
      });
      return;
    }

    setState(() => _isFetchingSuggestion = true);
    try {
      final aiService = ref.read(aiServiceProvider);
      final suggestion = await aiService.suggestCategory(title, note: _noteCtrl.text.trim());
      debugPrint('AI suggestion: $suggestion');
      if (mounted && suggestion.isNotEmpty && suggestion != 'Other') {
        setState(() {
          _aiSuggestion = suggestion;
          if (_categoryCtrl.text.trim().isEmpty) {
            _categoryCtrl.text = suggestion;
          }
        });
      }
    } catch (e) {
      debugPrint('AI suggestion error: $e');
    } finally {
      if (mounted) setState(() => _isFetchingSuggestion = false);
    }
  }

  String? _findLocalSuggestion(String title) {
    final lowerTitle = title.toLowerCase();
    for (final entry in _localCategoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (lowerTitle.contains(keyword)) {
          return entry.key;
        }
      }
    }
    return null;
  }

  void _onTitleChanged(String value) {
    _debounceTimer?.cancel();
    if (value.trim().length < 3) {
      setState(() => _aiSuggestion = null);
      return;
    }

    // Try local matching instantly
    final localSuggestion = _findLocalSuggestion(value);
    if (localSuggestion != null && _categoryCtrl.text.trim().isEmpty) {
      setState(() {
        _aiSuggestion = localSuggestion;
        _categoryCtrl.text = localSuggestion;
      });
    }

    // Debounce AI call (500ms delay)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      if (_categoryCtrl.text.trim().isEmpty) {
        _fetchAiSuggestion();
      }
    });
  }

  void _applySuggestion() {
    if (_aiSuggestion != null && _aiSuggestion!.isNotEmpty) {
      setState(() {
        _categoryCtrl.text = _aiSuggestion!;
        _aiSuggestion = null;
      });
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
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Title',
                        hintText: 'Lunch, taxi, groceries...',
                        prefixIcon: const Icon(Icons.title_rounded),
                        suffixIcon: _aiSuggestion != null
                            ? Tooltip(
                                message: 'Category set to $_aiSuggestion',
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: palette.success,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _aiSuggestion!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: palette.success,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : null,
                      ),
                      onChanged: _onTitleChanged,
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Enter a title'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _amountCtrl,
                      style: Theme.of(context).textTheme.bodyLarge,
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
                      style: Theme.of(context).textTheme.bodyLarge,
                      decoration: InputDecoration(
                        labelText: 'Category',
                        hintText: 'Food, transport, shopping...',
                        prefixIcon: const Icon(Icons.category_rounded),
                        suffixIcon: _isFetchingSuggestion
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : _aiSuggestion != null
                                ? IconButton(
                                    icon: const Icon(Icons.auto_awesome),
                                    tooltip:
                                        'Apply AI suggestion: $_aiSuggestion',
                                    onPressed: _applySuggestion,
                                  )
                                : IconButton(
                                    icon: const Icon(Icons.lightbulb_outline),
                                    tooltip: 'Get AI suggestion',
                                    onPressed: _fetchAiSuggestion,
                                  ),
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
                        style: Theme.of(context).textTheme.bodyLarge,
                        selectedItemBuilder: (_) => [
                          Text(
                            'Personal expense',
                            style: Theme.of(context)
                                .textTheme
                                .bodyLarge
                                ?.copyWith(
                                  color: palette.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          ...groups.map(
                            (group) => Text(
                              group.name,
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Group (optional)',
                          prefixIcon: Icon(Icons.group_work_rounded),
                        ),
                        items: [
                          DropdownMenuItem<String?>(
                            value: null,
                            child: Text(
                              'Personal expense',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: palette.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          ...groups.map(
                            (group) => DropdownMenuItem<String?>(
                              value: group.id,
                              child: Text(
                                group.name,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
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
                    TextFormField(
                      readOnly: true,
                      onTap: _pickDate,
                      decoration: InputDecoration(
                        labelText: 'Date',
                        prefixIcon: Icon(
                          Icons.calendar_month_rounded,
                          color: palette.primary,
                        ),
                        suffixIcon: Icon(
                          Icons.chevron_right_rounded,
                          color: palette.textMuted,
                        ),
                      ),
                      controller: _dateCtrl,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _noteCtrl,
                      style: Theme.of(context).textTheme.bodyLarge,
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

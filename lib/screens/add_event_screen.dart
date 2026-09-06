import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_3_expressive/components/buttons/enums/m3e_button_enums.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:myapp/l10n/app_localizations.dart';
import '../models/event.dart';
import '../utils/event_utils.dart';

class AddEventBottomSheet extends StatefulWidget {
  final Function(Event) onAddEvent;
  final DateTime day;
  final Event? event;

  const AddEventBottomSheet({
    super.key,
    required this.onAddEvent,
    required this.day,
    this.event,
  });

  @override
  _AddEventBottomSheetState createState() => _AddEventBottomSheetState();
}

class _AddEventBottomSheetState extends State<AddEventBottomSheet>
    with TickerProviderStateMixin {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _startTime;
  late DateTime _selectedDate;
  DateTime? _endTime;
  late List<int> _repeatDays;
  late int _importance;
  late bool _isCompleted;
  // FIX: category is always stored as an English key (e.g. "School", "Home")
  late String _category;
  late String _userId;

  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  bool get isEditing => widget.event != null;
  bool _showTimeShortcuts = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeData();
  }

  void _initializeAnimations() {
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeOut));
    _slideController.forward();
    _fadeController.forward();
  }

  void _initializeData() {
    if (widget.event != null) {
      final event = widget.event!;
      _titleController = TextEditingController(text: event.title);
      _descriptionController = TextEditingController(
        text: event.description ?? '',
      );
      _startTime = event.startTime;
      _endTime = event.endTime;
      _selectedDate = event.startTime;
      _repeatDays = List<int>.from(event.repeatDays);
      _importance = event.importance ?? 0;
      _isCompleted = event.isCompleted;
      // FIX: category is already stored as English key — no translation needed
      _category = event.category;
      _userId = event.userId;
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _startTime = DateTime(
        widget.day.year,
        widget.day.month,
        widget.day.day,
        DateTime.now().hour,
        DateTime.now().minute,
      );
      _endTime = null;
      _selectedDate = widget.day;
      _repeatDays = [];
      _importance = 0;
      _isCompleted = false;
      _category = '';
      _userId = '';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _slideController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _closeWithAnimation() {
    _slideController.reverse();
    _fadeController.reverse();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQueryData = MediaQuery.of(context);
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return SlideTransition(
          position: _slideAnimation,
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 16,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.only(
                bottom: mediaQueryData.viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 12),
                        _buildMainFields(),
                        const SizedBox(height: 10),
                        _buildTimeSection(),
                        const SizedBox(height: 10),
                        _buildDateSection(),
                        const SizedBox(height: 12),
                        _buildOptionsSection(),
                        const SizedBox(height: 16),
                        _buildActionButtons(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Container(
        width: 36,
        height: 3,
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.3),
          borderRadius: BorderRadius.circular(1.5),
        ),
      ),
    );
  }

  Widget _buildMainFields() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isEditing ? Icons.edit : Icons.add,
                color: Theme.of(context).colorScheme.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isEditing ? l10n.editEvent : l10n.newEvent,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _titleController,
          label: l10n.eventTitle,
          hint: l10n.whatNeedsToBeDone,
          icon: Icons.title_rounded,
          isRequired: true,
        ),
        const SizedBox(height: 12),
        _buildTextField(
          controller: _descriptionController,
          label: l10n.description,
          hint: l10n.addSomeDetails,
          icon: Icons.description_outlined,
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool isRequired = false,
    int maxLines = 1,
  }) {
    return M3ETextField(
      controller: controller,
      label: isRequired ? '$label *' : label,
      supportingText: hint,
      leading: Icon(icon),
      variant: M3ETextFieldVariant.filled,
    );
  }

  void _applyTimeShortcut(String shortcut) {
    final now = DateTime.now();
    setState(() {
      switch (shortcut) {
        case '5min':
          _startTime = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            now.hour,
            now.minute,
          ).add(const Duration(minutes: 5));
          break;
        case '30min':
          _startTime = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            now.hour,
            now.minute,
          ).add(const Duration(minutes: 30));
          break;
        case '1hour':
          _startTime = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            now.hour,
            now.minute,
          ).add(const Duration(hours: 1));
          break;
        case 'morning':
          DateTime morningTime = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            9,
            0,
          );
          if (now.hour >= 9 && _selectedDate.day == now.day) {
            morningTime = morningTime.add(const Duration(days: 1));
            _selectedDate = _selectedDate.add(const Duration(days: 1));
          }
          _startTime = morningTime;
          _endTime = morningTime.add(const Duration(hours: 1));
          break;
        case 'afternoon':
          DateTime afternoonTime = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            14,
            0,
          );
          if (now.hour >= 14 && _selectedDate.day == now.day) {
            afternoonTime = afternoonTime.add(const Duration(days: 1));
            _selectedDate = _selectedDate.add(const Duration(days: 1));
          }
          _startTime = afternoonTime;
          break;
        case 'evening':
          DateTime eveningTime = DateTime(
            _selectedDate.year,
            _selectedDate.month,
            _selectedDate.day,
            18,
            0,
          );
          if (now.hour >= 18 && _selectedDate.day == now.day) {
            eveningTime = eveningTime.add(const Duration(days: 1));
            _selectedDate = _selectedDate.add(const Duration(days: 1));
          }
          _startTime = eveningTime;
          break;
      }
      _showTimeShortcuts = false;
    });
  }

  Widget _buildTimeShortcuts() {
    if (!_showTimeShortcuts) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.quickTime,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            M3EButton.text(
              onPressed: () => setState(() => _showTimeShortcuts = false),
              size: M3EButtonSize.xs,
              decoration: M3EButtonDecoration(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 0),
              ),
              child: Text(
                l10n.hide,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildTimeShortcutChip(
              label: l10n.in5min,
              icon: Icons.schedule,
              onTap: () => _applyTimeShortcut('5min'),
            ),
            _buildTimeShortcutChip(
              label: l10n.in30min,
              icon: Icons.access_time,
              onTap: () => _applyTimeShortcut('30min'),
            ),
            _buildTimeShortcutChip(
              label: l10n.in1hour,
              icon: Icons.schedule,
              onTap: () => _applyTimeShortcut('1hour'),
            ),
            _buildTimeShortcutChip(
              label: l10n.morningTime,
              icon: Icons.wb_sunny,
              onTap: () => _applyTimeShortcut('morning'),
            ),
            _buildTimeShortcutChip(
              label: l10n.afternoonTime,
              icon: Icons.wb_twilight,
              onTap: () => _applyTimeShortcut('afternoon'),
            ),
            _buildTimeShortcutChip(
              label: l10n.eveningTime,
              icon: Icons.nightlight_round,
              onTap: () => _applyTimeShortcut('evening'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeShortcutChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.time,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            if (!_showTimeShortcuts)
              M3EButton.icon(
                onPressed: () => setState(() => _showTimeShortcuts = true),
                icon: Icon(
                  Icons.bolt,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                label: Text(
                  l10n.quickLabel,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                style: M3EButtonStyle.tonal,
                size: M3EButtonSize.xs,
                decoration: M3EButtonDecoration(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: const Size(0, 0),
                  backgroundColor: WidgetStateProperty.all(
                    Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.5),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildTimeShortcuts(),
        if (_showTimeShortcuts) const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _showTimeShortcuts = false);
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainer.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: !_showTimeShortcuts
                    ? Theme.of(context).colorScheme.primary.withOpacity(0.5)
                    : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                width: !_showTimeShortcuts ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.edit_calendar,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.customTime,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.setSpecificTimes,
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  !_showTimeShortcuts ? Icons.expand_less : Icons.expand_more,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
          ),
        ),
        if (!_showTimeShortcuts) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTimeCard(
                  title: l10n.start,
                  time: _startTime,
                  icon: Icons.play_circle_outline,
                  onTap: () => _selectTime(true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTimeCard(
                  title: l10n.end,
                  time: _endTime,
                  icon: Icons.stop_circle_outlined,
                  onTap: () => _selectTime(false),
                  canClear: true,
                  onClear: () => setState(() => _endTime = null),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTimeCard({
    required String title,
    required DateTime? time,
    required IconData icon,
    required VoidCallback onTap,
    bool canClear = false,
    VoidCallback? onClear,
  }) {
    final l10n = AppLocalizations.of(context);
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainer.withOpacity(0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
                if (canClear && time != null) ...[
                  const Spacer(),
                  GestureDetector(
                    onTap: onClear,
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              time != null ? formatTime(time) : l10n.notSet,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: time != null
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.date,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                _selectDate();
              },
              icon: Icon(
                Icons.calendar_month,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: Text(
                'Custom',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                minimumSize: const Size(0, 0),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildHorizontalDateScroll(),
      ],
    );
  }

  Widget _buildHorizontalDateScroll() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final l10n = AppLocalizations.of(context);
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 30,
        itemBuilder: (context, index) {
          final date = today.add(Duration(days: index));
          final isSelected =
              _selectedDate.year == date.year &&
              _selectedDate.month == date.month &&
              _selectedDate.day == date.day;
          final isToday = index == 0;
          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedDate = date;
                _startTime = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  _startTime.hour,
                  _startTime.minute,
                );
                if (_endTime != null) {
                  _endTime = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    _endTime!.hour,
                    _endTime!.minute,
                  );
                }
              });
            },
            child: Container(
              width: 56,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.surfaceContainer.withOpacity(0.7),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.outline.withOpacity(0.2),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isToday)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      margin: const EdgeInsets.only(bottom: 3),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(
                                context,
                              ).colorScheme.onPrimary.withOpacity(0.2)
                            : Theme.of(
                                context,
                              ).colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        l10n.today,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  Text(
                    DateFormat('E').format(date).substring(0, 3),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    date.day.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(date),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: isSelected
                          ? Theme.of(
                              context,
                            ).colorScheme.onPrimary.withOpacity(0.8)
                          : Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildOptionsSection() {
    final l10n = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.options,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainer.withOpacity(0.3),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOptionButton(
                icon: Icons.repeat,
                label: l10n.repeat,
                isActive: _repeatDays.isNotEmpty,
                onPressed: () => _showRepeatDaysDialog(context),
                badge: _repeatDays.isNotEmpty
                    ? _repeatDays.length.toString()
                    : null,
              ),
              _buildOptionButton(
                icon: Icons.flag_outlined,
                label: l10n.priority,
                isActive: _importance != 0,
                color: _importance != 0
                    ? getImportanceColor(_importance)
                    : null,
                onPressed: () => _showPriorityDialog(context),
              ),
              _buildOptionButton(
                icon: getCategoryIcon(_category, context),
                label: l10n.category,
                isActive: _category.isNotEmpty,
                onPressed: () => _showCategoryDialog(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    Color? color,
    String? badge,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onPressed();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              children: [
                Icon(
                  icon,
                  size: 24,
                  color: isActive
                      ? (color ?? Theme.of(context).colorScheme.primary)
                      : Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.5),
                ),
                if (badge != null)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        badge,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: M3EButton.text(
            onPressed: _closeWithAnimation,
            size: M3EButtonSize.md,

            child: Text(
              l10n.cancel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        // ANTES: ElevatedButton
        Expanded(
          flex: 2,
          child: M3EButton(
            style: M3EButtonStyle.filled,
            onPressed: _saveEvent,
            child: Text(isEditing ? l10n.updateEvent : l10n.createEvent),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime(bool isStartTime) async {
  final currentTime = isStartTime ? _startTime : (_endTime ?? _startTime);
  final initialTime = M3ETime(
    hour: currentTime.hour,
    minute: currentTime.minute,
  );
  final time = await M3ETimePicker.show(
    context,
    initialTime: initialTime,
  );
  if (time != null) {
    setState(() {
      if (isStartTime) {
        _startTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          time.hour,
          time.minute,
        );
      } else {
        _endTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          time.hour,
          time.minute,
        );
      }
    });
  }
}

  Future<void> _selectDate() async {
    final date = await M3EDatePicker.show(
      context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
        _startTime = DateTime(
          date.year,
          date.month,
          date.day,
          _startTime.hour,
          _startTime.minute,
        );
        if (_endTime != null) {
          _endTime = DateTime(
            date.year,
            date.month,
            date.day,
            _endTime!.hour,
            _endTime!.minute,
          );
        }
      });
    }
  }

  void _saveEvent() {
    final l10n = AppLocalizations.of(context);

    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar(l10n.pleaseEnterTitle);
      return;
    }

    // FIX: was using l10n.endTime (a label) instead of the error message
    if (_endTime != null && _endTime!.isBefore(_startTime)) {
      _showErrorSnackBar(l10n.endTimeAfterStart);
      return;
    }

    try {
      final updatedEvent = Event(
        id:
            widget.event?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        startTime: _startTime,
        endTime: _endTime,
        repeatDays: _repeatDays,
        importance: _importance,
        // FIX: _category is already an English key — stored as-is
        category: _category,
        isCompleted: _isCompleted,
        userId: _userId,
      );

      widget.onAddEvent(updatedEvent);
      _closeWithAnimation();
    } catch (e) {
      _showErrorSnackBar('${l10n.errorSavingEvent}: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showRepeatDaysDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    List<int> tempRepeatDays = List<int>.from(_repeatDays);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Text(
                l10n.repeatDays,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              content: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(7, (index) {
                  final dayOfWeek = index + 1;
                  final isSelected = tempRepeatDays.contains(dayOfWeek);
                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      setDialogState(() {
                        if (isSelected) {
                          tempRepeatDays.remove(dayOfWeek);
                        } else {
                          tempRepeatDays.add(dayOfWeek);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                        ),
                      ),
                      child: Text(
                        getDayName(dayOfWeek).substring(0, 3),
                        style: TextStyle(
                          color: isSelected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() => _repeatDays = tempRepeatDays);
                    Navigator.pop(context);
                  },
                  child: Text(l10n.done),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPriorityDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l10n.priority,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPriorityOption(l10n.low, 1, Colors.green),
              _buildPriorityOption(l10n.moderate, 2, Colors.yellow),
              _buildPriorityOption(l10n.important, 3, Colors.orange),
              _buildPriorityOption(l10n.veryImportant, 4, Colors.red),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriorityOption(String title, int value, Color color) {
    final isSelected = _importance == value;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.flag, color: color, size: 16),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: color,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        trailing: isSelected ? Icon(Icons.check_circle, color: color) : null,
        onTap: () {
          setState(() => _importance = value);
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCategoryDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // FIX: categories use fixed English keys; display names are translated
    final categories = [
      {'key': CategoryKeys.school, 'icon': Icons.school, 'name': l10n.school},
      {'key': CategoryKeys.home, 'icon': Icons.home, 'name': l10n.home},
      {'key': CategoryKeys.work, 'icon': Icons.work, 'name': l10n.work},
      {
        'key': CategoryKeys.shopping,
        'icon': Icons.shopping_cart,
        'name': l10n.shopping,
      },
      {
        'key': CategoryKeys.health,
        'icon': Icons.health_and_safety,
        'name': l10n.health,
      },
      {
        'key': CategoryKeys.personal,
        'icon': Icons.person,
        'name': l10n.personal,
      },
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            l10n.category,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...categories.map(
                (cat) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      cat['icon'] as IconData,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    cat['name'] as String,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  // FIX: compare against the English key, not the translated name
                  trailing: _category == cat['key']
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    // FIX: store the English key
                    setState(() => _category = cat['key'] as String);
                    Navigator.pop(context);
                  },
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.clear, color: Colors.grey),
                ),
                title: Text(l10n.none),
                trailing: _category.isEmpty
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  setState(() => _category = '');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String getDayName(int dayOfWeek) {
    final l10n = AppLocalizations.of(context);
    switch (dayOfWeek) {
      case 1:
        return l10n.monday;
      case 2:
        return l10n.tuesday;
      case 3:
        return l10n.wednesday;
      case 4:
        return l10n.thursday;
      case 5:
        return l10n.friday;
      case 6:
        return l10n.saturday;
      case 7:
        return l10n.sunday;
      default:
        return '';
    }
  }

  String formatTime(DateTime dateTime) {
    return DateFormat.jm().format(dateTime);
  }
}

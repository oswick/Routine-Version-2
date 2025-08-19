import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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
  late String _category;
  late String _userId;

  // Animation controllers
  late AnimationController _slideController;
  late AnimationController _fadeController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // Para indicar si estamos editando un evento existente
  bool get isEditing => widget.event != null;

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
      // Modo edición - cargar datos del evento existente
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
      _category = event.category;
      _userId = event.userId;
    } else {
      // Modo creación - valores por defecto
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
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 20,
                  spreadRadius: 5,
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
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        const SizedBox(height: 24),
                        _buildMainFields(),
                        const SizedBox(height: 20),
                        _buildTimeSection(),
                        const SizedBox(height: 20),
                        _buildDateSection(),
                        const SizedBox(height: 24),
                        _buildOptionsSection(),
                        const SizedBox(height: 32),
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
    return Row(
      children: [
        // Handle bar
        Expanded(
          child: Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con título dinámico
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isEditing ? Icons.edit : Icons.add,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              isEditing ? AppLocalizations.of(context).editEvent : AppLocalizations.of(context).newEvent,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Campo de título
        _buildTextField(
          controller: _titleController,
          label: AppLocalizations.of(context).eventTitle,
          hint: AppLocalizations.of(context).whatNeedsToBeDone,
          icon: Icons.title_rounded,
          isRequired: true,
        ),
        const SizedBox(height: 16),

        // Campo de descripción
        _buildTextField(
          controller: _descriptionController,
          label: AppLocalizations.of(context).description,
          hint: AppLocalizations.of(context).addSomeDetails,
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.transparent, width: 2),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        textCapitalization: TextCapitalization.sentences,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Theme.of(context).colorScheme.onSurface,
        ),
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 16,
          ),
          labelStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            fontWeight: FontWeight.w500,
          ),
          hintStyle: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).time,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildTimeCard(
                title: AppLocalizations.of(context).start,
                time: _startTime,
                icon: Icons.play_circle_outline,
                onTap: () => _selectTime(true),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTimeCard(
                title: AppLocalizations.of(context).end,
                time: _endTime,
                icon: Icons.stop_circle_outlined,
                onTap: () => _selectTime(false),
                canClear: true,
                onClear: () {
                  setState(() {
                    _endTime = null;
                  });
                },
              ),
            ),
          ],
        ),
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
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(
            context,
          ).colorScheme.surfaceContainer.withOpacity(0.7),
          borderRadius: BorderRadius.circular(16),
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
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
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
                      size: 16,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.5),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              time != null ? formatTime(time) : AppLocalizations.of(context).notSet,
              style: TextStyle(
                fontSize: 16,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).date,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _selectDate();
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainer.withOpacity(0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
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
                    Icons.calendar_today,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context).selectedDate,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat.yMMMd().format(_selectedDate),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context).options,
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
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildOptionButton(
                icon: Icons.repeat,
                label: AppLocalizations.of(context).repeat,
                isActive: _repeatDays.isNotEmpty,
                onPressed: () => _showRepeatDaysDialog(context),
                badge: _repeatDays.isNotEmpty
                    ? _repeatDays.length.toString()
                    : null,
              ),
              _buildOptionButton(
                icon: Icons.flag_outlined,
                label: AppLocalizations.of(context).priority,
                isActive: _importance != 0,
                color: _importance != 0
                    ? getImportanceColor(_importance)
                    : null,
                onPressed: () => _showPriorityDialog(context),
              ),
              _buildOptionButton(
                icon: getCategoryIcon(_category),
                label: AppLocalizations.of(context).category,
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
          borderRadius: BorderRadius.circular(16),
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
    return Row(
      children: [
        Expanded(
          child: TextButton(
            onPressed: _closeWithAnimation,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              AppLocalizations.of(context).cancel,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: _saveEvent,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              isEditing ? AppLocalizations.of(context).updateEvent :AppLocalizations.of(context).createEvent,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _selectTime(bool isStartTime) async {
    final initialTime = TimeOfDay.fromDateTime(
      isStartTime ? _startTime : (_endTime ?? _startTime),
    );

    final time = await showTimePicker(
      context: context,
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
    final date = await showDatePicker(
      context: context,
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
    if (_titleController.text.trim().isEmpty) {
      _showErrorSnackBar(AppLocalizations.of(context).pleaseEnterTitle);
      return;
    }

    if (_endTime != null && _endTime!.isBefore(_startTime)) {
      _showErrorSnackBar(AppLocalizations.of(context).endTime
      );
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
        category: _category,
        isCompleted: _isCompleted,
        userId: _userId,
      );

      widget.onAddEvent(updatedEvent);
      _closeWithAnimation();
    } catch (e) {
      _showErrorSnackBar('Error saving event: $e');
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
                AppLocalizations.of(context).repeatDays,
                style: TextStyle(fontWeight: FontWeight.w600),
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
                  child: Text(AppLocalizations.of(context).cancel,),
                ),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      _repeatDays = tempRepeatDays;
                    });
                    Navigator.pop(context);
                  },
                  child: Text(AppLocalizations.of(context).done,),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPriorityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            AppLocalizations.of(context).priority,
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPriorityOption(AppLocalizations.of(context).low, 1, Colors.green),
              _buildPriorityOption(AppLocalizations.of(context).moderate, 2, Colors.yellow),
              _buildPriorityOption(AppLocalizations.of(context).important, 3, Colors.orange),
              _buildPriorityOption(AppLocalizations.of(context).veryImportant, 4, Colors.red),
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
          setState(() {
            _importance = value;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  void _showCategoryDialog(BuildContext context) {
    final categories = [
      {'name': AppLocalizations.of(context).school, 'icon': Icons.school},
      {'name': AppLocalizations.of(context).home, 'icon': Icons.home},
      {'name': AppLocalizations.of(context).work, 'icon': Icons.work},
      {'name': AppLocalizations.of(context).shopping, 'icon': Icons.shopping_cart},
      {'name': AppLocalizations.of(context).health, 'icon': Icons.health_and_safety},
      {'name': AppLocalizations.of(context).personal, 'icon': Icons.person},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            AppLocalizations.of(context).category,
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
                (category) => ListTile(
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
                      category['icon'] as IconData,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  title: Text(
                    category['name'] as String,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  trailing: _category == category['name']
                      ? Icon(
                          Icons.check,
                          color: Theme.of(context).colorScheme.primary,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _category = category['name'] as String;
                    });
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
                title: Text(AppLocalizations.of(context).none),
                trailing: _category.isEmpty
                    ? Icon(
                        Icons.check,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : null,
                onTap: () {
                  setState(() {
                    _category = '';
                  });
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
    switch (dayOfWeek) {
      case 1:
        return AppLocalizations.of(context).monday;
      case 2:
        return AppLocalizations.of(context).tuesday;
      case 3:
        return AppLocalizations.of(context).wednesday;
      case 4:
        return AppLocalizations.of(context).thursday;
      case 5:
        return AppLocalizations.of(context).friday;
      case 6:
        return AppLocalizations.of(context).saturday;
      case 7:
        return AppLocalizations.of(context).sunday;
      default:
        return '';
    }
  }

  String formatTime(DateTime dateTime) {
    return DateFormat.jm().format(dateTime);
  }
}

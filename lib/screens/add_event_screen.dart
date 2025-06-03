import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
  // ignore: library_private_types_in_public_api
  _AddEventBottomSheetState createState() => _AddEventBottomSheetState();
}

class _AddEventBottomSheetState extends State<AddEventBottomSheet> {
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

  // Para indicar si estamos editando un evento existente
  bool get isEditing => widget.event != null;

  @override
  void initState() {
    super.initState();
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
      _repeatDays = List<int>.from(event.repeatDays); // Crear una copia
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
      _userId = ''; // Se asignará en el HomeScreen
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQueryData = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: mediaQueryData.viewInsets.bottom),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con título dinámico
              Row(
                children: [
                  Icon(
                    isEditing ? Icons.edit : Icons.add,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isEditing ? 'Edit Event' : 'Add Event',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Campos del formulario
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.title),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              
              TextField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (Optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.description),
                ),
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              
              // Tiempos
              Row(
                children: [
                  Expanded(
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.access_time),
                        title: const Text('Start Time'),
                        subtitle: Text(formatTime(_startTime)),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_startTime),
                          );
                          if (time != null) {
                            setState(() {
                              _startTime = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Card(
                      child: ListTile(
                        leading: const Icon(Icons.access_time_filled),
                        title: const Text('End Time'),
                        subtitle: _endTime != null
                            ? Text(formatTime(_endTime!))
                            : const Text('Not set'),
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(
                              _endTime ?? _startTime,
                            ),
                          );
                          if (time != null) {
                            setState(() {
                              _endTime = DateTime(
                                _selectedDate.year,
                                _selectedDate.month,
                                _selectedDate.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        },
                        trailing: _endTime != null
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  setState(() {
                                    _endTime = null;
                                  });
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Fecha
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('Date'),
                  subtitle: Text(DateFormat.yMMMd().format(_selectedDate)),
                  onTap: () async {
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
                  },
                ),
              ),
              const SizedBox(height: 16),
              
              // Opciones adicionales
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildOptionButton(
                      icon: Icons.event_repeat,
                      label: 'Repeat',
                      isActive: _repeatDays.isNotEmpty,
                      onPressed: () => _showRepeatDaysDialog(context),
                    ),
                    _buildOptionButton(
                      icon: Icons.priority_high,
                      label: 'Priority',
                      isActive: _importance != 0,
                      color: _importance != 0 ? getImportanceColor(_importance) : null,
                      onPressed: () => _showPriorityDialog(context),
                    ),
                    _buildOptionButton(
                      icon: getCategoryIcon(_category),
                      label: 'Category',
                      isActive: _category.isNotEmpty,
                      onPressed: () => _showCategoryDialog(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Botones de acción
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveEvent,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: Text(isEditing ? 'Update' : 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
    Color? color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            icon,
            color: isActive 
                ? (color ?? Theme.of(context).colorScheme.primary)
                : Colors.grey,
          ),
          onPressed: onPressed,
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive 
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
          ),
        ),
      ],
    );
  }

  void _saveEvent() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title for the event'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar que la hora de fin sea posterior a la de inicio
    if (_endTime != null && _endTime!.isBefore(_startTime)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be after start time'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      final updatedEvent = Event(
        id: widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
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
      Navigator.pop(context);

      // Mostrar confirmación
     
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving event: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRepeatDaysDialog(BuildContext context) {
    List<int> tempRepeatDays = List<int>.from(_repeatDays);
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Repeat Days'),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              content: Wrap(
                children: List.generate(7, (index) {
                  final dayOfWeek = index + 1;
                  final isSelected = tempRepeatDays.contains(dayOfWeek);
                  return GestureDetector(
                    onTap: () {
                      setDialogState(() {
                        if (isSelected) {
                          tempRepeatDays.remove(dayOfWeek);
                        } else {
                          tempRepeatDays.add(dayOfWeek);
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4.0),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.primary
                              : Colors.grey,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        getDayName(dayOfWeek).substring(0, 3),
                        style: TextStyle(
                          color: isSelected 
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _repeatDays = tempRepeatDays;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
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
          title: const Text('Priority Level'),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildPriorityOption('Low', 1, Colors.green),
              _buildPriorityOption('Moderate', 2, Colors.yellow),
              _buildPriorityOption('Important', 3, Colors.orange),
              _buildPriorityOption('Very Important', 4, Colors.red),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriorityOption(String title, int value, Color color) {
    return ListTile(
      leading: Icon(Icons.circle, color: color),
      title: Text(title, style: TextStyle(color: color)),
      trailing: _importance == value ? const Icon(Icons.check) : null,
      onTap: () {
        setState(() {
          _importance = value;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showCategoryDialog(BuildContext context) {
    final categories = [
      {'name': 'School', 'icon': Icons.school},
      {'name': 'Home', 'icon': Icons.home},
      {'name': 'Work', 'icon': Icons.work},
      {'name': 'Shopping', 'icon': Icons.shopping_cart},
      {'name': 'Health', 'icon': Icons.health_and_safety},
      {'name': 'Personal', 'icon': Icons.person},
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Category'),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...categories.map((category) => ListTile(
                leading: Icon(category['icon'] as IconData),
                title: Text(category['name'] as String),
                trailing: _category == category['name'] ? const Icon(Icons.check) : null,
                onTap: () {
                  setState(() {
                    _category = category['name'] as String;
                  });
                  Navigator.pop(context);
                },
              )),
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('None'),
                trailing: _category.isEmpty ? const Icon(Icons.check) : null,
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
      case 1: return 'Monday';
      case 2: return 'Tuesday';
      case 3: return 'Wednesday';
      case 4: return 'Thursday';
      case 5: return 'Friday';
      case 6: return 'Saturday';
      case 7: return 'Sunday';
      default: return '';
    }
  }

  String formatTime(DateTime dateTime) {
    return DateFormat.jm().format(dateTime);
  }
}
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
  DateTime? _endTime; // Agregar endTime como opcional
  late List<int> _repeatDays;
  late int _importance;
  late bool _isCompleted;
  late String _category;

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController = TextEditingController(text: widget.event!.title);
      _descriptionController = TextEditingController(
        text: widget.event!.description ?? '',
      );
      _startTime = widget.event!.startTime;
      _endTime = widget.event!.endTime; // Inicializar endTime
      _selectedDate = widget.event!.startTime;
      _repeatDays = widget.event!.repeatDays;
      _importance = widget.event!.importance ?? 0;
      _isCompleted = widget.event!.isCompleted;
      _category = widget.event!.category;
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
      _endTime = null; // Inicializar endTime como null
      _selectedDate = widget.day;
      _repeatDays = [];
      _importance = 0;
      _isCompleted = false;
      _category = '';
    }
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
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
              ),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
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
                  Expanded(
                    child: ListTile(
                      title: const Text('End Time'),
                      subtitle:
                          _endTime != null
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
                    ),
                  ),
                ],
              ),
              ListTile(
                title: const Text('Date'),
                subtitle: Text(_selectedDate.toString().split(' ')[0]),
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
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.event_repeat,
                        color:
                            _repeatDays.isNotEmpty
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                      ),
                      onPressed: () {
                        _showRepeatDaysDialog(context);
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        Icons.priority_high,
                        color:
                            _importance != 0
                                ? getImportanceColor(_importance)
                                : Theme.of(context).colorScheme.onSurface,
                      ),
                      onPressed: () {
                        _showPriorityDialog(context);
                      },
                    ),
                    IconButton(
                      icon: Icon(
                        getCategoryIcon(_category),
                        color:
                            _category.isNotEmpty
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                      ),
                      onPressed: () {
                        _showCategoryDialog(context);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      if (_titleController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Title cannot be empty'),
                          ),
                        );
                      } else {
                        final updatedEvent = Event(
                          id:
                              widget.event?.id ??
                              DateTime.now().millisecondsSinceEpoch.toString(),
                          title: _titleController.text,
                          description:
                              _descriptionController.text.isNotEmpty
                                  ? _descriptionController.text
                                  : null,
                          startTime: _startTime,
                          endTime: _endTime,
                          repeatDays: _repeatDays,
                          importance: _importance,
                          category: _category,
                          isCompleted: _isCompleted,
                        );
                        widget.onAddEvent(updatedEvent);
                        Navigator.pop(context);
                      }
                    },
                    style: TextButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRepeatDaysDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final theme = Theme.of(context);
            final selectedColor =
                theme.brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black;
            final unselectedColor =
                theme.brightness == Brightness.dark
                    ? Colors.grey[700]
                    : Colors.grey[700];

            return AlertDialog(
              title: const Text('Repeat Days'),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
              content: Wrap(
                children: List.generate(7, (index) {
                  final dayOfWeek = index + 1;
                  final isSelected = _repeatDays.contains(dayOfWeek);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _repeatDays.remove(dayOfWeek);
                        } else {
                          _repeatDays.add(dayOfWeek);
                        }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.all(4.0),
                      padding: const EdgeInsets.all(4.0),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? selectedColor : unselectedColor!,
                        ),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(
                        getDayName(dayOfWeek),
                        style: TextStyle(
                          color: isSelected ? selectedColor : unselectedColor,
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
          title: const Text('Priority'),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('Low', style: TextStyle(color: Colors.green)),
                onTap: () {
                  setState(() {
                    _importance = 1;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text(
                  'Moderate',
                  style: TextStyle(color: Colors.yellow),
                ),
                onTap: () {
                  setState(() {
                    _importance = 2;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text(
                  'Important',
                  style: TextStyle(color: Colors.orange),
                ),
                onTap: () {
                  setState(() {
                    _importance = 3;
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: const Text(
                  'Very Important',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  setState(() {
                    _importance = 4;
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

  void _showCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Category'),
          backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('School'),
                onTap: () {
                  setState(() {
                    _category = 'School';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.home),
                title: const Text('Home'),
                onTap: () {
                  setState(() {
                    _category = 'Home';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.work),
                title: const Text('Work'),
                onTap: () {
                  setState(() {
                    _category = 'Work';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: const Text('Shopping'),
                onTap: () {
                  setState(() {
                    _category = 'Shopping';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('None'),
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
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return '';
    }
  }

  String formatTime(DateTime dateTime) {
    return DateFormat.jm().format(dateTime);
  }
}

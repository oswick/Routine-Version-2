import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Import the intl package
import '../models/event.dart';
import '../utils/event_utils.dart'; // Import the utility file

class AddEventBottomSheet extends StatefulWidget {
  final Function(Event) onAddEvent;
  final DateTime day;
  final Event? event;

  const AddEventBottomSheet({super.key, required this.onAddEvent, required this.day, this.event});

  @override
  // ignore: library_private_types_in_public_api
  _AddEventBottomSheetState createState() => _AddEventBottomSheetState();
}

class _AddEventBottomSheetState extends State<AddEventBottomSheet> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _startTime;
  late DateTime _selectedDate;
  late List<int> _repeatDays;
  late int _importance;
  late bool _isCompleted;
  late String _category; // New field for category

  @override
  void initState() {
    super.initState();
    if (widget.event != null) {
      _titleController = TextEditingController(text: widget.event!.title);
      _descriptionController = TextEditingController(text: widget.event!.description ?? '');
      _startTime = widget.event!.startTime;
      _selectedDate = widget.event!.startTime;
      _repeatDays = widget.event!.repeatDays;
      _importance = widget.event!.importance ?? 0;
      _isCompleted = widget.event!.isCompleted;
      _category = widget.event!.category; // New field for category
    } else {
      _titleController = TextEditingController();
      _descriptionController = TextEditingController();
      _startTime = DateTime(widget.day.year, widget.day.month, widget.day.day, DateTime.now().hour, DateTime.now().minute);
      _selectedDate = widget.day;
      _repeatDays = [];
      _importance = 0;
      _isCompleted = false;
      _category = ''; // Default category is empty
    }
  }

  @override
  Widget build(BuildContext context) {
    final MediaQueryData mediaQueryData = MediaQuery.of(context); // solution step 1

    return Padding(
      padding: EdgeInsets.only(
        bottom: mediaQueryData.viewInsets.bottom, // solution step 2
      ),
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
              ListTile(
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
                    });
                  }
                },
              ),
              ListTile(
                title: const Text('Repeat'),
                trailing: const Icon(Icons.event_repeat),
                onTap: () {
                  _showRepeatDaysDialog(context);
                },
              ),
              const SizedBox(height: 5),
              const Text('Priority'),
              const  SizedBox(height: 5),
              PopupMenuButton<int>(
                color: Theme.of(context).colorScheme.surfaceContainer,
                initialValue: _importance,
                onSelected: (value) {
                  setState(() {
                    _importance = value;
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 1,
                    child: Text('Low', style: TextStyle(color: Colors.green)),
                  ),
                  const PopupMenuItem(
                    value: 2,
                    child: Text('Moderate', style: TextStyle(color: Colors.yellow)),
                  ),
                  const PopupMenuItem(
                    value: 3,
                    child: Text('Important', style: TextStyle(color: Colors.orange)),
                  ),
                  const PopupMenuItem(
                    value: 4,
                    child: Text('Very Important', style: TextStyle(color: Colors.red)),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.all(8.0),
                  decoration: BoxDecoration(
                    color: getImportanceColor(_importance),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Text(
                    getImportanceText(_importance),
                  ),
                ),
              ),
              const SizedBox(height: 5),
              const Text('Category'),
              const SizedBox(height: 5),
              PopupMenuButton<String>(
                color: Theme.of(context).colorScheme.surfaceContainer,
                initialValue: _category,
                onSelected: (value) {
                  setState(() {
                    _category = value;
                  });
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'School',
                    child: Row(
                      children: [
                        Icon(Icons.school),
                        SizedBox(width: 5),
                        Text('School'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'Home',
                    child: Row(
                      children: [
                        Icon(Icons.home),
                        SizedBox(width: 5),
                        Text('Home'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'Work',
                    child: Row(
                      children: [
                        Icon(Icons.work),
                        SizedBox(width: 5),
                        Text('Work'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'Shopping',
                    child: Row(
                      children: [
                        Icon(Icons.shopping_cart),
                        SizedBox(width: 5),
                        Text('Shopping'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: '',
                    child: Row(
                      children: [
                        Icon(Icons.close),
                        SizedBox(width: 5),
                        Text('None'),
                      ],
                    ),
                  ),
                ],
                child: Container(
                  decoration: BoxDecoration(
                    color: getCategoryColor(_category),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: Row(
                    children: [
                      if (_category.isNotEmpty) // Show icon only if category is not empty
                        Icon(getCategoryIcon(_category)),
                      const SizedBox(width: 5),
                      Text(
                        _category.isNotEmpty ? _category : 'None',
                      ),
                    ],
                  ),
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
                          id: widget.event?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                          title: _titleController.text,
                          description: _descriptionController.text.isNotEmpty ? _descriptionController.text : null,
                          startTime: _startTime,
                          repeatDays: _repeatDays,
                          importance: _importance,
                          category: _category, // New field for category
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
                            Theme.of(context).colorScheme.onSecondaryContainer),
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
            final selectedColor = theme.brightness == Brightness.dark ? Colors.white : Colors.black;
            final unselectedColor = theme.brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[700];

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
                        border: Border.all(color: isSelected ? selectedColor : unselectedColor!),
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      child: Text(getDayName(dayOfWeek), style: TextStyle(color: isSelected ? selectedColor : unselectedColor)),
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
    // Use DateFormat to format the time according to the device's locale settings
    return DateFormat.jm().format(dateTime);
  }
}

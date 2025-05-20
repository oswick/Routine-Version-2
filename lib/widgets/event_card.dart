import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/models/event.dart';
import 'package:myapp/screens/add_event_screen.dart';
import 'package:myapp/utils/event_utils.dart';

class EventCard extends StatefulWidget {
  final Event event;
  final Function(Event) onUpdateEvent;

  const EventCard({
    super.key,
    required this.event,
    required this.onUpdateEvent,
  });

  @override
  // ignore: library_private_types_in_public_api
  _EventCardState createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  late bool isCompleted;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    isCompleted = widget.event.isCompleted;
    _loadCompletedStatus();
    _checkAndResetCompletedStatus();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> _loadCompletedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final completedStatus =
        prefs.getBool('event_${widget.event.id}_completed') ?? false;
    setState(() {
      isCompleted = completedStatus;
    });
  }

  Future<void> _saveCompletedStatus(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('event_${widget.event.id}_completed', completed);
  }

  double _calculateProgress() {
    if (widget.event.endTime == null) {
      return 0.0;
    }

    final now = DateTime.now();
    final startTime = widget.event.startTime;
    final endTime = widget.event.endTime!;

    if (now.isBefore(startTime)) {
      return 0.0;
    }

    if (now.isAfter(endTime)) {
      return 1.0;
    }

    final totalDuration = endTime.difference(startTime).inSeconds;
    final elapsedDuration = now.difference(startTime).inSeconds;

    return elapsedDuration / totalDuration;
  }

  bool _shouldShowProgressIndicator() {
    final now = DateTime.now();
    final hasEndTime = widget.event.endTime != null;
    
    if (!hasEndTime) {
      return false;
    }
    
    // Solo mostrar el indicador si el evento ha comenzado pero no ha terminado
    return now.isAfter(widget.event.startTime) && now.isBefore(widget.event.endTime!);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showEventDetails(context);
      },
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 0,
        child: Opacity(
          opacity: isCompleted ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    if (widget.event.importance != null)
                      Container(
                        width: 5,
                        height: 20,
                        decoration: BoxDecoration(
                          color: getImportanceColor(widget.event.importance!),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    const SizedBox(width: 5),
                    if (widget.event.category.isNotEmpty)
                      Icon(getCategoryIcon(widget.event.category), size: 16),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  widget.event.title,
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              Text(
                                formatTime(widget.event.startTime),
                                style: const TextStyle(fontSize: 10),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Tooltip(
                      message:
                          isCompleted
                              ? "Mark as incomplete"
                              : "Mark as complete",
                      child: Checkbox(
                        shape: const CircleBorder(),
                        value: isCompleted,
                        onChanged: (value) {
                          setState(() {
                            isCompleted = value!;
                            final updatedEvent = widget.event.copyWith(
                              isCompleted: isCompleted,
                            );
                            widget.onUpdateEvent(updatedEvent);
                          });
                        },
                      ),
                    ),
                  ],
                ),
                if (_shouldShowProgressIndicator())
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: LinearProgressIndicator(
                      value: _calculateProgress(),
                      minHeight: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showEventDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return AddEventBottomSheet(
          event: widget.event,
          onAddEvent: (updatedEvent) {
            widget.onUpdateEvent(updatedEvent);
          },
          day: widget.event.startTime,
        );
      },
    );
  }

  void _updateCompletedStatus(bool value) {
    setState(() {
      isCompleted = value;
      final updatedEvent = widget.event.copyWith(isCompleted: isCompleted);
      widget.onUpdateEvent(updatedEvent);
      _saveCompletedStatus(isCompleted);
    });
  }

  void _checkAndResetCompletedStatus() {
    final now = DateTime.now();
    final eventDate = DateTime(
      now.year,
      now.month,
      now.day,
      widget.event.startTime.hour,
      widget.event.startTime.minute,
    );

    if (now.isAfter(eventDate) &&
        widget.event.repeatDays.isNotEmpty &&
        widget.event.isCompleted) {
      _updateCompletedStatus(false);
    }
  }

  String formatTime(DateTime dateTime) {
    return DateFormat.jm().format(dateTime);
  }
}
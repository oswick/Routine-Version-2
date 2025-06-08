import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/screens/pomodoro_screen.dart';
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
    _checkAndUpdateCompletedStatus();
    _startTimer();
  }

  @override
  void didUpdateWidget(EventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Verificar si el evento fue editado y si necesita ser desmarcado
    if (oldWidget.event.endTime != widget.event.endTime ||
        oldWidget.event.startTime != widget.event.startTime) {
      _checkAndUpdateCompletedStatus();
    }
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
    return now.isAfter(widget.event.startTime) &&
        now.isBefore(widget.event.endTime!);
  }

  // Método mejorado que maneja tanto el marcado automático como el desmarcado
  void _checkAndUpdateCompletedStatus() {
    final now = DateTime.now();
    final hasEndTime = widget.event.endTime != null;
    
    if (hasEndTime) {
      final hasEnded = now.isAfter(widget.event.endTime!);
      final isCurrentlyInProgress = now.isAfter(widget.event.startTime) && 
                                   now.isBefore(widget.event.endTime!);
      
      // Si el evento ha terminado y no está marcado, marcarlo automáticamente
      if (hasEnded && !isCompleted) {
        _updateCompletedStatus(true);
      }
      // Si el evento está marcado como completado pero aún está en progreso o no ha comenzado,
      // desmarcarlo automáticamente (esto maneja el caso de extensión de tiempo)
      else if (isCompleted && (isCurrentlyInProgress || now.isBefore(widget.event.startTime))) {
        _updateCompletedStatus(false);
      }
    }

    // Lógica para eventos repetitivos
    if (widget.event.repeatDays.isNotEmpty && widget.event.isCompleted) {
      final eventDate = DateTime(
        now.year,
        now.month,
        now.day,
        widget.event.startTime.hour,
        widget.event.startTime.minute,
      );

      if (now.isAfter(eventDate)) {
        _updateCompletedStatus(false);
      }
    }
  }

@override
Widget build(BuildContext context) {
  // Verificar el estado de completado en cada build
  _checkAndUpdateCompletedStatus();

  return GestureDetector(
    onTap: () {
      _showEventDetails(context);
    },
    child: Card(
      color: Theme.of(context).colorScheme.surfaceContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Opacity(
        opacity: isCompleted ? 0.6 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  if (widget.event.importance != null)
                    Container(
                      width: 4,
                      height: 40,
                      decoration: BoxDecoration(
                        color: getImportanceColor(widget.event.importance!),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  const SizedBox(width: 12),
                  if (widget.event.category.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        getCategoryIcon(widget.event.category),
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.event.title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ),
                            Text(
                              formatTime(widget.event.startTime),
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (widget.event.endTime != null && !isCompleted)
                    IconButton(
                      icon: Icon(
                        Icons.timer,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PomodoroScreen(event: widget.event),
                          ),
                        );
                      },
                    ),
                  Tooltip(
                    message: isCompleted ? "Mark as incomplete" : "Mark as complete",
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
                  child: Column(
                    children: [
                      LinearProgressIndicator(
                        value: _calculateProgress(),
                        minHeight: 4,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            formatTime(widget.event.startTime),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                          Text(
                            formatTime(widget.event.endTime!),
                            style: TextStyle(
                              fontSize: 10,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ],
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

  String formatTime(DateTime dateTime) {
    return DateFormat.jm().format(dateTime);
  }
}
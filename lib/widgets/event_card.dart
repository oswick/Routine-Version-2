import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/screens/pomodoro_screen.dart';
import 'package:myapp/services/statistics_service.dart';
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
    // Reducir la frecuencia de actualización a cada minuto en lugar de cada segundo
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _checkAndUpdateCompletedStatus();
      }
    });
  }

  Future<void> _loadCompletedStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'event_${widget.event.id}_${_getDateKey()}';
    final completedStatus = prefs.getBool(key) ?? widget.event.isCompleted;

    if (mounted) {
      setState(() {
        isCompleted = completedStatus;
      });
    }
  }

  String _getDateKey() {
    // Crear una clave única para cada día
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  Future<void> _saveCompletedStatus(bool completed) async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'event_${widget.event.id}_${_getDateKey()}';
    await prefs.setBool(key, completed);
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

  void _checkAndUpdateCompletedStatus() {
    final now = DateTime.now();
    final hasEndTime = widget.event.endTime != null;

    // Si el evento es repetitivo, verificar si estamos en un nuevo día
    if (widget.event.repeatDays.isNotEmpty) {
      final today = DateTime(now.year, now.month, now.day);
      final eventDate = DateTime(
        widget.event.startTime.year,
        widget.event.startTime.month,
        widget.event.startTime.day,
      );

      // Si estamos en un nuevo día y el evento debe repetirse hoy
      if (!today.isAtSameMomentAs(eventDate) &&
          widget.event.repeatDays.contains(now.weekday)) {
        // Cargar el estado completado para el día actual
        _loadCompletedStatus();
        return;
      }
    }
    if (hasEndTime) {
      final hasEnded = now.isAfter(widget.event.endTime!);
      final isCurrentlyInProgress =
          now.isAfter(widget.event.startTime) &&
          now.isBefore(widget.event.endTime!);

      if (hasEnded && !isCompleted) {
        _updateCompletedStatus(true);
      } else if (isCompleted && isCurrentlyInProgress) {
        // Solo desmarcar si el evento está en progreso
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                          color: Theme.of(
                            context,
                          ).colorScheme.primary.withOpacity(0.1),
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                formatTime(widget.event.startTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.6),
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
                              builder: (context) =>
                                  PomodoroScreen(event: widget.event),
                            ),
                          );
                        },
                      ),
                    Tooltip(
                      message: isCompleted
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
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _calculateProgress(),
                          minHeight: 4,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
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
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                            Text(
                              formatTime(widget.event.endTime!),
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
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
    if (mounted) {
      setState(() {
        isCompleted = value;
        final updatedEvent = widget.event.copyWith(isCompleted: value);
        widget.onUpdateEvent(updatedEvent);
        _saveCompletedStatus(value);

        // Record event statistics
        StatisticsService().recordEventCompletion(
          updatedEvent,
          value,
          value ? DateTime.now() : null,
        );
      });
    }
  }

  String formatTime(DateTime dateTime) {
    return DateFormat.jm().format(dateTime);
  }
}

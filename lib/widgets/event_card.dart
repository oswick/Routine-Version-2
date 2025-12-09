// lib/widgets/event_card.dart - VERSIÓN ACTUALIZADA CON EVENT PREVIEW SHEET
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/screens/pomodoro_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/models/event.dart';
import 'package:myapp/screens/add_event_screen.dart';
import 'package:myapp/utils/event_utils.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/widgets/event_preview_sheet.dart'; // 🆕 NUEVO IMPORT

class EventCard extends StatefulWidget {
  final Event event;
  final Function(Event) onUpdateEvent;
  final bool pastEvent;

  const EventCard({
    super.key,
    required this.event,
    required this.onUpdateEvent,
    this.pastEvent = false,
  });

  @override
  _EventCardState createState() => _EventCardState();
}

class _EventCardState extends State<EventCard> {
  late bool isCompleted;
  String? _currentDateKey;

  @override
  void initState() {
    super.initState();
    _currentDateKey = _getDateKey();
    _loadCompletedStatus();
  }

  @override
  void didUpdateWidget(EventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newDateKey = _getDateKey();
    if (_currentDateKey != newDateKey) {
      _currentDateKey = newDateKey;
      _loadCompletedStatus();
    }
    
    if (oldWidget.event.isCompleted != widget.event.isCompleted) {
      isCompleted = widget.event.isCompleted;
    }
  }

  Future<void> _loadCompletedStatus() async {
    if (_isRepetitiveEvent()) {
      final provider = Provider.of<EventProvider>(context, listen: false);
      if (mounted) {
        setState(() {
          isCompleted = provider.getEventCompletion(
            widget.event.id, 
            DateTime.now()
          );
        });
      }
    } else {
      if (mounted) {
        setState(() {
          isCompleted = widget.event.isCompleted;
        });
      }
    }
  }

  String _getDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _isRepetitiveEvent() {
    return widget.event.repeatDays.isNotEmpty;
  }

  Future<void> _saveCompletedStatus(bool completed) async {
    if (_isRepetitiveEvent()) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'event_${widget.event.id}_completion_$_currentDateKey';
      await prefs.setBool(key, completed);
      
      // Actualizar cache del provider
      final provider = Provider.of<EventProvider>(context, listen: false);
      provider.updateEventCompletion(widget.event, completed, DateTime.now());
      
      _cleanOldCompletionStates();
    } else {
      final updatedEvent = widget.event.copyWith(isCompleted: completed);
      widget.onUpdateEvent(updatedEvent);
    }
  }

  Future<void> _cleanOldCompletionStates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final now = DateTime.now();
      final cutoffDate = now.subtract(const Duration(days: 30));

      final keysToRemove = keys.where((key) {
        if (key.startsWith('event_${widget.event.id}_completion_')) {
          final dateStr = key.split('_').last;
          try {
            final date = DateTime.parse(dateStr);
            return date.isBefore(cutoffDate);
          } catch (e) {
            return false;
          }
        }
        return false;
      }).toList();

      for (String key in keysToRemove) {
        await prefs.remove(key);
      }
    } catch (e) {
      debugPrint('Error cleaning old completion states: $e');
    }
  }

  bool _shouldShowProgressIndicator() {
    final now = DateTime.now();
    if (widget.event.endTime == null) return false;

    if (_isRepetitiveEvent()) {
      final today = now.weekday;
      if (!widget.event.repeatDays.contains(today)) return false;

      final todayStart = DateTime(
        now.year, now.month, now.day,
        widget.event.startTime.hour, widget.event.startTime.minute,
      );
      final todayEnd = DateTime(
        now.year, now.month, now.day,
        widget.event.endTime!.hour, widget.event.endTime!.minute,
      );

      return now.isAfter(todayStart) && now.isBefore(todayEnd);
    } else {
      return now.isAfter(widget.event.startTime) &&
          now.isBefore(widget.event.endTime!);
    }
  }

  void _updateCompletedStatus(bool value) {
    if (mounted) {
      setState(() {
        isCompleted = value;
        _saveCompletedStatus(value);

        if (!_isRepetitiveEvent()) {
          final updatedEvent = widget.event.copyWith(isCompleted: value);
          widget.onUpdateEvent(updatedEvent);
        }
      });
    }
  }

  Widget _buildCompletionIndicator() {
    if (_isRepetitiveEvent()) {
      return Tooltip(
        message: isCompleted
            ? AppLocalizations.of(context).markAsIncomplete
            : AppLocalizations.of(context).markAsComplete,
        child: Checkbox(
          shape: const CircleBorder(),
          value: isCompleted,
          onChanged: (value) => _updateCompletedStatus(value!),
        ),
      );
    } else {
      return Tooltip(
        message: isCompleted
            ? AppLocalizations.of(context).markAsIncomplete
            : AppLocalizations.of(context).markAsComplete,
        child: Checkbox(
          shape: const CircleBorder(),
          value: isCompleted,
          onChanged: (value) => _updateCompletedStatus(value!),
        ),
      );
    }
  }

  Widget _buildStatusIndicator() {
    if (widget.pastEvent) {
      if (isCompleted) {
        return Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 16),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context).accomplished,
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
          ],
        );
      } else {
        return Row(
          children: [
            Icon(Icons.history, color: Colors.grey, size: 16),
            const SizedBox(width: 4),
            Text(
              AppLocalizations.of(context).notAccomplished,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        );
      }
    }

    if (_isRepetitiveEvent()) {
      return Row(
        children: [
          Icon(
            Icons.repeat,
            color: Theme.of(context).colorScheme.primary,
            size: 16,
          ),
          const SizedBox(width: 4),
          Text(
            _getRepeatDaysText(),
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  String _getRepeatDaysText() {
    final dayNames = [
      '',
      AppLocalizations.of(context).mon,
      AppLocalizations.of(context).tue,
      AppLocalizations.of(context).wed,
      AppLocalizations.of(context).thu,
      AppLocalizations.of(context).fri,
      AppLocalizations.of(context).sat,
      AppLocalizations.of(context).sun,
    ];
    final days = widget.event.repeatDays.map((day) => dayNames[day]).join(', ');
    return days;
  }

  @override
  Widget build(BuildContext context) {
    bool isPast = widget.pastEvent;
    double cardOpacity = isPast ? 0.5 : (isCompleted ? 0.6 : 1.0);

    return Consumer<EventProvider>(
      builder: (context, provider, child) {
        final progress = provider.getEventProgress(widget.event.id);
        final showProgress = _shouldShowProgressIndicator();

        return GestureDetector(
          onTap: () => _showEventPreview(context), // 🆕 CAMBIO AQUÍ
          child: Card(
            color: Theme.of(context).colorScheme.surfaceContainer,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)
            ),
            child: Opacity(
              opacity: cardOpacity,
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
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              getCategoryIcon(widget.event.category, context),
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    formatTime(widget.event.startTime),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              _buildStatusIndicator(),
                            ],
                          ),
                        ),
                        if (widget.event.endTime != null && 
                            !isCompleted && 
                            !isPast)
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
                        _buildCompletionIndicator(),
                      ],
                    ),
                    
                    if (showProgress)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          children: [
                            LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(2),
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainer,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  formatTime(widget.event.endTime!),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.5),
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
      },
    );
  }

  // 🆕 NUEVO MÉTODO - Muestra el preview sheet primero
  void _showEventPreview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return EventPreviewSheet(
          event: widget.event,
          onEdit: () {
            // Abrir pantalla de edición después de cerrar el preview
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
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
          },
          onDelete: () {
            // El delete se maneja dentro del EventPreviewSheet
          },
        );
      },
    );
  }

  String formatTime(DateTime dateTime) {
    return DateFormat.jm().format(dateTime);
  }
}
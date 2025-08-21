import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/screens/pomodoro_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:myapp/models/event.dart';
import 'package:myapp/screens/add_event_screen.dart';
import 'package:myapp/utils/event_utils.dart';

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
  Timer? _timer;
  Timer? _progressTimer; // Timer separado para el progreso
  String? _currentDateKey;
  double _currentProgress = 0.0; // Cache del progreso actual

  @override
  void initState() {
    super.initState();
    _currentDateKey = _getDateKey();
    isCompleted = widget.event.isCompleted;
    _loadCompletedStatus();
    _checkAndUpdateCompletedStatus();
    _startTimers();
  }

  @override
  void didUpdateWidget(EventCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Verificar si cambió el día
    final newDateKey = _getDateKey();
    if (_currentDateKey != newDateKey) {
      _currentDateKey = newDateKey;
      _loadCompletedStatus(); // Recargar el estado para el nuevo día
    }
    // Solo actualizar si realmente cambió algo importante del evento
    if (oldWidget.event.id != widget.event.id ||
        oldWidget.event.endTime != widget.event.endTime ||
        oldWidget.event.startTime != widget.event.startTime ||
        oldWidget.event.isCompleted != widget.event.isCompleted) {
      // Actualizar estado de completado si cambió
      if (oldWidget.event.isCompleted != widget.event.isCompleted) {
        isCompleted = widget.event.isCompleted;
      }
      _checkAndUpdateCompletedStatus();
      _updateProgressTimer(); // Reiniciar timer de progreso si cambiaron las horas
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startTimers() {
    // Timer principal para verificaciones cada minuto
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        final newDateKey = _getDateKey();
        // Si cambió el día, recargar el estado
        if (_currentDateKey != newDateKey) {
          _currentDateKey = newDateKey;
          _loadCompletedStatus();
        }
        _checkAndUpdateCompletedStatus();
      }
    });

    // Inicializar el timer de progreso
    _updateProgressTimer();
  }

  void _updateProgressTimer() {
    _progressTimer?.cancel();

    // Solo crear timer de progreso si debe mostrar el indicador
    if (_shouldShowProgressIndicator()) {
      _progressTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted && _shouldShowProgressIndicator()) {
          final newProgress = _calculateProgress();
          if (newProgress != _currentProgress) {
            setState(() {
              _currentProgress = newProgress;
            });
          }
        } else {
          // Si ya no debe mostrar el progreso, cancelar el timer
          timer.cancel();
        }
      });

      // Actualizar progreso inicial
      _currentProgress = _calculateProgress();
    }
  }

  Future<void> _loadCompletedStatus() async {
    if (_isRepetitiveEvent()) {
      // Para eventos repetitivos, cargar el estado específico del día actual
      final prefs = await SharedPreferences.getInstance();
      final key = _getCompletionKey();
      final completedStatus =
          prefs.getBool(key) ?? false; // Default false para nuevos días
      if (mounted) {
        setState(() {
          isCompleted = completedStatus;
        });
      }
    } else {
      // Para eventos únicos, usar el estado del evento directamente
      if (mounted) {
        setState(() {
          isCompleted = widget.event.isCompleted;
        });
      }
    }

    // Actualizar timer de progreso después de cargar el estado
    _updateProgressTimer();
  }

  String _getDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String _getCompletionKey() {
    return 'event_${widget.event.id}_completion_$_currentDateKey';
  }

  bool _isRepetitiveEvent() {
    return widget.event.repeatDays.isNotEmpty;
  }

  Future<void> _saveCompletedStatus(bool completed) async {
    if (_isRepetitiveEvent()) {
      // Para eventos repetitivos, guardar el estado específico del día
      final prefs = await SharedPreferences.getInstance();
      final key = _getCompletionKey();
      await prefs.setBool(key, completed);

      // Opcional: limpiar estados antiguos (más de 30 días)
      _cleanOldCompletionStates();
    } else {
      // Para eventos únicos, actualizar el evento directamente
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

  double _calculateProgress() {
    if (widget.event.endTime == null) {
      return 0.0;
    }

    final now = DateTime.now();

    if (_isRepetitiveEvent()) {
      // Para eventos repetitivos, calcular el progreso para hoy
      final today = now.weekday;
      if (!widget.event.repeatDays.contains(today)) {
        return 0.0;
      }

      final todayStart = DateTime(
        now.year,
        now.month,
        now.day,
        widget.event.startTime.hour,
        widget.event.startTime.minute,
      );
      final todayEnd = DateTime(
        now.year,
        now.month,
        now.day,
        widget.event.endTime!.hour,
        widget.event.endTime!.minute,
      );

      if (now.isBefore(todayStart)) {
        return 0.0;
      }
      if (now.isAfter(todayEnd)) {
        return 1.0;
      }

      final totalDuration = todayEnd.difference(todayStart).inSeconds;
      final elapsedDuration = now.difference(todayStart).inSeconds;
      return elapsedDuration / totalDuration;
    } else {
      // Para eventos únicos, usar la lógica original
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
  }

  bool _shouldShowProgressIndicator() {
    final now = DateTime.now();
    final hasEndTime = widget.event.endTime != null;
    if (!hasEndTime) {
      return false;
    }

    if (_isRepetitiveEvent()) {
      // Para eventos repetitivos, verificar si hoy es uno de los días de repetición
      final today = now.weekday;
      if (!widget.event.repeatDays.contains(today)) {
        return false;
      }

      // Crear las horas de inicio y fin para hoy
      final todayStart = DateTime(
        now.year,
        now.month,
        now.day,
        widget.event.startTime.hour,
        widget.event.startTime.minute,
      );
      final todayEnd = DateTime(
        now.year,
        now.month,
        now.day,
        widget.event.endTime!.hour,
        widget.event.endTime!.minute,
      );

      return now.isAfter(todayStart) && now.isBefore(todayEnd);
    } else {
      return now.isAfter(widget.event.startTime) &&
          now.isBefore(widget.event.endTime!);
    }
  }

  void _checkAndUpdateCompletedStatus() {
    final now = DateTime.now();
    final hasEndTime = widget.event.endTime != null;

    if (_isRepetitiveEvent()) {
      // Para eventos repetitivos, no hacer cambios automáticos
      // El usuario debe marcarlos manualmente cada día
      return;
    }

    // Para eventos únicos, mantener la lógica original
    if (hasEndTime) {
      final hasEnded = now.isAfter(widget.event.endTime!);
      final isCurrentlyInProgress =
          now.isAfter(widget.event.startTime) &&
          now.isBefore(widget.event.endTime!);

      if (hasEnded && !isCompleted) {
        // Si no quieres marcar como hecho automáticamente, comenta la siguiente línea
        // _updateCompletedStatus(true);
      } else if (isCompleted && isCurrentlyInProgress) {
        _updateCompletedStatus(false);
      }
    }
  }

  void _updateCompletedStatus(bool value) {
    if (mounted) {
      setState(() {
        isCompleted = value;
        _saveCompletedStatus(value);

        // Solo actualizar el evento si no es repetitivo
        if (!_isRepetitiveEvent()) {
          final updatedEvent = widget.event.copyWith(isCompleted: value);
          widget.onUpdateEvent(updatedEvent);
        }
      });

      // Actualizar timer de progreso cuando cambia el estado de completado
      _updateProgressTimer();
    }
  }

  Widget _buildCompletionIndicator() {
    if (_isRepetitiveEvent()) {
      return Tooltip(
        message: isCompleted
            ? AppLocalizations.of(context).markAsComplete
            : AppLocalizations.of(context).markAsComplete,
        child: Checkbox(
          shape: const CircleBorder(),
          value: isCompleted,
          onChanged: (value) {
            // Removido el condicional widget.pastEvent
            _updateCompletedStatus(value!);
          },
        ),
      );
    } else {
      return Tooltip(
        message: isCompleted
            ? AppLocalizations.of(context).markAsIncomplete
            : AppLocalizations.of(context).markAsIncomplete,
        child: Checkbox(
          shape: const CircleBorder(),
          value: isCompleted,
          onChanged: (value) {
            // Removido el condicional widget.pastEvent
            _updateCompletedStatus(value!);
          },
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

    return GestureDetector(
      onTap: () {
        _showEventDetails(context);
      },
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                // En el método build() del EventCard, en la parte donde se muestra el ícono de categoría:

if (widget.event.category.isNotEmpty)
  Container(
    padding: const EdgeInsets.all(6),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
      shape: BoxShape.circle,
    ),
    child: Icon(
      getCategoryIcon(widget.event.category, context), // <- Agregar context aquí
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
                          const SizedBox(height: 4),
                          _buildStatusIndicator(),
                        ],
                      ),
                    ),
                    if (widget.event.endTime != null && !isCompleted && !isPast)
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
                if (_shouldShowProgressIndicator())
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      children: [
                        LinearProgressIndicator(
                          value: _currentProgress, // Usar el progreso cacheado
                          minHeight: 4,
                          borderRadius: BorderRadius.circular(2),
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
                              _isRepetitiveEvent()
                                  ? formatTime(
                                      DateTime(
                                        DateTime.now().year,
                                        DateTime.now().month,
                                        DateTime.now().day,
                                        widget.event.startTime.hour,
                                        widget.event.startTime.minute,
                                      ),
                                    )
                                  : formatTime(widget.event.startTime),
                              style: TextStyle(
                                fontSize: 10,
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurface.withOpacity(0.5),
                              ),
                            ),
                            Text(
                              _isRepetitiveEvent()
                                  ? formatTime(
                                      DateTime(
                                        DateTime.now().year,
                                        DateTime.now().month,
                                        DateTime.now().day,
                                        widget.event.endTime!.hour,
                                        widget.event.endTime!.minute,
                                      ),
                                    )
                                  : formatTime(widget.event.endTime!),
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

  String formatTime(DateTime dateTime) {
    return DateFormat.jm().format(dateTime);
  }
}

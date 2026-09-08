// lib/widgets/event_card.dart
// MEJORAS:
// 1. Barra de progreso suave con AnimatedBuilder + Tween
// 2. Muestra tiempo restante en formato legible
// 3. Colores de progreso dinámicos según porcentaje
// 4. Estado de evento activo bien distinguido visualmente
// 5. Tick local cada segundo: la tarjeta se actualiza sola, sin depender
//    del timer global del provider ni de recargar la pantalla.

import 'dart:async';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/event.dart';
import 'package:myapp/screens/add_event_screen.dart';
import 'package:myapp/utils/event_utils.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/widgets/event_preview_sheet.dart';

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
  State<EventCard> createState() => _EventCardState();
}

class _EventCardState extends State<EventCard>
    with SingleTickerProviderStateMixin {
  late bool isCompleted;
  String? _currentDateKey;

  late AnimationController _progressAnimController;
  late Animation<double> _progressAnim;
  double _lastProgress = 0.0;

  Timer? _tickTimer;

  @override
  void initState() {
    super.initState();
    _currentDateKey = _getDateKey();

    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressAnimController, curve: Curves.easeInOut),
    );

    _loadCompletedStatus();
    _syncTicker();
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _progressAnimController.dispose();
    super.dispose();
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

    _syncTicker();
  }

  void _syncTicker() {
    final shouldTick = _shouldShowProgress();

    if (shouldTick && _tickTimer == null) {
      _tickTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) {
          _tickTimer?.cancel();
          return;
        }
        if (!_shouldShowProgress()) {
          _tickTimer?.cancel();
          _tickTimer = null;
        }
        setState(() {});
      });
    } else if (!shouldTick && _tickTimer != null) {
      _tickTimer?.cancel();
      _tickTimer = null;
    }
  }

  Future<void> _loadCompletedStatus() async {
    final provider = Provider.of<EventProvider>(context, listen: false);
    if (mounted) {
      setState(() {
        isCompleted = _isRepetitive()
            ? provider.getEventCompletion(widget.event.id, DateTime.now())
            : widget.event.isCompleted;
      });
      _syncTicker();
    }
  }

  String _getDateKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  bool _isRepetitive() => widget.event.repeatDays.isNotEmpty;

  void _updateCompleted(bool value) {
    if (!mounted) return;
    setState(() => isCompleted = value);
    _syncTicker();

    final provider = Provider.of<EventProvider>(context, listen: false);
    provider.updateEventCompletion(widget.event, value, DateTime.now());
  }

  bool _shouldShowProgress() {
    if (widget.event.endTime == null || isCompleted || widget.pastEvent) {
      return false;
    }
    final now = DateTime.now();

    if (_isRepetitive()) {
      if (!widget.event.repeatDays.contains(now.weekday)) return false;
      final start = DateTime(
        now.year,
        now.month,
        now.day,
        widget.event.startTime.hour,
        widget.event.startTime.minute,
      );
      final end = DateTime(
        now.year,
        now.month,
        now.day,
        widget.event.endTime!.hour,
        widget.event.endTime!.minute,
      );
      return now.isAfter(start) && now.isBefore(end);
    } else {
      return now.isAfter(widget.event.startTime) &&
          now.isBefore(widget.event.endTime!);
    }
  }

  double _calculateCurrentProgress() {
    if (widget.event.endTime == null) return 0.0;
    final now = DateTime.now();

    if (_isRepetitive()) {
      if (!widget.event.repeatDays.contains(now.weekday)) return 0.0;
      final s = DateTime(
        now.year,
        now.month,
        now.day,
        widget.event.startTime.hour,
        widget.event.startTime.minute,
      );
      final e = DateTime(
        now.year,
        now.month,
        now.day,
        widget.event.endTime!.hour,
        widget.event.endTime!.minute,
      );
      if (now.isBefore(s)) return 0.0;
      if (now.isAfter(e)) return 1.0;
      return (now.difference(s).inMilliseconds / e.difference(s).inMilliseconds)
          .clamp(0.0, 1.0);
    } else {
      if (now.isBefore(widget.event.startTime)) return 0.0;
      if (now.isAfter(widget.event.endTime!)) return 1.0;
      return (now.difference(widget.event.startTime).inMilliseconds /
              widget.event.endTime!
                  .difference(widget.event.startTime)
                  .inMilliseconds)
          .clamp(0.0, 1.0);
    }
  }

  String _remainingTime(double progress) {
    if (widget.event.endTime == null) return '';
    final now = DateTime.now();

    DateTime endRef;
    if (_isRepetitive()) {
      endRef = DateTime(
        now.year,
        now.month,
        now.day,
        widget.event.endTime!.hour,
        widget.event.endTime!.minute,
      );
    } else {
      endRef = widget.event.endTime!;
    }

    final remaining = endRef.difference(now);
    if (remaining.isNegative) return '';

    final h = remaining.inHours;
    final m = remaining.inMinutes.remainder(60);
    final s = remaining.inSeconds.remainder(60);

    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Color _progressColor(double progress, BuildContext context) {
    if (progress < 0.5) {
      return Color.lerp(Colors.green, Colors.amber, progress * 2)!;
    } else {
      return Color.lerp(Colors.amber, Colors.red, (progress - 0.5) * 2)!;
    }
  }

  Widget _buildStatusIndicator() {
    if (widget.pastEvent) {
      return Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.history,
            color: isCompleted ? Colors.green : Colors.grey,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            isCompleted
                ? AppLocalizations.of(context).accomplished
                : AppLocalizations.of(context).notAccomplished,
            style: TextStyle(
              color: isCompleted ? Colors.green : Colors.grey,
              fontSize: 12,
            ),
          ),
        ],
      );
    }

    if (_isRepetitive()) {
      return Row(
        children: [
          Icon(
            Icons.repeat,
            color: Theme.of(context).colorScheme.primary,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            _repeatDaysText(),
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

  String _repeatDaysText() {
    final names = [
      '',
      AppLocalizations.of(context).mon,
      AppLocalizations.of(context).tue,
      AppLocalizations.of(context).wed,
      AppLocalizations.of(context).thu,
      AppLocalizations.of(context).fri,
      AppLocalizations.of(context).sat,
      AppLocalizations.of(context).sun,
    ];
    return widget.event.repeatDays.map((d) => names[d]).join(', ');
  }

  String _eventDuration() {
    final end = widget.event.endTime;
    if (end == null) return '';

    final startMinutes = widget.event.startTime.hour * 60 +
        widget.event.startTime.minute;
    final endMinutes = end.hour * 60 + end.minute;
    var duration = endMinutes - startMinutes;

    // Supports events that cross midnight without changing event data.
    if (duration < 0) duration += 24 * 60;

    final hours = duration ~/ 60;
    final minutes = duration % 60;

    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  Widget _buildDurationIndicator(BuildContext context) {
    if (widget.event.endTime == null) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final duration = _eventDuration();

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 15,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 3),
          Text(
            duration,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final opacity = widget.pastEvent ? 0.5 : (isCompleted ? 0.65 : 1.0);
    final rawProgress = _calculateCurrentProgress();
    final showProgress = _shouldShowProgress();

    if (showProgress && (rawProgress - _lastProgress).abs() > 0.0005) {
      _progressAnim =
          Tween<double>(begin: _progressAnim.value, end: rawProgress).animate(
            CurvedAnimation(
              parent: _progressAnimController,
              curve: Curves.easeOut,
            ),
          );
      _progressAnimController
        ..reset()
        ..forward();
      _lastProgress = rawProgress;
    }

    return GestureDetector(
      onTap: () => _showPreview(context),
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Opacity(
          opacity: opacity,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    if (widget.event.importance != null &&
                        widget.event.importance! > 0)
                      Container(
                        width: 4,
                        height: 40,
                        decoration: BoxDecoration(
                          color: getImportanceColor(widget.event.importance!),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    if (widget.event.importance != null &&
                        widget.event.importance! > 0)
                      const SizedBox(width: 8),

                    if (widget.event.category.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          getCategoryIcon(widget.event.category, context),
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    if (widget.event.category.isNotEmpty)
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
                                    decoration: isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                _formatTime(widget.event.startTime),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                ),
                              ),
                              _buildDurationIndicator(context),
                            ],
                          ),
                          const SizedBox(height: 4),
                          _buildStatusIndicator(),
                        ],
                      ),
                    ),

                    Tooltip(
                      message: isCompleted
                          ? AppLocalizations.of(context).markAsIncomplete
                          : AppLocalizations.of(context).markAsComplete,
                      child: Checkbox(
                        shape: const CircleBorder(),
                        value: isCompleted,
                        onChanged: (v) => _updateCompleted(v!),
                      ),
                    ),
                  ],
                ),

                if (showProgress)
                  AnimatedBuilder(
                    animation: _progressAnim,
                    builder: (context, _) {
                      final p = _progressAnim.value;
                      final color = _progressColor(p, context);
                      final remaining = _remainingTime(p);

                      return Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Column(
                          children: [
                            M3EProgressIndicator.linearWavy(
                              value: p,
                              linearSize: M3EProgressIndicatorSize.s,
                              color: color,
                              trackColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${(p * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                Text(
                                  remaining,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return DateFormat('HH:mm').format(time);
  }

  void _showPreview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventPreviewSheet(
        event: widget.event,
        onUpdateEvent: widget.onUpdateEvent,
      ),
    );
  }
}

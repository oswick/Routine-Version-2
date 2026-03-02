// lib/widgets/event_card.dart
// MEJORAS:
// 1. Barra de progreso suave con AnimatedBuilder + Tween
// 2. Muestra tiempo restante en formato legible
// 3. Colores de progreso dinámicos según porcentaje
// 4. Estado de evento activo bien distinguido visualmente

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

  // Smooth progress animation
  late AnimationController _progressAnimController;
  late Animation<double> _progressAnim;
  double _lastProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _currentDateKey = _getDateKey();

    _progressAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _progressAnim = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(
          parent: _progressAnimController, curve: Curves.easeInOut),
    );

    _loadCompletedStatus();
  }

  @override
  void dispose() {
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
  }

  // ── Completion helpers ────────────────────────────────────────────────────────
  Future<void> _loadCompletedStatus() async {
    final provider = Provider.of<EventProvider>(context, listen: false);
    if (mounted) {
      setState(() {
        isCompleted = _isRepetitive()
            ? provider.getEventCompletion(widget.event.id, DateTime.now())
            : widget.event.isCompleted;
      });
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

    final provider = Provider.of<EventProvider>(context, listen: false);
    provider.updateEventCompletion(widget.event, value, DateTime.now());
  }

  // ── Progress helpers ──────────────────────────────────────────────────────────
  bool _shouldShowProgress() {
    if (widget.event.endTime == null || isCompleted || widget.pastEvent) {
      return false;
    }
    final now = DateTime.now();

    if (_isRepetitive()) {
      if (!widget.event.repeatDays.contains(now.weekday)) return false;
      final start = DateTime(now.year, now.month, now.day,
          widget.event.startTime.hour, widget.event.startTime.minute);
      final end = DateTime(now.year, now.month, now.day,
          widget.event.endTime!.hour, widget.event.endTime!.minute);
      return now.isAfter(start) && now.isBefore(end);
    } else {
      return now.isAfter(widget.event.startTime) &&
          now.isBefore(widget.event.endTime!);
    }
  }

  /// Returns human-readable remaining time string.
  String _remainingTime(double progress) {
    if (widget.event.endTime == null) return '';
    final now = DateTime.now();

    DateTime endRef;
    if (_isRepetitive()) {
      endRef = DateTime(now.year, now.month, now.day,
          widget.event.endTime!.hour, widget.event.endTime!.minute);
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

  /// Dynamic color for progress bar: green → amber → red as time runs out.
  Color _progressColor(double progress, BuildContext context) {
    if (progress < 0.5) {
      return Color.lerp(Colors.green, Colors.amber, progress * 2)!;
    } else {
      return Color.lerp(Colors.amber, Colors.red, (progress - 0.5) * 2)!;
    }
  }

  // ── Status text / icon ────────────────────────────────────────────────────────
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
          Icon(Icons.repeat,
              color: Theme.of(context).colorScheme.primary, size: 14),
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

  // ── Build ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final opacity = widget.pastEvent ? 0.5 : (isCompleted ? 0.65 : 1.0);

    return Consumer<EventProvider>(
      builder: (context, provider, _) {
        final rawProgress = provider.getEventProgress(widget.event.id);
        final showProgress = _shouldShowProgress();

        // Animate to new progress value when it changes
        if (showProgress && (rawProgress - _lastProgress).abs() > 0.0005) {
          _progressAnim = Tween<double>(
            begin: _progressAnim.value,
            end: rawProgress,
          ).animate(CurvedAnimation(
              parent: _progressAnimController, curve: Curves.easeOut));
          _progressAnimController
            ..reset()
            ..forward();
          _lastProgress = rawProgress;
        }

        return GestureDetector(
          onTap: () => _showPreview(context),
          child: Card(
            color: Theme.of(context).colorScheme.surfaceContainer,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: Opacity(
              opacity: opacity,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Importance bar
                        if (widget.event.importance != null &&
                            widget.event.importance! > 0)
                          Container(
                            width: 4,
                            height: 40,
                            decoration: BoxDecoration(
                              color:
                                  getImportanceColor(widget.event.importance!),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        if (widget.event.importance != null &&
                            widget.event.importance! > 0)
                          const SizedBox(width: 8),

                        // Category icon
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
                        if (widget.event.category.isNotEmpty)
                          const SizedBox(width: 12),

                        // Title + status
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
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _formatTime(widget.event.startTime),
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

                        // Pomodoro button
                        if (widget.event.endTime != null &&
                            !isCompleted &&
                            !widget.pastEvent)
                          IconButton(
                            icon: Icon(Icons.timer,
                                color:
                                    Theme.of(context).colorScheme.primary),
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PomodoroScreen(event: widget.event),
                              ),
                            ),
                          ),

                        // Completion checkbox
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

                    // ── Real-time progress bar ──────────────────────────────────
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
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: p,
                                    minHeight: 5,
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(color),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // Elapsed %
                                    Text(
                                      '${(p * 100).toStringAsFixed(0)}%',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: color,
                                      ),
                                    ),
                                    // Remaining time
                                    if (remaining.isNotEmpty)
                                      Row(
                                        children: [
                                          Icon(Icons.schedule,
                                              size: 11, color: color),
                                          const SizedBox(width: 2),
                                          Text(
                                            remaining,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    // End time
                                    Text(
                                      _formatTime(widget.event.endTime!),
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
                          );
                        },
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

  // ── Sheet helpers ─────────────────────────────────────────────────────────────
  void _showPreview(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventPreviewSheet(
        event: widget.event,
        onEdit: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddEventBottomSheet(
              event: widget.event,
              onAddEvent: widget.onUpdateEvent,
              day: widget.event.startTime,
            ),
          );
        },
        onDelete: () {},
      ),
    );
  }

  String _formatTime(DateTime dt) => DateFormat.jm().format(dt);
}
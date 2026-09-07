import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/event.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:myapp/screens/add_event_screen.dart';
import 'package:myapp/screens/pomodoro_screen.dart';
import 'package:myapp/utils/event_utils.dart';
import 'package:myapp/widgets/event_preview_sheet.dart';
import 'package:provider/provider.dart';

class BrutalistEventTile extends StatefulWidget {
  final Event event;
  final bool pastEvent;

  const BrutalistEventTile({
    super.key,
    required this.event,
    this.pastEvent = false,
  });

  @override
  State<BrutalistEventTile> createState() => _BrutalistEventTileState();
}

class _BrutalistEventTileState extends State<BrutalistEventTile>
    with SingleTickerProviderStateMixin {
  late bool _completed;
  Timer? _timer;
  double _pressScale = 1;

  bool get _repeating => widget.event.repeatDays.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _completed = widget.event.isCompleted;
    _syncTimer();
  }

  @override
  void didUpdateWidget(covariant BrutalistEventTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.event.id != widget.event.id ||
        oldWidget.event.isCompleted != widget.event.isCompleted) {
      _completed = widget.event.isCompleted;
    }
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer() {
    final active = _isActive;
    if (active && _timer == null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        if (!_isActive) {
          _timer?.cancel();
          _timer = null;
        }
        setState(() {});
      });
    } else if (!active && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  DateTime _startForToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, widget.event.startTime.hour,
        widget.event.startTime.minute);
  }

  DateTime? _endForToday() {
    final end = widget.event.endTime;
    if (end == null) return null;
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, end.hour, end.minute);
  }

  bool get _isActive {
    if (_completed || widget.pastEvent || widget.event.endTime == null) {
      return false;
    }
    final now = DateTime.now();
    final start = _repeating ? _startForToday() : widget.event.startTime;
    final end = _repeating ? _endForToday()! : widget.event.endTime!;
    return now.isAfter(start) && now.isBefore(end);
  }

  double get _progress {
    if (!_isActive || widget.event.endTime == null) return 0;
    final now = DateTime.now();
    final start = _repeating ? _startForToday() : widget.event.startTime;
    final end = _repeating ? _endForToday()! : widget.event.endTime!;
    return (now.difference(start).inMilliseconds /
            end.difference(start).inMilliseconds)
        .clamp(0.0, 1.0);
  }

  String _time(DateTime value) => DateFormat.jm().format(value);

  String _repeatText(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final names = <int, String>{
      1: l10n.mon,
      2: l10n.tue,
      3: l10n.wed,
      4: l10n.thu,
      5: l10n.fri,
      6: l10n.sat,
      7: l10n.sun,
    };
    return widget.event.repeatDays.map((d) => names[d] ?? '').join(' · ');
  }

  Future<void> _toggleComplete() async {
    final value = !_completed;
    HapticFeedback.lightImpact();
    setState(() => _completed = value);
    await context.read<EventProvider>().updateEventCompletion(
          widget.event,
          value,
          DateTime.now(),
        );
  }

  void _openPreview() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventPreviewSheet(
        event: widget.event,
        onEdit: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => AddEventBottomSheet(
              event: widget.event,
              onAddEvent: context.read<EventProvider>().updateEvent,
              day: widget.event.startTime,
            ),
          );
        },
        onDelete: () {},
      ),
    );
  }

  void _openPomodoro() {
    HapticFeedback.mediumImpact();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PomodoroScreen(event: widget.event)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final muted = scheme.onSurfaceVariant;
    final opacity = widget.pastEvent || _completed ? 0.48 : 1.0;
    final accent = widget.event.importance != null && widget.event.importance! > 0
        ? getImportanceColor(widget.event.importance!)
        : scheme.primary;

    return AnimatedScale(
      scale: _pressScale,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
      child: Opacity(
        opacity: opacity,
        child: Semantics(
          button: true,
          label: widget.event.title,
          child: GestureDetector(
            onTapDown: (_) => setState(() => _pressScale = 0.985),
            onTapCancel: () => setState(() => _pressScale = 1),
            onTapUp: (_) => setState(() => _pressScale = 1),
            onTap: _openPreview,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              decoration: BoxDecoration(
                color: _isActive ? scheme.primaryContainer.withOpacity(0.18) : scheme.surface,
                border: Border(
                  left: BorderSide(color: accent, width: _isActive ? 5 : 3),
                  top: BorderSide(color: scheme.outlineVariant.withOpacity(0.75)),
                  bottom: BorderSide(color: scheme.outlineVariant.withOpacity(0.75)),
                  right: BorderSide(color: scheme.outlineVariant.withOpacity(0.75)),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 13, 10, 12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 72,
                        child: Text(
                          _time(widget.event.startTime),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            color: muted,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.event.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 19,
                                height: 1.05,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                decoration: _completed ? TextDecoration.lineThrough : null,
                                color: scheme.onSurface,
                              ),
                            ),
                            if (_repeating) ...[
                              const SizedBox(height: 5),
                              Text(
                                _repeatText(context),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.primary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (_isActive)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            'NOW',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                              color: scheme.primary,
                            ),
                          ),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: AppLocalizations.of(context).markAsComplete,
                        onPressed: _toggleComplete,
                        icon: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                          child: Icon(
                            _completed ? Icons.check_box : Icons.check_box_outline_blank,
                            key: ValueKey(_completed),
                            size: 23,
                            color: _completed ? scheme.primary : muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (widget.event.endTime != null) ...[
                    const SizedBox(height: 10),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: _isActive ? 5 : 1,
                      width: double.infinity,
                      color: _isActive ? scheme.primary : scheme.outlineVariant.withOpacity(0.35),
                      child: _isActive
                          ? Align(
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _progress,
                                child: Container(color: accent),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isActive
                              ? '${(_progress * 100).round()}%'
                              : _time(widget.event.endTime!),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _isActive ? accent : muted),
                        ),
                        if (_isActive)
                          Text(
                            '${_time(widget.event.startTime)} — ${_time(widget.event.endTime!)}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: muted),
                          ),
                      ],
                    ),
                  ],
                  if (!_completed && !widget.pastEvent && widget.event.endTime != null) ...[
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: 'Focus',
                        onPressed: _openPomodoro,
                        icon: Icon(Icons.timer_outlined, size: 20, color: muted),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

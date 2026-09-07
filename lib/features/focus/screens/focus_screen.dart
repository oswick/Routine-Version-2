import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import '../models/focus_config.dart';
import '../models/focus_phase.dart';
import '../providers/focus_provider.dart';
import '../widgets/break_view.dart';
import '../widgets/deep_focus_view.dart';
import '../widgets/focus_controls.dart';
import '../widgets/focus_progress.dart';
import '../widgets/focus_timer.dart';
import 'focus_history_screen.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, this.initialEventId});
  final String? initialEventId;
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  bool _deepFocus = false;
  bool _didAutoSync = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  void _sync() {
    if (!mounted) return;
    final events = context.read<EventProvider>().events;
    final focus = context.read<FocusProvider>();
    if (widget.initialEventId != null) {
      final event = events.where((e) => e.id == widget.initialEventId).firstOrNull;
      focus.selectEvent(widget.initialEventId, event: event);
    }
    focus.syncWithEvents(events);
    _didAutoSync = true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<EventProvider, FocusProvider>(
      builder: (context, events, focus, _) {
        if (_didAutoSync || events.events.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) focus.syncWithEvents(events.events);
          });
        }
        if (_deepFocus && focus.state is FocusActive) {
          return DeepFocusView(
            remaining: focus.remaining,
            progress: focus.progress,
            title: focus.activeEvent?.title ?? 'Free Focus',
            isRunning: focus.isRunning,
            onPause: focus.pause,
            onResume: focus.resume,
            onFinish: focus.finishEarly,
            onExit: () => setState(() => _deepFocus = false),
          );
        }
        return Scaffold(
          backgroundColor: Theme.of(context).colorScheme.surface,
          appBar: M3EAppBar.top(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 0,
            title: Text('Focus', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
            actions: [
              M3EIconButton(icon: const Icon(Icons.history_rounded), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FocusHistoryScreen()))),
            ],
          ),
          body: SafeArea(child: AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: _buildState(context, focus))),
        );
      },
    );
  }

  Widget _buildState(BuildContext context, FocusProvider focus) {
    final state = focus.state;
    if (state is FocusReady) return _ReadyView(focus: focus);
    if (state is FocusActive) return _ActiveView(focus: focus, onDeepFocus: () => setState(() => _deepFocus = true));
    if (state is FocusBreak) return BreakView(phase: state.phase, remaining: focus.remaining, progress: focus.progress, onStart: focus.startBreak, onSkip: focus.skipBreak);
    if (state is FocusCompleted) return _CompletedView(focus: focus);
    return const SizedBox.shrink();
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.focus});
  final FocusProvider focus;
  @override
  Widget build(BuildContext context) {
    final event = focus.activeEvent;
    return ListView(
      key: const ValueKey('ready'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        Text('Focus Center', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text('Choose what deserves your attention.', style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 24),
        if (event != null) M3ECard.filled(child: ListTile(leading: const Icon(Icons.schedule_rounded), title: Text(event.title), subtitle: Text('${_time(event.startTime)} – ${_time(event.endTime!)}'), trailing: const Icon(Icons.arrow_forward_rounded)))
        else M3ECard.filled(child: const ListTile(leading: Icon(Icons.self_improvement_rounded), title: Text('Free Focus'), subtitle: Text('A session without a scheduled event'))),
        const SizedBox(height: 24),
        M3ECard.outlined(child: Padding(padding: const EdgeInsets.all(20), child: Row(children: [const Icon(Icons.timer_outlined), const SizedBox(width: 16), Expanded(child: Text('Focus session', style: TextStyle(fontWeight: FontWeight.w600))), Text('${FocusConfig.focusDuration.inMinutes} min')]))) ,
        const SizedBox(height: 20),
        M3EButton.icon(onPressed: focus.startFocus, icon: const Icon(Icons.play_arrow_rounded), label: const Text('Start Focus'), style: M3EButtonStyle.filled, size: M3EButtonSize.lg),
      ],
    );
  }
}

class _ActiveView extends StatelessWidget {
  const _ActiveView({required this.focus, required this.onDeepFocus});
  final FocusProvider focus;
  final VoidCallback onDeepFocus;
  @override
  Widget build(BuildContext context) {
    final event = focus.activeEvent;
    return ListView(
      key: const ValueKey('active'),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      children: [
        M3ECard.filled(child: Padding(padding: const EdgeInsets.all(18), child: Row(children: [Icon(Icons.bolt_rounded, color: Theme.of(context).colorScheme.primary), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(event?.title ?? 'Free Focus', style: Theme.of(context).textTheme.titleLarge), Text(event != null ? '${_time(event.startTime)} – ${_time(event.endTime!)}' : 'Focus session', style: Theme.of(context).textTheme.bodyMedium)]))])) ,
        const SizedBox(height: 28),
        Center(child: FocusTimer(remaining: focus.remaining, progress: focus.progress)),
        const SizedBox(height: 20),
        FocusProgress(progress: focus.progress),
        const SizedBox(height: 28),
        FocusControls(isRunning: focus.isRunning, onStart: focus.resume, onPause: focus.pause, onFinish: focus.finishEarly, onAddTime: focus.addFiveMinutes),
        const SizedBox(height: 8),
        Center(child: TextButton.icon(onPressed: onDeepFocus, icon: const Icon(Icons.fullscreen_rounded), label: const Text('Deep Focus'))),
      ],
    );
  }
}

class _CompletedView extends StatelessWidget {
  const _CompletedView({required this.focus});
  final FocusProvider focus;
  @override
  Widget build(BuildContext context) {
    final isFocus = focus.phase == FocusPhase.focus;
    return Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle_rounded, size: 72, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 20), Text(isFocus ? 'Nice work' : 'Break complete', style: Theme.of(context).textTheme.headlineMedium), const SizedBox(height: 12), Text('${focus.elapsed.inMinutes} min completed'), const SizedBox(height: 28), M3EButton(onPressed: focus.startNextPhase, label: Text(isFocus ? 'Start break' : 'Start next focus'), style: M3EButtonStyle.filled, size: M3EButtonSize.lg), M3EButton.text(onPressed: focus.reset, child: const Text('Return to Focus'))])));
  }
}

String _time(DateTime time) => '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

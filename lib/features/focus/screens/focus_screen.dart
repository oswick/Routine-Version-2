import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/focus_config.dart';
import '../models/focus_phase.dart';
import '../providers/focus_provider.dart';
import '../widgets/break_view.dart';
import '../widgets/deep_focus_view.dart';
import '../widgets/focus_controls.dart';
import '../widgets/focus_event_selector.dart';
import '../widgets/focus_progress.dart';
import '../widgets/focus_stats.dart';
import '../widgets/focus_timer.dart';
import 'focus_history_screen.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key});
  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  bool _deepFocus = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<FocusProvider>(
      builder: (context, focus, _) {
        if (_deepFocus && focus.state is FocusActive) {
          return DeepFocusView(
            remaining: focus.remaining,
            progress: focus.progress,
            title: focus.eventId == null ? 'Free Focus' : 'Focus',
            isRunning: focus.isRunning,
            onPause: focus.pause,
            onResume: focus.resume,
            onFinish: focus.finishEarly,
            onExit: () => setState(() => _deepFocus = false),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: const Text('Focus'),
            actions: [
              IconButton(
                tooltip: 'Focus history',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FocusHistoryScreen()),
                ),
                icon: const Icon(Icons.history_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: _buildState(context, focus),
            ),
          ),
        );
      },
    );
  }

  Widget _buildState(BuildContext context, FocusProvider focus) {
    final state = focus.state;
    if (state is FocusReady) return _ReadyView(focus: focus);
    if (state is FocusActive) {
      return _ActiveView(focus: focus, onDeepFocus: () => setState(() => _deepFocus = true));
    }
    if (state is FocusBreak) {
      return BreakView(
        phase: state.phase,
        remaining: focus.remaining,
        progress: focus.progress,
        onStart: focus.startBreak,
        onSkip: focus.skipBreak,
      );
    }
    if (state is FocusCompleted) return _CompletedView(focus: focus);
    return const SizedBox.shrink();
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.focus});
  final FocusProvider focus;
  @override
  Widget build(BuildContext context) {
    return ListView(
      key: const ValueKey('ready'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Text('Focus Center', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const FocusStats(),
        const SizedBox(height: 32),
        FocusEventSelector(eventId: focus.eventId, onChanged: focus.selectEvent),
        const SizedBox(height: 24),
        Text('Suggested · ${FocusConfig.focusDuration.inMinutes} min', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: focus.startFocus,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Start Focus'),
        ),
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
    return ListView(
      key: const ValueKey('active'),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Text(focus.eventId == null ? 'Free Focus' : 'Focus', textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 32),
        FocusTimer(remaining: focus.remaining, progress: focus.progress),
        const SizedBox(height: 24),
        FocusProgress(progress: focus.progress),
        const SizedBox(height: 24),
        FocusControls(isRunning: focus.isRunning, onStart: focus.resume, onPause: focus.pause, onFinish: focus.finishEarly, onAddTime: focus.addFiveMinutes),
        const SizedBox(height: 16),
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
    final phase = focus.phase;
    final isFocus = phase == FocusPhase.focus;
    return Center(
      key: const ValueKey('completed'),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, size: 72, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text(isFocus ? 'Nice work' : 'Break complete', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Text('${focus.elapsed.inMinutes} min'),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: focus.startNextPhase,
              child: Text(isFocus ? 'Start break' : 'Start next focus'),
            ),
            TextButton(onPressed: focus.reset, child: const Text('Return to Focus')),
          ],
        ),
      ),
    );
  }
}

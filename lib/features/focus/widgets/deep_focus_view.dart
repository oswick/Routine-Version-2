import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'focus_timer.dart';

class DeepFocusView extends StatefulWidget {
  const DeepFocusView({
    super.key,
    required this.remaining,
    required this.progress,
    required this.title,
    required this.isRunning,
    required this.onPause,
    required this.onResume,
    required this.onFinish,
    required this.onExit,
  });

  final Duration remaining;
  final double progress;
  final String title;
  final bool isRunning;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onFinish;
  final VoidCallback onExit;

  @override
  State<DeepFocusView> createState() => _DeepFocusViewState();
}

class _DeepFocusViewState extends State<DeepFocusView> {
  @override
  void initState() {
    super.initState();
    _enable();
  }

  Future<void> _enable() async {
    await WakelockPlus.enable();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _disable() async {
    await WakelockPlus.disable();
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  @override
  void dispose() {
    _disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                widget.title,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 20),
              ),
              const SizedBox(height: 36),
              FocusTimer(
                remaining: widget.remaining,
                progress: widget.progress,
                large: true,
              ),
              const SizedBox(height: 36),
              IconButton.filledTonal(
                onPressed: widget.isRunning ? widget.onPause : widget.onResume,
                icon: Icon(widget.isRunning ? Icons.pause : Icons.play_arrow),
                iconSize: 30,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: widget.onFinish,
                child: const Text('Finish', style: TextStyle(color: Colors.white70)),
              ),
              TextButton(
                onPressed: widget.onExit,
                child: const Text('Exit Deep Focus', style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

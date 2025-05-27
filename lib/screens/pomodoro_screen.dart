import 'dart:async';
import 'package:flutter/material.dart';
import '../models/event.dart';
import '../utils/notification_service.dart';

class PomodoroScreen extends StatefulWidget {
  final Event event;

  const PomodoroScreen({
    super.key, 
    required this.event,
  });

  @override
  _PomodoroScreenState createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen> {
  Timer? _timer;
  late Duration _timeLeft;
  bool _isRunning = false;
  
  @override
  void initState() {
    super.initState();
    _initializeTimer();
    if (_shouldAutoStart()) {
      _startTimer();
      _isRunning = true;
    }
  }

  void _initializeTimer() {
    if (widget.event.endTime == null) {
      _timeLeft = const Duration(minutes: 25);
      return;
    }

    final now = DateTime.now();
    
    if (now.isBefore(widget.event.startTime)) {
      _timeLeft = widget.event.endTime!.difference(widget.event.startTime);
      return;
    }
    
    if (now.isAfter(widget.event.endTime!)) {
      _timeLeft = const Duration(seconds: 0);
      return;
    }
    
    _timeLeft = widget.event.endTime!.difference(now);
  }

  bool _shouldAutoStart() {
    if (widget.event.endTime == null) return false;
    
    final now = DateTime.now();
    return now.isAfter(widget.event.startTime) && 
           now.isBefore(widget.event.endTime!);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft.inSeconds > 0) {
          _timeLeft = _timeLeft - const Duration(seconds: 1);
        } else {
          timer.cancel();
          _onTimerComplete();
        }
      });
    });
  }

  void _pauseTimer() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    setState(() {
      _initializeTimer();
      _isRunning = false;
    });
  }

  void _onTimerComplete() {
    _timer?.cancel();
    setState(() {
      _isRunning = false;
    });
    
    NotificationService().scheduleNotification(
      widget.event.id.hashCode + 20000,
      "¡Evento Terminado!",
      "El evento ${widget.event.title} ha terminado",
      DateTime.now(),
      null,
    );
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return duration.inHours > 0 
        ? "$hours:$minutes:$seconds"
        : "$minutes:$seconds";
  }

  double _calculateProgress() {
    if (widget.event.endTime == null) return 0;
    final totalDuration = widget.event.endTime!.difference(widget.event.startTime);
    final remaining = _timeLeft;
    return 1 - (remaining.inSeconds / totalDuration.inSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final timerSize = size.width * 0.85; // Hacer el timer más grande, usando 85% del ancho de pantalla

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.event.title),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Timer circular grande
            SizedBox(
              height: timerSize,
              width: timerSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Fondo gris más delgado
                  SizedBox(
                    height: timerSize,
                    width: timerSize,
                    child: CircularProgressIndicator(
                      value: 1,
                      strokeWidth: 5,
                      backgroundColor: Colors.grey.withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.transparent,
                      ),
                    ),
                  ),
                  // Progreso principal
                  SizedBox(
                    height: timerSize,
                    width: timerSize,
                    child: CircularProgressIndicator(
                      value: _calculateProgress(),
                      strokeWidth: 5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  // Contenido central
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tiempo restante en grande
                      Text(
                        _formatTime(_timeLeft),
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (widget.event.endTime != null) ...[
                        const SizedBox(height: 16),
                        // Tiempo total en pequeño
                        Text(
                          "Tiempo Total: ${_formatTime(widget.event.endTime!.difference(widget.event.startTime))}",
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        // Horarios de inicio y fin
                        Text(
                          "Inicio: ${_formatDateTime(widget.event.startTime)}",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        Text(
                          "Fin: ${_formatDateTime(widget.event.endTime!)}",
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Botones de control
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FloatingActionButton.large(
                  heroTag: "playPause",
                  onPressed: () {
                    setState(() {
                      if (_isRunning) {
                        _pauseTimer();
                      } else {
                        _startTimer();
                        _isRunning = true;
                      }
                    });
                  },
                  child: Icon(
                    _isRunning ? Icons.pause : Icons.play_arrow,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 20),
                FloatingActionButton.large(
                  heroTag: "reset",
                  onPressed: _resetTimer,
                  child: const Icon(
                    Icons.restart_alt,
                    size: 36,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
  }
}
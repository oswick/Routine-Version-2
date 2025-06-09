import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/event.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/notification_service.dart';

class PomodoroScreen extends StatefulWidget {
  final Event event;

  const PomodoroScreen({super.key, required this.event});

  @override
  _PomodoroScreenState createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  late Duration _timeLeft;
  bool _isRunning = false;
  bool _isAmoledMode = false;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _breathingController;
  late AnimationController _buttonController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _buttonScaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeTimer();

    if (_shouldAutoStart()) {
      _startTimer();
      _isRunning = true;
    }
  }

  void _initializeAnimations() {
    // Pulse animation para el timer cuando está corriendo
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Breathing animation para el fondo
    _breathingController = AnimationController(
      duration: const Duration(milliseconds: 4000),
      vsync: this,
    );
    _breathingAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );

    // Button scale animation
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _buttonScaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );

    _breathingController.repeat(reverse: true);
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
    _pulseController.dispose();
    _breathingController.dispose();
    _buttonController.dispose();

    // Desactivar wakelock al salir de la pantalla
    WakelockPlus.disable();

    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _pulseController.repeat(reverse: true);

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
    _pulseController.stop();
    setState(() {
      _isRunning = false;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _pulseController.stop();
    setState(() {
      _initializeTimer();
      _isRunning = false;
    });
  }

  void _onTimerComplete() {
    _timer?.cancel();
    _pulseController.stop();
    setState(() {
      _isRunning = false;
    });

    // Desactivar wakelock cuando el evento termine
    if (_isAmoledMode) {
      WakelockPlus.disable();
    }

    HapticFeedback.heavyImpact();

    NotificationService().scheduleNotification(
      widget.event.id.hashCode + 20000,
      "¡Evento Terminado!",
      "El evento ${widget.event.title} ha terminado",
      DateTime.now(),
      null,
    );
  }

  void _toggleAmoledMode() {
    setState(() {
      _isAmoledMode = !_isAmoledMode;

      // Activar/desactivar wakelock según el modo AMOLED
      if (_isAmoledMode) {
        WakelockPlus.enable(); // Mantener pantalla encendida
      } else {
        WakelockPlus.disable(); // Permitir que la pantalla se apague normalmente
      }
    });
  }

  String _formatTime(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  double _calculateProgress() {
    if (widget.event.endTime == null) {
      return _timeLeft.inSeconds / (25 * 60);
    }
    final totalDuration = widget.event.endTime!.difference(
      widget.event.startTime,
    );
    final remaining = _timeLeft;
    return 1 - (remaining.inSeconds / totalDuration.inSeconds);
  }

  Color get _backgroundColor {
    if (_isAmoledMode) return Colors.black;
    return Theme.of(context).colorScheme.surface;
  }

  Color get _primaryColor {
    if (_isAmoledMode) return Colors.white;
    return Theme.of(context).colorScheme.primary;
  }

  Color get _textColor {
    if (_isAmoledMode) return Colors.white;
    return Theme.of(context).colorScheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: _isAmoledMode
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_backgroundColor, _backgroundColor.withOpacity(0.8)],
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        widget.event.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: _textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Stack(
                      children: [
                        IconButton(
                          onPressed: _toggleAmoledMode,
                          icon: Icon(
                            _isAmoledMode ? Icons.light_mode : Icons.dark_mode,
                            color: _textColor,
                          ),
                        ),
                        // Indicador visual cuando wakelock está activo
                        if (_isAmoledMode)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Timer principal
              Expanded(
                child: Center(
                  child: AnimatedBuilder(
                    animation: _breathingAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _breathingAnimation.value,
                        child: AnimatedBuilder(
                          animation: _pulseAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _isRunning ? _pulseAnimation.value : 1.0,
                              child: _buildTimerWidget(),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Controles
              Padding(
                padding: const EdgeInsets.all(40),
                child: _buildControls(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerWidget() {
    final size = MediaQuery.of(context).size.width * 0.75;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: _isAmoledMode
            ? null
            : [
                BoxShadow(
                  color: _primaryColor.withOpacity(0.1),
                  blurRadius: 30,
                  spreadRadius: 10,
                ),
              ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Círculo de fondo
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isAmoledMode
                  ? Colors.grey.withOpacity(0.1)
                  : _primaryColor.withOpacity(0.05),
            ),
          ),

          // Progreso circular
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: CircularProgressPainter(
                progress: _calculateProgress(),
                color: _primaryColor,
                strokeWidth: 3,
                isAmoled: _isAmoledMode,
              ),
            ),
          ),

          // Contenido central
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Tiempo principal
              Text(
                _formatTime(_timeLeft),
                style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: _textColor,
                  letterSpacing: 2,
                ),
              ),

              const SizedBox(height: 16),

              // Estado
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: _primaryColor.withOpacity(0.1),
                ),
                child: Text(
                  _isRunning ? 'En progreso' : 'Pausado',
                  style: TextStyle(
                    fontSize: 14,
                    color: _primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

              // Indicador de pantalla activa en modo AMOLED
              if (_isAmoledMode) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Pantalla activa',
                      style: TextStyle(
                        fontSize: 12,
                        color: _textColor.withOpacity(0.7),
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Botón de play/pause
        GestureDetector(
          onTapDown: (_) => _buttonController.forward(),
          onTapUp: (_) => _buttonController.reverse(),
          onTapCancel: () => _buttonController.reverse(),
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() {
              if (_isRunning) {
                _pauseTimer();
              } else {
                _startTimer();
                _isRunning = true;
              }
            });
          },
          child: AnimatedBuilder(
            animation: _buttonScaleAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _buttonScaleAnimation.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _primaryColor,
                    boxShadow: _isAmoledMode
                        ? null
                        : [
                            BoxShadow(
                              color: _primaryColor.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                  ),
                  child: Icon(
                    _isRunning ? Icons.pause : Icons.play_arrow,
                    size: 36,
                    color: _isAmoledMode ? Colors.black : Colors.white,
                  ),
                ),
              );
            },
          ),
        ),

        const SizedBox(width: 32),

        // Botón de reset
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            _resetTimer();
          },
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _isAmoledMode
                  ? Colors.white.withOpacity(0.1)
                  : _primaryColor.withOpacity(0.1),
              border: Border.all(
                color: _primaryColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Icon(Icons.restart_alt, size: 28, color: _primaryColor),
          ),
        ),
      ],
    );
  }
}

class CircularProgressPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;
  final bool isAmoled;

  CircularProgressPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
    required this.isAmoled,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Fondo del círculo
    final backgroundPaint = Paint()
      ..color = isAmoled
          ? Colors.white.withOpacity(0.1)
          : color.withOpacity(0.1)
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progreso
    final progressPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

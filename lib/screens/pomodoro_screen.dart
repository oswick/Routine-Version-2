// lib/screens/pomodoro_screen.dart - Versión Material 3 Expressive
import 'dart:async';
import 'dart:math' as math;
import 'package:material_3_expressive/components/buttons/enums/m3e_button_enums.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';
import '../models/event.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../utils/notification_service.dart';

class PomodoroScreen extends StatefulWidget {
  final Event event;
  final Function(bool)? onAmoledModeChanged;

  const PomodoroScreen({
    super.key,
    required this.event,
    this.onAmoledModeChanged,
  });

  @override
  _PomodoroScreenState createState() => _PomodoroScreenState();
}

class _PomodoroScreenState extends State<PomodoroScreen>
    with TickerProviderStateMixin {
  Timer? _timer;
  late Duration _timeLeft;
  bool _isRunning = false;
  bool _isAmoledMode = false;
  bool _isCompleted = false;

  // Animation controllers
  // NOTA M3E: el controller/animación de "press scale" para los botones
  // circulares de control desapareció — M3EButton ya trae su propio
  // spring-driven press feedback incorporado, así que ya no hace falta
  // simularlo a mano con un GestureDetector + AnimationController.
  late AnimationController _pulseController;
  late AnimationController _breathingController;
  late AnimationController _completionController;

  // Animations
  late Animation<double> _pulseAnimation;
  late Animation<double> _breathingAnimation;
  late Animation<double> _completionAnimation;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.event.isCompleted;
    _initializeAnimations();
    _initializeTimer();

    if (_shouldAutoStart() && !_isCompleted) {
      _startTimer();
      _isRunning = true;
    }

    // Notificar el estado inicial del modo AMOLED
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.onAmoledModeChanged != null) {
        widget.onAmoledModeChanged!(_isAmoledMode);
      }
    });
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

    // Completion animation
    _completionController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _completionAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _completionController, curve: Curves.bounceOut),
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
    _completionController.dispose();

    // Desactivar el modo AMOLED al salir de la pantalla
    if (_isAmoledMode) {
      WakelockPlus.disable();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      if (widget.onAmoledModeChanged != null) {
        widget.onAmoledModeChanged!(false);
      }
    }

    super.dispose();
  }

  void _startTimer() {
    if (_isCompleted) return;

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

  void _onTimerComplete() async {
    _timer?.cancel();
    _pulseController.stop();

    // Marcar evento como completado automáticamente
    if (!_isCompleted) {
      await _toggleCompletion();
    }

    setState(() {
      _isRunning = false;
    });

    // Desactivar wakelock cuando el evento termine
    if (_isAmoledMode) {
      WakelockPlus.disable();
    }

    HapticFeedback.heavyImpact();

    // Mostrar dialog de finalización
    if (mounted) {
      _showCompletionDialog();
    }

    NotificationService().scheduleNotification(
      widget.event.id.hashCode + 20000,
      "¡Evento Terminado!",
      "El evento ${widget.event.title} ha terminado",
      DateTime.now(),
      null,
    );
  }

  Future<void> _toggleCompletion() async {
    try {
      final eventProvider = Provider.of<EventProvider>(context, listen: false);
      final updatedEvent = widget.event.copyWith(
        isCompleted: !_isCompleted,
        lastModified: DateTime.now(),
      );

      await eventProvider.updateEvent(updatedEvent);

      setState(() {
        _isCompleted = !_isCompleted;
      });

      // Animación de completion
      if (_isCompleted) {
        _completionController.forward();
        HapticFeedback.mediumImpact();
      } else {
        _completionController.reverse();
      }

      // Mostrar feedback visual
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isCompleted ? 'Task completed! 🎉' : 'Task marked as incomplete'),
            duration: const Duration(seconds: 2),
            backgroundColor: _isCompleted ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showCompletionDialog() {
    showDialog(
      context: context,
      // M3EDialog real del paquete, igual que en event_preview_sheet.dart:
      // header + icono + contenido + acciones ya siguen los tokens M3E.
      builder: (context) => M3EDialog(
        icon: const Icon(Icons.celebration, color: Colors.green, size: 32),
        title: '¡Completado!',
        content: const Text(
          '¡Has completado la tarea! 🎉\n\n'
          '¡Excelente trabajo manteniendo el foco!',
          textAlign: TextAlign.center,
        ),
        actions: [
          M3EButton(
            style: M3EButtonStyle.filled,
            size: M3EButtonSize.sm,
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Salir del Pomodoro
            },
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  void _toggleAmoledMode() {
    setState(() {
      _isAmoledMode = !_isAmoledMode;

      if (widget.onAmoledModeChanged != null) {
        widget.onAmoledModeChanged!(_isAmoledMode);
      }

      if (_isAmoledMode) {
        WakelockPlus.enable();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
      } else {
        WakelockPlus.disable();
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
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
    if (_isCompleted) return Colors.green;
    if (_isAmoledMode) return Colors.white;
    return Theme.of(context).colorScheme.primary;
  }

  Color get _textColor {
    if (_isAmoledMode) return Colors.white;
    return Theme.of(context).colorScheme.onSurface;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EventProvider>(
      builder: (context, eventProvider, child) {
        // Actualizar el estado de completion si cambió desde otra pantalla
        final currentEvent = eventProvider.events
            .where((e) => e.id == widget.event.id)
            .firstOrNull;

        if (currentEvent != null && currentEvent.isCompleted != _isCompleted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _isCompleted = currentEvent.isCompleted;
              });
            }
          });
        }

        if (_isAmoledMode) {
          return Scaffold(
            backgroundColor: _backgroundColor,
            body: Stack(
              children: [
                // Contenido principal centrado
                Center(
                  child: GestureDetector(
                    onTap: _isCompleted ? null : () {
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
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.event.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                            color: _textColor,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildTimerWidget(),
                        const SizedBox(height: 20),
                        if (_isCompleted)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle,
                                     color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'Completado',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Botón para salir del modo AMOLED — M3EButton icon-only,
                // tamaño fijo, sobre el scrim negro.
                Positioned(
                  top: MediaQuery.of(context).padding.top + 10,
                  right: 20,
                  child: M3EButton(
                    style: M3EButtonStyle.text,
                    shape: M3EButtonShape.round,
                    decoration: M3EButtonDecoration.styleFrom(
                      backgroundColor: Colors.black.withOpacity(0.5),
                      foregroundColor: Colors.white,
                      fixedSize: const Size(40, 40),
                      padding: EdgeInsets.zero,
                    ),
                    onPressed: _toggleAmoledMode,
                    child: const Icon(Icons.light_mode, size: 22),
                  ),
                ),
                // Botón de completar (esquina inferior derecha)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 20,
                  right: 20,
                  child: AnimatedBuilder(
                    animation: _completionAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: 1.0 + (_completionAnimation.value * 0.1),
                        child: child,
                      );
                    },
                    child: M3EButton(
                      style: _isCompleted
                          ? M3EButtonStyle.filled
                          : M3EButtonStyle.text,
                      shape: M3EButtonShape.round,
                      decoration: M3EButtonDecoration.styleFrom(
                        backgroundColor: _isCompleted
                            ? Colors.green
                            : Colors.white.withOpacity(0.2),
                        foregroundColor: Colors.white,
                        fixedSize: const Size(52, 52),
                        padding: EdgeInsets.zero,
                      ),
                      onPressed: _toggleCompletion,
                      child: Icon(
                        _isCompleted ? Icons.check : Icons.check_circle_outline,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        } else {
          // El diseño original, con app bar M3E
          return Scaffold(
            backgroundColor: _backgroundColor,
            appBar: _buildAppBar(context),
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
      },
    );
  }

  // App bar real de M3E, en vez de un AppBar estándar transparente.
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return M3EAppBar.top(
      backgroundColor: Colors.transparent,
      elevation: 0,
      title: Text(
        widget.event.title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: _textColor,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      actions: [
        // Botón de completar
        M3EButton(
          style: M3EButtonStyle.text,
          shape: M3EButtonShape.round,
          decoration: M3EButtonDecoration.styleFrom(
            foregroundColor: _isCompleted ? Colors.green : _textColor,
            fixedSize: const Size(48, 48),
            padding: EdgeInsets.zero,
          ),
          onPressed: _toggleCompletion,
          child: AnimatedBuilder(
            animation: _completionAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_completionAnimation.value * 0.1),
                child: Icon(
                  _isCompleted ? Icons.check_circle : Icons.check_circle_outline,
                  size: 26,
                ),
              );
            },
          ),
        ),
        // Botón de modo AMOLED
        Stack(
          children: [
            M3EButton(
              style: M3EButtonStyle.text,
              shape: M3EButtonShape.round,
              decoration: M3EButtonDecoration.styleFrom(
                foregroundColor: _textColor,
                fixedSize: const Size(48, 48),
                padding: EdgeInsets.zero,
              ),
              onPressed: _toggleAmoledMode,
              child: Icon(
                _isAmoledMode ? Icons.light_mode : Icons.dark_mode,
                size: 22,
              ),
            ),
            if (_isAmoledMode)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 4),
      ],
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
          // NOTA: se mantiene el CustomPainter — no encontré una API
          // confirmada de círculo wavy dentro del paquete material_3_expressive
          // que ya está en pubspec (el paquete equivalente con
          // M3ECircularWavyProgressIndicator es otro paquete, m3e_progress_indicator,
          // que no está entre las dependencias del proyecto). Si lo agregan,
          // este painter se puede sustituir 1:1.
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
                  _isCompleted
                      ? 'Completado'
                      : _isRunning
                          ? 'En progreso'
                          : 'Pausado',
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

          // Overlay de completado
          if (_isCompleted)
            AnimatedBuilder(
              animation: _completionAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _completionAnimation.value * 0.3,
                  child: Container(
                    width: size,
                    height: size,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green,
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: _completionAnimation.value,
                        child: Icon(
                          Icons.check,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Botón de play/pause — M3EButton filled, forma circular fija de
        // 80x80. El "press scale" ya no se simula a mano: lo trae el
        // propio M3EButton (spring-driven press feedback).
        M3EButton(
          style: M3EButtonStyle.filled,
          shape: M3EButtonShape.round,
          decoration: M3EButtonDecoration.styleFrom(
            backgroundColor: _isCompleted ? Colors.green : _primaryColor,
            foregroundColor: _isAmoledMode ? Colors.black : Colors.white,
            fixedSize: const Size(80, 80),
            padding: EdgeInsets.zero,
            elevation: _isAmoledMode
                  ? 0.0
                : null,
          ),
          onPressed: _isCompleted
              ? null
              : () {
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
          child: Icon(
            _isCompleted
                ? Icons.check
                : _isRunning
                    ? Icons.pause
                    : Icons.play_arrow,
            size: 36,
          ),
        ),

        const SizedBox(width: 32),

        // Botón de reset — outlined, tamaño fijo 60x60.
        M3EButton.outlined(
          shape: M3EButtonShape.round,
          decoration: M3EButtonDecoration.styleFrom(
            foregroundColor: _isCompleted
                ? _primaryColor.withOpacity(0.5)
                : _primaryColor,
            side: BorderSide(
              color: _primaryColor.withOpacity(0.3),
              width: 1,
            ),
            fixedSize: const Size(60, 60),
            padding: EdgeInsets.zero,
          ),
          onPressed: _isCompleted
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  _resetTimer();
                },
          child: const Icon(Icons.restart_alt, size: 28),
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
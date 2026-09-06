// lib/widgets/event_preview_sheet.dart
import 'package:material_3_expressive/components/buttons/enums/m3e_button_enums.dart';
import 'package:material_ui/material_ui.dart';
import 'package:material_3_expressive/material_3_expressive.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/event.dart';
import 'package:myapp/utils/event_utils.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';

/// Preview sheet, reconstruido sobre los componentes reales de
/// material_3_expressive:
/// - M3EBottomSheet para el contenedor (shape, elevación y drag handle).
/// - M3EButton (filled / outlined / text) para las acciones, con su propio
///   spring press feedback y shape morphing.
/// - M3EDialog para la confirmación de borrado.
/// - Radios de esquina generosos y contenedores tonales para el resto
///   del contenido, coherentes con esos componentes.
class EventPreviewSheet extends StatelessWidget {
  final Event event;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const EventPreviewSheet({
    super.key,
    required this.event,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Entrada expresiva: overshoot sutil (spring) en vez de una curva lineal.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.9, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          alignment: Alignment.bottomCenter,
          child: child,
        );
      },
      // Componente real del paquete: maneja forma, elevación y el
      // drag handle expresivo por nosotros — ya no lo dibujamos a mano.
      child: M3EBottomSheet(
        showDragHandle: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleSection(context),

              const SizedBox(height: 20),

              if (event.description != null &&
                  event.description!.isNotEmpty)
                _buildDescriptionSection(context),

              _buildEventInfo(context),

              const SizedBox(height: 28),

              _buildActionButtons(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (event.importance != null && event.importance! > 0)
          Container(
            width: 5,
            height: 52,
            decoration: BoxDecoration(
              color: getImportanceColor(event.importance!),
              // Extremos redondeados, sin esquinas duras.
              borderRadius: BorderRadius.circular(100),
            ),
          ),

        if (event.importance != null && event.importance! > 0)
          const SizedBox(width: 14),

        if (event.category.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              // Forma tipo "squircle" expresiva en vez de un cuadrado redondeado clásico.
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              getCategoryIcon(event.category, context),
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              size: 24,
            ),
          ),

        const SizedBox(width: 14),

        Expanded(
          child: Text(
            event.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
          ),
        ),
      ],
    );
  }

  Widget _buildDescriptionSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .secondaryContainer
                .withOpacity(0.45),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).description,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                event.description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Theme.of(context).colorScheme.onSurface,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  Widget _buildEventInfo(BuildContext context) {
    return Column(
      children: [
        _buildInfoRow(
          context,
          Icons.access_time,
          AppLocalizations.of(context).time,
          _formatTimeRange(),
        ),

        const SizedBox(height: 10),

        _buildInfoRow(
          context,
          Icons.calendar_today,
          AppLocalizations.of(context).date,
          _formatDate(context),
        ),

        if (event.repeatDays.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            context,
            Icons.repeat,
            AppLocalizations.of(context).repeat,
            _getRepeatDaysText(context),
          ),
        ],

        if (event.importance != null && event.importance! > 0) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            context,
            Icons.flag_outlined,
            AppLocalizations.of(context).priority,
            _getImportanceText(context),
            color: getImportanceColor(event.importance!),
          ),
        ],

        if (event.category.isNotEmpty) ...[
          const SizedBox(height: 10),
          _buildInfoRow(
            context,
            getCategoryIcon(event.category, context),
            AppLocalizations.of(context).category,
            event.category,
          ),
        ],
      ],
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh.withOpacity(0.6),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: (color ?? Theme.of(context).colorScheme.primary)
                  .withOpacity(0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: color ?? Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        // EDITAR — M3EButton filled: spring press feedback y shape
        // morphing ya vienen resueltos por el propio componente.
        SizedBox(
          width: double.infinity,
          child: M3EButton(
            style: M3EButtonStyle.filled,
            size: M3EButtonSize.md,
            shape: M3EButtonShape.round,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context, rootNavigator: true).pop(); // FIX
              onEdit();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit_outlined, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).editEvent,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ELIMINAR — M3EButton.outlined recoloreado a "error" vía decoration.
        SizedBox(
          width: double.infinity,
          child: M3EButton.outlined(
            size: M3EButtonSize.md,
            shape: M3EButtonShape.round,
            decoration: M3EButtonDecoration.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(
                color: Theme.of(context).colorScheme.error.withOpacity(0.35),
                width: 1.5,
              ),
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context, rootNavigator: true).pop(); // FIX
              _showDeleteConfirmation(context);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.delete_outline, size: 20),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context).delete,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // CANCELAR — variante "text", de menor énfasis.
        SizedBox(
          width: double.infinity,
          child: M3EButton(
            style: M3EButtonStyle.text,
            size: M3EButtonSize.sm,
            shape: M3EButtonShape.round,
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context, rootNavigator: true).pop(); // FIX
            },
            child: Text(
              AppLocalizations.of(context).cancel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        // M3EDialog real del paquete: header, icono, divisores y acciones
        // ya siguen los tokens de forma/color de Material 3 Expressive.
        return M3EDialog(
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              Icons.warning_rounded,
              color: Theme.of(context).colorScheme.onErrorContainer,
              size: 28,
            ),
          ),
          title: AppLocalizations.of(context).deleteConfirmationTitle,
          content: Text(
            '${AppLocalizations.of(context).deleteConfirmation} "${event.title}"?',
            textAlign: TextAlign.center,
          ),
          actions: [
            M3EButton(
              style: M3EButtonStyle.text,
              size: M3EButtonSize.sm,
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Text(
                AppLocalizations.of(context).cancel,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                ),
              ),
            ),
            if (event.repeatDays.isNotEmpty)
              M3EButton(
                style: M3EButtonStyle.text,
                size: M3EButtonSize.sm,
                decoration: M3EButtonDecoration.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                onPressed: () async {
                  final eventProvider =
                      Provider.of<EventProvider>(context, listen: false);
                  await eventProvider.deleteEvent(event.id, deleteAll: true);
                  Navigator.of(context, rootNavigator: true).pop();
                },
                child: Text(
                  AppLocalizations.of(context).deleteAll,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            M3EButton(
              style: M3EButtonStyle.filled,
              size: M3EButtonSize.sm,
              decoration: M3EButtonDecoration.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              onPressed: () async {
                final eventProvider =
                    Provider.of<EventProvider>(context, listen: false);
                await eventProvider.deleteEvent(event.id, deleteAll: false);
                Navigator.of(context, rootNavigator: true).pop();
              },
              child: Text(
                AppLocalizations.of(context).delete,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatTimeRange() {
    final start = DateFormat.jm().format(event.startTime);
    if (event.endTime != null) {
      final end = DateFormat.jm().format(event.endTime!);
      return '$start - $end';
    }
    return start;
  }

  String _formatDate(BuildContext context) {
    if (event.repeatDays.isNotEmpty) {
      return AppLocalizations.of(context).repeat;
    }
    return DateFormat.yMMMMd().format(event.startTime);
  }

  String _getRepeatDaysText(BuildContext context) {
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
    return event.repeatDays.map((d) => dayNames[d]).join(', ');
  }

  String _getImportanceText(BuildContext context) {
    switch (event.importance) {
      case 1:
        return AppLocalizations.of(context).low;
      case 2:
        return AppLocalizations.of(context).moderate;
      case 3:
        return AppLocalizations.of(context).important;
      case 4:
        return AppLocalizations.of(context).veryImportant;
      default:
        return '';
    }
  }
}
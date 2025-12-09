// lib/widgets/event_preview_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:myapp/l10n/app_localizations.dart';
import 'package:myapp/models/event.dart';
import 'package:myapp/utils/event_utils.dart';
import 'package:provider/provider.dart';
import 'package:myapp/providers/event_provider.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(context),

          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleSection(context),

                const SizedBox(height: 16),

                if (event.description != null && event.description!.isNotEmpty)
                  _buildDescriptionSection(context),

                _buildEventInfo(context),

                const SizedBox(height: 24),

                _buildActionButtons(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 36,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.3),
              borderRadius: BorderRadius.circular(1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildTitleSection(BuildContext context) {
    return Row(
      children: [
        if (event.importance != null && event.importance! > 0)
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: getImportanceColor(event.importance!),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

        if (event.importance != null && event.importance! > 0)
          const SizedBox(width: 12),

        if (event.category.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              getCategoryIcon(event.category, context),
              color: Theme.of(context).colorScheme.primary,
              size: 24,
            ),
          ),

        const SizedBox(width: 12),

        Expanded(
          child: Text(
            event.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .surfaceContainer
                .withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 16,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    AppLocalizations.of(context).description,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
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
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
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

        const SizedBox(height: 12),

        _buildInfoRow(
          context,
          Icons.calendar_today,
          AppLocalizations.of(context).date,
          _formatDate(context),
        ),

        if (event.repeatDays.isNotEmpty) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            Icons.repeat,
            AppLocalizations.of(context).repeat,
            _getRepeatDaysText(context),
          ),
        ],

        if (event.importance != null && event.importance! > 0) ...[
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            Icons.flag_outlined,
            AppLocalizations.of(context).priority,
            _getImportanceText(context),
            color: getImportanceColor(event.importance!),
          ),
        ],

        if (event.category.isNotEmpty) ...[
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:
            Theme.of(context).colorScheme.surfaceContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:
                  (color ?? Theme.of(context).colorScheme.primary).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color ?? Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: color ?? Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
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
        // EDITAR
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context, rootNavigator: true).pop(); // FIX
              onEdit();
            },
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: Text(
              AppLocalizations.of(context).editEvent,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ELIMINAR
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context, rootNavigator: true).pop(); // FIX
              _showDeleteConfirmation(context);
            },
            icon: const Icon(Icons.delete_outline, size: 20),
            label: Text(
              AppLocalizations.of(context).delete,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(
                color:
                    Theme.of(context).colorScheme.error.withOpacity(0.3),
                width: 1.5,
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        // CANCELAR
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () {
              HapticFeedback.lightImpact();
              Navigator.of(context, rootNavigator: true).pop(); // FIX
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              AppLocalizations.of(context).cancel,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withOpacity(0.7),
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
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context).deleteConfirmationTitle),
            ],
          ),
          content: Text(
            '${AppLocalizations.of(context).deleteConfirmation} "${event.title}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              child: Text(
                AppLocalizations.of(context).cancel,
                style: TextStyle(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withOpacity(0.7),
                ),
              ),
            ),
            if (event.repeatDays.isNotEmpty)
              TextButton(
                onPressed: () async {
                  final eventProvider =
                      Provider.of<EventProvider>(context, listen: false);
                  await eventProvider.deleteEvent(event.id, deleteAll: true);
                  Navigator.of(context, rootNavigator: true).pop();
                },
                child: Text(
                  AppLocalizations.of(context).deleteAll,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            FilledButton(
              onPressed: () async {
                final eventProvider =
                    Provider.of<EventProvider>(context, listen: false);
                await eventProvider.deleteEvent(event.id, deleteAll: false);
                Navigator.of(context, rootNavigator: true).pop();
              },
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: Text(
                AppLocalizations.of(context).delete,
                style: const TextStyle(fontWeight: FontWeight.w600),
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

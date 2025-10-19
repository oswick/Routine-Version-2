// lib/utils/event_sorting_utils.dart
import '../models/event.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Opciones de ordenamiento disponibles
enum EventSortOption {
  timeAscending,      // Por hora (temprano → tarde)
  timeDescending,     // Por hora (tarde → temprano)
  importance,         // Por importancia (alta → baja)
  importanceAndTime,  // Por importancia, luego por hora
  title,              // Alfabético
  category,           // Por categoría
}

/// Utilidad para ordenar y agrupar eventos
class EventSortingUtils {
  // 🆕 Cargar preferencia de ordenamiento
  static Future<EventSortOption> loadSortPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final sortIndex = prefs.getInt('event_sort_option') ?? 0;
      return EventSortOption.values[sortIndex];
    } catch (e) {
      debugPrint('Error loading sort preference: $e');
      return EventSortOption.timeAscending; // Default
    }
  }

  /// Ordena eventos considerando si son repetitivos
  static List<Event> sortEvents(
    List<Event> events,
    DateTime referenceDate, {
    EventSortOption sortBy = EventSortOption.timeAscending,
  }) {
    final sortedEvents = List<Event>.from(events);

    switch (sortBy) {
      case EventSortOption.timeAscending:
        sortedEvents.sort((a, b) => _compareByTime(a, b, referenceDate));
        break;

      case EventSortOption.timeDescending:
        sortedEvents.sort((a, b) => _compareByTime(b, a, referenceDate));
        break;

      case EventSortOption.importance:
        sortedEvents.sort((a, b) => _compareByImportance(a, b));
        break;

      case EventSortOption.importanceAndTime:
        sortedEvents.sort((a, b) {
          final importanceCompare = _compareByImportance(a, b);
          if (importanceCompare != 0) return importanceCompare;
          return _compareByTime(a, b, referenceDate);
        });
        break;

      case EventSortOption.title:
        sortedEvents.sort((a, b) => a.title.compareTo(b.title));
        break;

      case EventSortOption.category:
        sortedEvents.sort((a, b) {
          final categoryCompare = a.category.compareTo(b.category);
          if (categoryCompare != 0) return categoryCompare;
          return _compareByTime(a, b, referenceDate);
        });
        break;
    }

    return sortedEvents;
  }

  /// Compara eventos por hora, considerando eventos repetitivos
  static int _compareByTime(Event a, Event b, DateTime referenceDate) {
    final timeA = _getEffectiveTime(a, referenceDate);
    final timeB = _getEffectiveTime(b, referenceDate);
    return timeA.compareTo(timeB);
  }

  /// Obtiene la hora efectiva de un evento en una fecha específica
  static DateTime _getEffectiveTime(Event event, DateTime referenceDate) {
    if (event.repeatDays.isNotEmpty) {
      // Para eventos repetitivos, usar la hora del día en la fecha de referencia
      return DateTime(
        referenceDate.year,
        referenceDate.month,
        referenceDate.day,
        event.startTime.hour,
        event.startTime.minute,
      );
    }
    return event.startTime;
  }

  /// Compara eventos por importancia (mayor = más importante)
  static int _compareByImportance(Event a, Event b) {
    final importanceA = a.importance ?? 0;
    final importanceB = b.importance ?? 0;
    return importanceB.compareTo(importanceA); // Descendente
  }

  /// Agrupa eventos por periodo del día
  static Map<TimePeriod, List<Event>> groupByTimePeriod(
    List<Event> events,
    DateTime referenceDate, {
    bool sortGroups = true, // 🆕 Parámetro para controlar ordenamiento
  }) {
    final groups = <TimePeriod, List<Event>>{
      TimePeriod.night: [],     // Madrugada
      TimePeriod.morning: [],   // Mañana
      TimePeriod.afternoon: [], // Tarde
      TimePeriod.evening: [],   // Noche
    };

    for (final event in events) {
      final period = getTimePeriod(event, referenceDate);
      groups[period]!.add(event);
    }

    // 🆕 Solo ordenar si se solicita explícitamente
    if (sortGroups) {
      for (final period in TimePeriod.values) {
        groups[period] = sortEvents(
          groups[period]!,
          referenceDate,
          sortBy: EventSortOption.timeAscending,
        );
      }
    }

    return groups;
  }

  /// Determina el periodo del día para un evento
  static TimePeriod getTimePeriod(Event event, DateTime referenceDate) {
    final effectiveTime = _getEffectiveTime(event, referenceDate);
    final hour = effectiveTime.hour;

    if (hour >= 0 && hour < 5) {
      return TimePeriod.night; // Madrugada
    } else if (hour >= 5 && hour < 12) {
      return TimePeriod.morning; // Mañana
    } else if (hour >= 12 && hour < 18) {
      return TimePeriod.afternoon; // Tarde
    } else {
      return TimePeriod.evening; // Noche
    }
  }

  /// Separa eventos pasados de futuros
  static EventsByStatus separateByStatus(
    List<Event> events,
    DateTime referenceDate,
  ) {
    final now = DateTime.now();
    final past = <Event>[];
    final current = <Event>[];
    final upcoming = <Event>[];

    for (final event in events) {
      final effectiveTime = _getEffectiveTime(event, referenceDate);
      final effectiveEndTime = event.endTime != null
          ? DateTime(
              referenceDate.year,
              referenceDate.month,
              referenceDate.day,
              event.endTime!.hour,
              event.endTime!.minute,
            )
          : effectiveTime.add(const Duration(hours: 1));

      if (effectiveEndTime.isBefore(now)) {
        past.add(event);
      } else if (effectiveTime.isAfter(now)) {
        upcoming.add(event);
      } else {
        current.add(event);
      }
    }

    return EventsByStatus(
      past: sortEvents(past, referenceDate),
      current: sortEvents(current, referenceDate),
      upcoming: sortEvents(upcoming, referenceDate),
    );
  }

  /// Agrupa eventos por importancia
  static Map<int, List<Event>> groupByImportance(
    List<Event> events,
    DateTime referenceDate,
  ) {
    final groups = <int, List<Event>>{};

    for (final event in events) {
      final importance = event.importance ?? 0;
      groups.putIfAbsent(importance, () => []);
      groups[importance]!.add(event);
    }

    // Ordenar cada grupo por tiempo
    for (final importance in groups.keys) {
      groups[importance] = sortEvents(
        groups[importance]!,
        referenceDate,
        sortBy: EventSortOption.timeAscending,
      );
    }

    return groups;
  }
}

/// Periodos del día
enum TimePeriod {
  night,      // 00:00 - 04:59 → Madrugada
  morning,    // 05:00 - 11:59 → Mañana
  afternoon,  // 12:00 - 17:59 → Tarde
  evening,    // 18:00 - 23:59 → Noche
}

extension TimePeriodExtension on TimePeriod {
  String getName(dynamic context) {
    switch (this) {
      case TimePeriod.night:
        return 'Madrugada';
      case TimePeriod.morning:
        return 'Mañana';
      case TimePeriod.afternoon:
        return 'Tarde';
      case TimePeriod.evening:
        return 'Noche';
    }
  }

  IconData getIcon() {
    switch (this) {
      case TimePeriod.night:
        return Icons.bedtime; // 🌙
      case TimePeriod.morning:
        return Icons.wb_sunny; // ☀️
      case TimePeriod.afternoon:
        return Icons.wb_twilight; // 🌇
      case TimePeriod.evening:
        return Icons.nightlight; // 🌃
    }
  }
}

/// Estructura para eventos separados por estado
class EventsByStatus {
  final List<Event> past;
  final List<Event> current;
  final List<Event> upcoming;

  EventsByStatus({
    required this.past,
    required this.current,
    required this.upcoming,
  });

  List<Event> get all => [...past, ...current, ...upcoming];
}

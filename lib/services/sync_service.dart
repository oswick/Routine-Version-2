import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';
import '../models/event_statistics.dart';
import '../models/daily_stats.dart';
import '../models/statistics_summary.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  SyncService._internal();

  final supabase = Supabase.instance.client;
  final _uuid = const Uuid();

  Future<void> init() async {
    // No se necesita inicialización adicional para Supabase
  }

  Future<List<Event>> getEvents() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await supabase
          .from('events')
          .select()
          .eq('user_id', user.id)
          .order('start_time', ascending: true);

      return (response as List).map((json) => Event.fromJson(json)).toList();
    } catch (e) {
      print('Error getting events: $e');
      return [];
    }
  }

  // Método para obtener todos los eventos de un usuario
  Future<List<Event>> getAllUserEvents(String userId) async {
    try {
      final response = await supabase
          .from('events')
          .select()
          .eq('user_id', userId)
          .order('start_time', ascending: true);

      return (response as List).map((json) => Event.fromJson(json)).toList();
    } catch (e) {
      print('Error getting user events: $e');
      return [];
    }
  }

  Future<void> saveEvent(Event event) async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      await supabase.from('events').upsert(event.toJson());
    } catch (e) {
      print('Error saving event: $e');
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      await supabase.from('events').delete().eq('id', eventId);
    } catch (e) {
      print('Error deleting event: $e');
    }
  }

  Future<void> deleteAllEventInstances(String eventId) async {
    try {
      await supabase.from('events').delete().eq('id', eventId);
    } catch (e) {
      print('Error deleting event instances: $e');
    }
  }

  // Método mejorado para generar estadísticas diarias
  Future<Map<String, dynamic>> generateDailyStatistics(String userId, DateTime date) async {
    try {
      final events = await getAllUserEvents(userId);
      final filteredEvents = await _filterEventsForDate(events, date);

      final totalEvents = filteredEvents.length;
      final completedEvents = filteredEvents.where((event) => event.isCompleted).length;
      final completionRate = totalEvents > 0 ? completedEvents / totalEvents : 0.0;

      final categoryStats = _calculateCategoryStats(filteredEvents);
      final importanceStats = _calculateImportanceStats(filteredEvents);

      return {
        'total_events': totalEvents,
        'completed_events': completedEvents,
        'completion_rate': completionRate,
        'by_category': categoryStats,
        'by_importance': importanceStats,
      };
    } catch (e) {
      print('Error generating daily statistics: $e');
      return {
        'total_events': 0,
        'completed_events': 0,
        'completion_rate': 0.0,
        'by_category': {},
        'by_importance': {},
      };
    }
  }

  // Método para generar un resumen estadístico
  Future<StatisticsSummary> generateStatisticsSummary(String userId, DateTime startDate, DateTime endDate) async {
    try {
      final events = await getAllUserEvents(userId);
      final filteredEvents = await _filterEventsForDateRange(events, startDate, endDate);

      final totalEvents = filteredEvents.length;
      final completedEvents = filteredEvents.where((event) => event.isCompleted).length;
      final completionRate = totalEvents > 0 ? completedEvents / totalEvents : 0.0;

      final categoryStats = _calculateCategoryStats(filteredEvents);
      final importanceStats = _calculateImportanceStats(filteredEvents);
      final dailyStats = await _calculateDailyStats(filteredEvents, startDate, endDate);

      // Calculating average completion time would require completed_time data
      // which we don't have in our current event model
      final averageCompletionTime = null; // Implement later if needed

      return StatisticsSummary(
        totalEvents: totalEvents,
        completedEvents: completedEvents,
        completionRate: completionRate,
        categoryStats: categoryStats,
        importanceStats: importanceStats,
        averageCompletionTime: averageCompletionTime,
        dailyStats: dailyStats,
      );
    } catch (e) {
      print('Error generating statistics summary: $e');
      return StatisticsSummary(
        totalEvents: 0,
        completedEvents: 0,
        completionRate: 0.0,
        categoryStats: {},
        importanceStats: {},
        averageCompletionTime: null,
        dailyStats: [],
      );
    }
  }

  // Métodos auxiliares para filtrar eventos y calcular estadísticas
  Future<List<Event>> _filterEventsForDate(List<Event> events, DateTime date) async {
    final filtered = <Event>[];
    final dateStr = DateFormat('yyyy-MM-dd').format(date);

    for (final event in events) {
      final startTime = event.startTime;
      final startDateStr = DateFormat('yyyy-MM-dd').format(startTime);

      // Para eventos no repetitivos
      if (event.repeatDays.isEmpty) {
        if (startDateStr == dateStr) {
          filtered.add(event);
        }
      } else {
        // Para eventos repetitivos
        final startDate = DateTime(startTime.year, startTime.month, startTime.day);
        final endDate = event.endTime != null ? DateTime(
          event.endTime!.year, event.endTime!.month, event.endTime!.day) : null;

        // Verificar si la fecha está dentro del rango
        bool isWithinRange = true;
        if (startDate.isAfter(date)) {
          isWithinRange = false;
        }
        if (endDate != null && date.isAfter(endDate)) {
          isWithinRange = false;
        }
        if (isWithinRange && event.repeatDays.contains(date.weekday % 7)) {
          // Crear una copia del evento con la fecha ajustada
          final adjustedEvent = event.copyWith(
            startTime: DateTime(
              date.year,
              date.month,
              date.day,
              startTime.hour,
              startTime.minute,
              startTime.second,
            ),
            endTime: event.endTime != null ? DateTime(
              date.year,
              date.month,
              date.day,
              event.endTime!.hour,
              event.endTime!.minute,
              event.endTime!.second,
            ) : null,
          );
          filtered.add(adjustedEvent);
        }
      }
    }

    return filtered;
  }

  Future<List<Event>> _filterEventsForDateRange(List<Event> events, DateTime startDate, DateTime endDate) async {
    final filtered = <Event>[];
    final eventMap = <String, Event>{}; // Para evitar duplicados

    for (final event in events) {
      // Para eventos no repetitivos
      if (event.repeatDays.isEmpty) {
        final eventDate = DateTime(
          event.startTime.year,
          event.startTime.month,
          event.startTime.day,
        );
        if ((eventDate.isAtSameMomentAs(startDate) || eventDate.isAfter(startDate)) &&
            (eventDate.isBefore(endDate) || eventDate.isAtSameMomentAs(endDate))) {
          final key = '${event.id}_${DateFormat('yyyy-MM-dd').format(eventDate)}';
          if (!eventMap.containsKey(key)) {
            eventMap[key] = event;
            filtered.add(event);
          }
        }
      } else {
        // Para eventos repetitivos
        final eventStartDate = DateTime(
          event.startTime.year,
          event.startTime.month,
          event.startTime.day,
        );
        final eventEndTime = event.endTime;
        final eventEndDate = eventEndTime != null ? DateTime(
          eventEndTime.year,
          eventEndTime.month,
          eventEndTime.day,
        ) : null;

        // Determinar el rango válido para este evento repetitivo
        final validStartDate = eventStartDate.isBefore(startDate) ? startDate : eventStartDate;
        final validEndDate = eventEndDate != null
            ? (eventEndDate.isAfter(endDate) ? endDate : eventEndDate)
            : endDate;

        // Verificar si hay superposición con nuestro rango de fechas
        if (validEndDate.isAfter(validStartDate.subtract(Duration(days: 1)))) {
          // Iterar a través de cada día en el rango válido
          for (var d = validStartDate;
              d.isBefore(validEndDate) || d.isAtSameMomentAs(validEndDate);
              d = d.add(Duration(days: 1))) {

            // Verificar si el día de la semana está en repeat_days
            if (event.repeatDays.contains(d.weekday % 7)) {
              // Crear una clave única para este evento en este día
              final key = '${event.id}_${DateFormat('yyyy-MM-dd').format(d)}';

              if (!eventMap.containsKey(key)) {
                // Crear una copia del evento con la fecha ajustada
                final adjustedEvent = event.copyWith(
                  startTime: DateTime(
                    d.year,
                    d.month,
                    d.day,
                    event.startTime.hour,
                    event.startTime.minute,
                    event.startTime.second,
                  ),
                  endTime: event.endTime != null ? DateTime(
                    d.year,
                    d.month,
                    d.day,
                    event.endTime!.hour,
                    event.endTime!.minute,
                    event.endTime!.second,
                  ) : null,
                  isCompleted: event.isCompleted, // Simplificación
                );

                eventMap[key] = adjustedEvent;
                filtered.add(adjustedEvent);
              }
            }
          }
        }
      }
    }

    return filtered;
  }

  Map<String, int> _calculateCategoryStats(List<Event> events) {
    final stats = <String, int>{};

    for (final event in events) {
      final category = event.category.isNotEmpty ? event.category : 'Uncategorized';
      stats[category] = (stats[category] ?? 0) + 1;
    }

    return stats;
  }

  Map<int, int> _calculateImportanceStats(List<Event> events) {
    final stats = <int, int>{};

    for (final event in events) {
      final importance = event.importance;
      if (importance != null) {
        stats[importance] = (stats[importance] ?? 0) + 1;
      }
    }

    return stats;
  }

  Future<List<DailyStats>> _calculateDailyStats(List<Event> events, DateTime startDate, DateTime endDate) async {
    final eventsByDate = <String, List<Event>>{};
    final dateFormat = DateFormat('yyyy-MM-dd');

    // Agrupar eventos por fecha
    for (final event in events) {
      final dateKey = dateFormat.format(event.startTime);

      if (!eventsByDate.containsKey(dateKey)) {
        eventsByDate[dateKey] = [];
      }
      eventsByDate[dateKey]!.add(event);
    }

    // Procesar cada fecha en el rango
    final dailyStatsList = <DailyStats>[];
    for (var d = startDate;
         d.isBefore(endDate) || d.isAtSameMomentAs(endDate);
         d = d.add(Duration(days: 1))) {
      final dateKey = dateFormat.format(d);
      final eventsForDate = eventsByDate[dateKey] ?? [];

      final totalEvents = eventsForDate.length;
      final completedEvents = eventsForDate.where((e) => e.isCompleted).length;
      final completionRate = totalEvents > 0 ? completedEvents / totalEvents : 0.0;

      dailyStatsList.add(DailyStats(
        date: d,
        totalEvents: totalEvents,
        completedEvents: completedEvents,
        completionRate: completionRate,
      ));
    }

    return dailyStatsList;
  }

  // MÉTODO CORREGIDO para guardar estadísticas en la tabla event_statistics
  Future<void> saveEventStatistics(EventStatistics stats) async {
    try {
      // Crear el mapa de datos sin el ID para que se auto-genere
      final data = {
        'event_id': stats.eventId,
        'event_title': stats.eventTitle,
        'user_id': stats.userId,
        'date': stats.date.toIso8601String().split('T')[0], // Solo la fecha
        'was_completed': stats.wasCompleted,
        'scheduled_start_time': stats.scheduledStartTime.toIso8601String(),
        'scheduled_end_time': stats.scheduledEndTime?.toIso8601String(),
        'completed_time': stats.completedTime?.toIso8601String(),
        'category': stats.category,
        'importance': stats.importance,
        'created_at': DateTime.now().toIso8601String(),
      };

      print('Intentando guardar estadísticas: $data');

      final response = await supabase
          .from('event_statistics')
          .insert(data)
          .select();

      print('Estadísticas guardadas exitosamente: $response');
    } catch (e) {
      print('Error saving event statistics: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow; // Re-lanzar el error para manejo upstream
    }
  }

  // Método para obtener estadísticas guardadas de un usuario
  Future<List<EventStatistics>> getUserEventStatistics(String userId) async {
    try {
      final response = await supabase
          .from('event_statistics')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);

      return (response as List).map((json) => EventStatistics.fromJson(json)).toList();
    } catch (e) {
      print('Error getting user event statistics: $e');
      return [];
    }
  }

  // MÉTODO COMPLETAMENTE REDISEÑADO para generar y guardar estadísticas
  Future<void> generateAndSaveStatistics(String userId, DateTime startDate, DateTime endDate) async {
    try {
      print('Iniciando generación de estadísticas para usuario: $userId');
      print('Rango de fechas: ${startDate.toIso8601String()} - ${endDate.toIso8601String()}');

      // Obtener todos los eventos del usuario
      final events = await getAllUserEvents(userId);
      print('Eventos obtenidos: ${events.length}');

      if (events.isEmpty) {
        print('No hay eventos para procesar');
        return;
      }

      // Obtener estadísticas existentes para evitar duplicados
      final existingStats = await getUserEventStatistics(userId);
      final existingKeys = existingStats.map((s) => 
        '${s.eventId}_${DateFormat('yyyy-MM-dd').format(s.date)}'
      ).toSet();

      print('Estadísticas existentes: ${existingKeys.length}');

      int savedCount = 0;
      
      // Generar estadísticas para cada día en el rango
      for (var d = startDate;
           d.isBefore(endDate.add(Duration(days: 1))); // Incluir endDate
           d = d.add(Duration(days: 1))) {

        print('Procesando fecha: ${DateFormat('yyyy-MM-dd').format(d)}');

        // Filtrar eventos para este día específico
        final dailyEvents = await _filterEventsForDate(events, d);
        
        if (dailyEvents.isEmpty) {
          print('No hay eventos para esta fecha');
          continue;
        }

        print('Eventos para esta fecha: ${dailyEvents.length}');

        // Procesar cada evento del día
        for (final event in dailyEvents) {
          final dateKey = '${event.id}_${DateFormat('yyyy-MM-dd').format(d)}';
          
          if (existingKeys.contains(dateKey)) {
            print('Estadística ya existe para: $dateKey');
            continue; // Saltar eventos que ya tienen estadísticas
          }

          // Crear estadística para este evento en este día
          final stats = EventStatistics(
            id: _uuid.v4(), // Generar ID único
            eventId: event.id,
            eventTitle: event.title,
            userId: userId,
            date: DateTime(d.year, d.month, d.day),
            wasCompleted: event.isCompleted,
            scheduledStartTime: DateTime(
              d.year, d.month, d.day,
              event.startTime.hour, event.startTime.minute, event.startTime.second
            ),
            scheduledEndTime: event.endTime != null ? DateTime(
              d.year, d.month, d.day,
              event.endTime!.hour, event.endTime!.minute, event.endTime!.second
            ) : null,
            completedTime: event.isCompleted ? DateTime(
              d.year, d.month, d.day,
              event.startTime.hour, event.startTime.minute, event.startTime.second
            ).add(Duration(minutes: 30)) : null, // Tiempo estimado de completado
            category: event.category.isNotEmpty ? event.category : 'Uncategorized',
            importance: event.importance,
            createdAt: DateTime.now(),
          );

          try {
            // Guardar las estadísticas
            await saveEventStatistics(stats);
            savedCount++;
            print('Estadística guardada para evento: ${event.title} en fecha: ${DateFormat('yyyy-MM-dd').format(d)}');
          } catch (e) {
            print('Error guardando estadística para evento ${event.id}: $e');
            // Continuar con el siguiente evento
          }
        }
      }

      print('Proceso completado. Estadísticas guardadas: $savedCount');
    } catch (e) {
      print('Error generating and saving statistics: $e');
      print('Stack trace: ${StackTrace.current}');
      rethrow;
    }
  }

  // NUEVO MÉTODO: Guardar estadística individual cuando se completa un evento
  Future<void> saveEventCompletionStatistic(Event event, DateTime completionDate) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        print('Usuario no autenticado');
        return;
      }

      // Verificar si ya existe esta estadística
      final dateKey = DateFormat('yyyy-MM-dd').format(completionDate);
      final existing = await supabase
          .from('event_statistics')
          .select('id')
          .eq('event_id', event.id)
          .eq('user_id', user.id)
          .eq('date', dateKey)
          .maybeSingle();

      if (existing != null) {
        print('Estadística ya existe para este evento en esta fecha');
        return;
      }

      final stats = EventStatistics(
        id: _uuid.v4(),
        eventId: event.id,
        eventTitle: event.title,
        userId: user.id,
        date: DateTime(completionDate.year, completionDate.month, completionDate.day),
        wasCompleted: event.isCompleted,
        scheduledStartTime: event.startTime,
        scheduledEndTime: event.endTime,
        completedTime: event.isCompleted ? DateTime.now() : null,
        category: event.category.isNotEmpty ? event.category : 'Uncategorized',
        importance: event.importance,
        createdAt: DateTime.now(),
      );

      await saveEventStatistics(stats);
      print('Estadística de completado guardada para: ${event.title}');
    } catch (e) {
      print('Error saving completion statistic: $e');
    }
  }

  // NUEVO MÉTODO: Obtener estadísticas resumidas por período
  Future<Map<String, dynamic>> getStatisticsSummary(String userId, DateTime startDate, DateTime endDate) async {
    try {
      final stats = await supabase
          .from('event_statistics')
          .select()
          .eq('user_id', userId)
          .gte('date', DateFormat('yyyy-MM-dd').format(startDate))
          .lte('date', DateFormat('yyyy-MM-dd').format(endDate));

      final totalEvents = stats.length;
      final completedEvents = stats.where((s) => s['was_completed'] == true).length;
      final completionRate = totalEvents > 0 ? completedEvents / totalEvents : 0.0;

      // Estadísticas por categoría
      final categoryStats = <String, Map<String, int>>{};
      for (final stat in stats) {
        final category = stat['category'] as String;
        if (!categoryStats.containsKey(category)) {
          categoryStats[category] = {'total': 0, 'completed': 0};
        }
        categoryStats[category]!['total'] = categoryStats[category]!['total']! + 1;
        if (stat['was_completed'] == true) {
          categoryStats[category]!['completed'] = categoryStats[category]!['completed']! + 1;
        }
      }

      return {
        'total_events': totalEvents,
        'completed_events': completedEvents,
        'completion_rate': completionRate,
        'category_stats': categoryStats,
        'period_start': startDate.toIso8601String(),
        'period_end': endDate.toIso8601String(),
      };
    } catch (e) {
      print('Error getting statistics summary: $e');
      return {
        'total_events': 0,
        'completed_events': 0,
        'completion_rate': 0.0,
        'category_stats': {},
      };
    }
  }}
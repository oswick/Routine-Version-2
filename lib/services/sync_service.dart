import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;

  SyncService._internal();

  final supabase = Supabase.instance.client;

  Future<void> init() async {
    // Ya no necesitamos inicializar Hive
  }

  Future<List<Event>> getEvents() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await supabase
          .from('events')
          .select()
          .eq('user_id', user.id);

      return (response as List).map((json) => Event.fromJson(json)).toList();
    } catch (e) {
      print('Error getting events: $e');
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
}

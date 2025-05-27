import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/event.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  
  factory SyncService() => _instance;
  
  SyncService._internal();

  final supabase = Supabase.instance.client;
  late Box<Event> _eventBox;
  
  Future<void> init() async {
    await Hive.initFlutter();
    Hive.registerAdapter(EventAdapter());
    _eventBox = await Hive.openBox<Event>('events');
  }

  Future<void> syncEvents() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) return;

    // Get local events
    final localEvents = _eventBox.values.toList();
    
    // Get remote events
    final response = await supabase
        .from('events')
        .select()
        .eq('user_id', user.id);
    
    final remoteEvents = (response as List)
        .map((json) => Event.fromJson(json))
        .toList();

    // Sync strategy
    for (final remoteEvent in remoteEvents) {
      final localEvent = localEvents.firstWhere(
        (e) => e.id == remoteEvent.id,
        orElse: () => remoteEvent,
      );

      if (remoteEvent.lastModified.isAfter(localEvent.lastModified)) {
        await _eventBox.put(remoteEvent.id, remoteEvent);
      }
    }

    // Upload local changes
    for (final localEvent in localEvents) {
      final remoteEvent = remoteEvents.firstWhere(
        (e) => e.id == localEvent.id,
        orElse: () => localEvent,
      );

      if (localEvent.lastModified.isAfter(remoteEvent.lastModified)) {
        await supabase
            .from('events')
            .upsert(localEvent.toJson());
      }
    }
  }

  Future<List<Event>> getEvents() async {
    return _eventBox.values.toList();
  }

  Future<void> saveEvent(Event event) async {
    await _eventBox.put(event.id, event);
    
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await supabase
          .from('events')
          .upsert(event.toJson());
    }
  }

  Future<void> deleteEvent(String eventId) async {
    await _eventBox.delete(eventId);
    
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      await supabase
          .from('events')
          .delete()
          .eq('id', eventId);
    }
  }
}
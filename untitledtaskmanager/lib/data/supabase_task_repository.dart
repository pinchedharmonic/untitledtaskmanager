import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

/// The app's cloud data boundary.
///
/// This class intentionally contains no screen state. The UI should only show
/// a change after the returned server row has been received successfully.
class SupabaseTaskRepository {
  SupabaseTaskRepository(this._client);

  final SupabaseClient _client;
  Duration _serverClockOffset = Duration.zero;

  DateTime get now => DateTime.now().add(_serverClockOffset);

  String get currentUserId {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Please sign in first.');
    return user.id;
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) => _client.auth.signInWithPassword(email: email, password: password);

  Future<AuthResponse> createAccount({
    required String email,
    required String password,
  }) => _client.auth.signUp(email: email, password: password);

  Future<void> signOut() => _client.auth.signOut();

  /// Estimates the difference between the device clock and Supabase's clock.
  /// All clients then display a running timer from the same UTC time base.
  Future<void> syncServerClock() async {
    final before = DateTime.now().toUtc();
    final serverValue = await _client.rpc('server_now');
    final after = DateTime.now().toUtc();
    final midpoint = before.add(
      Duration(microseconds: after.difference(before).inMicroseconds ~/ 2),
    );
    final serverNow = DateTime.parse(serverValue as String).toUtc();
    _serverClockOffset = serverNow.difference(midpoint);
  }

  /// Emits when another client changes either table. Reload rows after an
  /// event; the event payload itself is only a signal, not the source of truth.
  Stream<void> watchChanges() {
    final ownerId = currentUserId;
    final controller = StreamController<void>();
    final channel = _client
        .channel('task-sync-$ownerId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'task_lists',
          callback: (_) => controller.add(null),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'tasks',
          callback: (_) => controller.add(null),
        )
        .subscribe();

    controller.onCancel = () async {
      await _client.removeChannel(channel);
    };
    return controller.stream;
  }

  Future<List<Map<String, dynamic>>> loadLists() async {
    await _client.rpc('ensure_default_task_lists');
    final rows = await _client
        .from('task_lists')
        .select('id, name, icon_key, sort_order, created_at, updated_at')
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<List<Map<String, dynamic>>> loadTasks() async {
    final rows = await _client
        .from('tasks')
        .select(
          'id, list_id, title, priority, sort_order, completed_at, '
          'elapsed_seconds, timer_started_at, created_at, updated_at',
        )
        .order('sort_order');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<Map<String, dynamic>> createList({
    required String id,
    required String name,
    required String iconKey,
  }) async {
    final row = await _client
        .from('task_lists')
        .insert({'id': id, 'name': name, 'icon_key': iconKey})
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> updateList({
    required String id,
    required String name,
    required String iconKey,
  }) async {
    final row = await _client
        .from('task_lists')
        .update({'name': name, 'icon_key': iconKey})
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<void> deleteList(String id) async {
    await _client.from('task_lists').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> createTask({
    required String id,
    required String listId,
    required String title,
    required int priority,
  }) async {
    final row = await _client
        .from('tasks')
        .insert({
          'id': id,
          'list_id': listId,
          'title': title,
          'priority': priority,
        })
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> updateTask({
    required String id,
    required String title,
    required int priority,
  }) async {
    final row = await _client
        .from('tasks')
        .update({'title': title, 'priority': priority})
        .eq('id', id)
        .select()
        .single();
    return Map<String, dynamic>.from(row);
  }

  Future<Map<String, dynamic>> startTimer(String taskId) =>
      _taskAction('start_task_timer', taskId);

  Future<Map<String, dynamic>> pauseTimer(String taskId) =>
      _taskAction('pause_task_timer', taskId);

  Future<Map<String, dynamic>> setCompleted(
    String taskId, {
    required bool completed,
  }) async {
    final row = await _client.rpc(
      'set_task_completed',
      params: {'p_task_id': taskId, 'p_completed': completed},
    );
    return Map<String, dynamic>.from(row as Map);
  }

  Future<void> deleteTask(String id) async {
    await _client.from('tasks').delete().eq('id', id);
  }

  Future<Map<String, dynamic>> _taskAction(
    String function,
    String taskId,
  ) async {
    final row = await _client.rpc(function, params: {'p_task_id': taskId});
    return Map<String, dynamic>.from(row as Map);
  }
}

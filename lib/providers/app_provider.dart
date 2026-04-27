import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';

enum ExtractionStatus { idle, loading, success, error }

class AppProvider extends ChangeNotifier {
  final ApiService api;
  final StorageService storage;

  List<ScheduleEvent> events = [];
  List<Todo> todos = [];
  ExtractionStatus status = ExtractionStatus.idle;
  String? errorMessage;
  String? pendingFilePath;

  AppProvider({required this.api, required this.storage});

  // ── Load & sync ────────────────────────────────────────────────────────────

  Future<void> loadLocal() async {
    events = await storage.getEvents();
    todos = await storage.getTodos();
    notifyListeners();
    // Sync from server in the background; update UI when done
    unawaited(_syncFromServer());
  }

  Future<void> _syncFromServer() async {
    try {
      final result = await api.getItems();
      await storage.replaceAll(result.events, result.todos);
      events = result.events;
      todos = result.todos;
      notifyListeners();
    } catch (_) {
      // Keep local cache on network error
    }
  }

  // ── Extraction ─────────────────────────────────────────────────────────────

  Future<bool> extractFromText(String text) =>
      _extract(() => api.extractFromText(text));

  Future<bool> extractFromImage(File file) =>
      _extract(() => api.extractFromImage(file));

  Future<bool> extractFromFile(File file, String type) =>
      _extract(() => api.extractFromFile(file, type));

  Future<bool> _extract(Future<ExtractionResult> Function() fn) async {
    status = ExtractionStatus.loading;
    errorMessage = null;
    notifyListeners();
    try {
      await fn();
      // Server already saved the new items; sync full list to stay consistent
      await _syncFromServer();
      status = ExtractionStatus.success;
      notifyListeners();
      return true;
    } catch (e) {
      errorMessage = e.toString();
      status = ExtractionStatus.error;
      notifyListeners();
      return false;
    }
  }

  // ── Event mutations (server-first) ─────────────────────────────────────────

  Future<void> updateEvent(ScheduleEvent event) async {
    final updated = await api.updateEventApi(event);
    await storage.updateEvent(updated);
    _replaceEvent(updated);
  }

  Future<void> deleteEvent(int id) async {
    await api.deleteEventApi(id);
    await storage.deleteEvent(id);
    events = events.where((e) => e.id != id).toList();
    notifyListeners();
  }

  Future<void> toggleEventPin(int id, bool isPinned) async {
    await api.pinEventApi(id, isPinned);
    await storage.updateEventPinned(id, isPinned);
    _replaceEvent(events.firstWhere((e) => e.id == id).copyWith(isPinned: isPinned));
    _sortEvents();
  }

  // ── Todo mutations (server-first) ──────────────────────────────────────────

  Future<void> updateTodo(Todo todo) async {
    final updated = await api.updateTodoApi(todo);
    await storage.updateTodo(updated);
    _replaceTodo(updated);
  }

  Future<void> deleteTodo(int id) async {
    await api.deleteTodoApi(id);
    await storage.deleteTodo(id);
    todos = todos.where((t) => t.id != id).toList();
    notifyListeners();
  }

  Future<void> toggleTodo(int id, bool isDone) async {
    await api.toggleTodoDoneApi(id, isDone);
    await storage.updateTodoDone(id, isDone);
    _replaceTodo(todos.firstWhere((t) => t.id == id).copyWith(isDone: isDone));
    _sortTodos();
  }

  Future<void> toggleTodoPin(int id, bool isPinned) async {
    await api.pinTodoApi(id, isPinned);
    await storage.updateTodoPinned(id, isPinned);
    _replaceTodo(todos.firstWhere((t) => t.id == id).copyWith(isPinned: isPinned));
    _sortTodos();
  }

  // ── Clear all ──────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await storage.clearAll();
    events = [];
    todos = [];
    notifyListeners();
  }

  // ── Pending file (iOS share) ───────────────────────────────────────────────

  void setPendingFile(String path) {
    pendingFilePath = path;
    notifyListeners();
  }

  void clearPendingFile() {
    pendingFilePath = null;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  void _replaceEvent(ScheduleEvent updated) {
    final idx = events.indexWhere((e) => e.id == updated.id);
    if (idx != -1) {
      final list = List<ScheduleEvent>.from(events);
      list[idx] = updated;
      events = list;
      notifyListeners();
    }
  }

  void _replaceTodo(Todo updated) {
    final idx = todos.indexWhere((t) => t.id == updated.id);
    if (idx != -1) {
      final list = List<Todo>.from(todos);
      list[idx] = updated;
      todos = list;
      notifyListeners();
    }
  }

  void _sortEvents() {
    events = List<ScheduleEvent>.from(events)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        final dc = (a.date ?? '').compareTo(b.date ?? '');
        return dc != 0 ? dc : (a.time ?? '').compareTo(b.time ?? '');
      });
    notifyListeners();
  }

  void _sortTodos() {
    todos = List<Todo>.from(todos)
      ..sort((a, b) {
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        return (a.deadline ?? '').compareTo(b.deadline ?? '');
      });
    notifyListeners();
  }
}

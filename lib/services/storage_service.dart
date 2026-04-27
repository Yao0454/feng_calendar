import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/models.dart';

class StorageService {
  static Database? _db;

  static Future<void> init() async {
    _db = await openDatabase(
      join(await getDatabasesPath(), 'schedule.db'),
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            date TEXT,
            time TEXT,
            location TEXT,
            notes TEXT,
            is_pinned INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE todos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            deadline TEXT,
            priority TEXT DEFAULT 'medium',
            notes TEXT,
            is_done INTEGER DEFAULT 0,
            is_pinned INTEGER DEFAULT 0,
            created_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          // Safe add: catches error if column already exists from a partial
          // earlier migration attempt.
          for (final table in ['events', 'todos']) {
            try {
              await db.execute(
                  'ALTER TABLE $table ADD COLUMN is_pinned INTEGER DEFAULT 0');
            } catch (_) {}
          }
        }
      },
    );
  }

  static Database get db {
    assert(_db != null, 'StorageService.init() must be called before use');
    return _db!;
  }

  Future<List<ScheduleEvent>> getEvents() async {
    final rows = await db.query('events',
        orderBy: 'is_pinned DESC, date ASC, time ASC');
    return rows.map(ScheduleEvent.fromDbMap).toList();
  }

  Future<int> insertEvent(ScheduleEvent event) async {
    return db.insert('events', event.toDbMap());
  }

  Future<void> insertEvents(List<ScheduleEvent> events) async {
    final batch = db.batch();
    for (final e in events) {
      batch.insert('events', e.toDbMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateEvent(ScheduleEvent event) async {
    await db.update(
      'events',
      event.toDbMap(),
      where: 'id = ?',
      whereArgs: [event.id],
    );
  }

  Future<void> updateEventPinned(int id, bool isPinned) async {
    await db.update(
      'events',
      {'is_pinned': isPinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteEvent(int id) async {
    await db.delete('events', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearEvents() async {
    await db.delete('events');
  }

  Future<List<Todo>> getTodos() async {
    final rows = await db.query('todos',
        orderBy: 'is_pinned DESC, is_done ASC, deadline ASC');
    return rows.map(Todo.fromDbMap).toList();
  }

  Future<int> insertTodo(Todo todo) async {
    return db.insert('todos', todo.toDbMap());
  }

  Future<void> insertTodos(List<Todo> todos) async {
    final batch = db.batch();
    for (final t in todos) {
      batch.insert('todos', t.toDbMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateTodo(Todo todo) async {
    await db.update(
      'todos',
      todo.toDbMap(),
      where: 'id = ?',
      whereArgs: [todo.id],
    );
  }

  Future<void> updateTodoDone(int id, bool isDone) async {
    await db.update(
      'todos',
      {'is_done': isDone ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateTodoPinned(int id, bool isPinned) async {
    await db.update(
      'todos',
      {'is_pinned': isPinned ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTodo(int id) async {
    await db.delete('todos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTodos() async {
    await db.delete('todos');
  }

  /// Replace the entire local cache with server data (used for cloud sync).
  Future<void> replaceAll(List<ScheduleEvent> newEvents, List<Todo> newTodos) async {
    final batch = db.batch();
    batch.delete('events');
    batch.delete('todos');
    for (final e in newEvents) {
      batch.insert('events', e.toDbMap());
    }
    for (final t in newTodos) {
      batch.insert('todos', t.toDbMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearAll() async {
    await clearEvents();
    await clearTodos();
  }
}

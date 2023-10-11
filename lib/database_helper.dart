import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {

  static Database? _database;
  static const String _dbName = 'taskline.db';

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String databasesPath = await getDatabasesPath();
    String path = join(databasesPath, _dbName);
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create your table here
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY,
        task_id INTEGER,
        user_id INTEGER,
        title TEXT,
        status INTEGER,
        priority INTEGER,
        created_at INTEGER,
        updated_at INTEGER
      )
    ''');
  }

  Future<int> insertData(Map<String, dynamic> data, String tableName) async {
    final db = await database;
    // Check if the task_id already exists
    final int taskId = data['task_id'];
    List<Map<String, dynamic>> existingTasks = await db.query(
      tableName,
      where: 'task_id = ?',
      whereArgs: [taskId],
      limit: 1,
    );

    if (existingTasks.isNotEmpty) {
      // Task with the same task_id exists, perform an update
      return await db.update(
        tableName,
        data,
        where: 'task_id = ?',
        whereArgs: [taskId],
      );
    } else {
      // Task with the given task_id does not exist, insert a new row
      return await db.insert(tableName, data);
    }
  }

  Future<List<Map<String, dynamic>>> getData(userId, status) async {
    final db = await database;
    final userIdValue = await userId; // Await the Future<String> userId to get its actual value
    final subQuery = await db.rawQuery('''
    SELECT MAX(id) as max_id
    FROM tasks
    WHERE user_id = $userIdValue AND status = $status
    GROUP BY task_id
  ''');
    return await db.query('tasks', where: 'id IN (${subQuery.map((result) => result['max_id']).join(",")})', orderBy: 'priority, task_id');
  }

}
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  // Singleton: Para asegurarnos de que solo hay una instancia
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  factory DBHelper() {
    return _instance;
  }

  DBHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'running_league.db');
    return await openDatabase(
      path,
      version: 1, // Si cambias la tabla, desinstala la app o sube esto a 2
      onCreate: (db, version) {
        return db.execute(
          '''
          CREATE TABLE runs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date TEXT,
            duration INTEGER,
            distance REAL,
            avgSpeed TEXT,
            bestSplitTime TEXT,
            bestSplitRange TEXT,
            bestRollingTime TEXT,
            bestRollingRange TEXT
          )
          ''',
        );
      },
    );
  }

  // --- GUARDAR CARRERA ---
  Future<void> insertRun(Map<String, dynamic> run) async {
    final db = await database;
    await db.insert(
      'runs',
      run,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // --- OBTENER HISTORIAL ---
  Future<List<Map<String, dynamic>>> getRuns() async {
    final db = await database;
    // Ordenado por ID descendente (la última carrera sale la primera)
    return await db.query('runs', orderBy: 'id DESC');
  }

  // --- FUNCIÓN 3: ELIMINAR UNA CARRERA ---
  Future<void> deleteRun(int id) async {
    final db = await database;
    // Borramos de la tabla 'runs' donde la columna 'id' coincida con el que pasamos
    await db.delete(
      'runs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
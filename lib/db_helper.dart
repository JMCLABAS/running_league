import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  factory DBHelper() => _instance;

  DBHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'running_league.db');
    return await openDatabase(
      path,
      version: 2, // Subimos la versión por si acaso
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE runs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userId TEXT, 
            date TEXT,
            duration INTEGER,
            distance REAL,
            avgSpeed TEXT,
            bestSplitTime TEXT,
            bestSplitRange TEXT,
            bestRollingTime TEXT,
            bestRollingRange TEXT
          )
        ''');
      },
      // Esto borra la tabla vieja si detecta una versión nueva (útil para desarrollo)
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute("DROP TABLE IF EXISTS runs");
          await db.execute('''
            CREATE TABLE runs(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              userId TEXT,
              date TEXT,
              duration INTEGER,
              distance REAL,
              avgSpeed TEXT,
              bestSplitTime TEXT,
              bestSplitRange TEXT,
              bestRollingTime TEXT,
              bestRollingRange TEXT
            )
          ''');
        }
      },
    );
  }

  // Guardar carrera (ahora requiere userId en el mapa)
  Future<void> insertRun(Map<String, dynamic> run) async {
    final db = await database;
    await db.insert(
      'runs',
      run,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Obtener SOLO las carreras del usuario actual
  Future<List<Map<String, dynamic>>> getUserRuns(String userId) async {
    final db = await database;
    // El "WHERE userId = ?" es el filtro de seguridad
    return await db.query(
      'runs',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'date DESC', // Las más recientes primero
    );
  }
  
  // Borrar una carrera específica
  Future<void> deleteRun(int id) async {
    final db = await database;
    await db.delete(
      'runs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
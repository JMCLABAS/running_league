import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Gestor de persistencia local (SQLite).
/// Implementa el patrón Singleton para garantizar una única instancia de conexión
/// a la base de datos durante el ciclo de vida de la aplicación.
class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  static Database? _database;

  factory DBHelper() => _instance;

  DBHelper._internal();

  /// Accesor asíncrono que asegura la inicialización perezosa (lazy loading) de la DB.
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'running_league.db');
    
    return await openDatabase(
      path,
      version: 2, 
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
      // Gestión de Migraciones:
      // Estrategia de "Reinicio Destructivo" para la versión 2.
      // En producción, esto debería reemplazarse por scripts ALTER TABLE para preservar datos.
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

  /// Persiste una nueva actividad localmente.
  /// Utiliza `ConflictAlgorithm.replace` para manejar duplicados como UPSERT.
  Future<void> insertRun(Map<String, dynamic> run) async {
    final db = await database;
    await db.insert(
      'runs',
      run,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Recupera el historial de carreras filtrado por usuario.
  /// Implementa aislamiento de datos a nivel de consulta para soportar múltiples sesiones en el mismo dispositivo.
  Future<List<Map<String, dynamic>>> getUserRuns(String userId) async {
    final db = await database;
    
    return await db.query(
      'runs',
      where: 'userId = ?', // Filtro de aislamiento por tenant/usuario
      whereArgs: [userId],
      orderBy: 'date DESC',
    );
  }
  
  /// Elimina un registro específico basado en su clave primaria.
  Future<void> deleteRun(int id) async {
    final db = await database;
    await db.delete(
      'runs',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
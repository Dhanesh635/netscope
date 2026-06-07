import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  DatabaseHelper._();

  static final DatabaseHelper instance = DatabaseHelper._();

  static const _databaseName = 'netscope.db';
  static const _databaseVersion = 3;

  static const measurementsTable = 'measurements';
  static const sessionsTable = 'sessions';

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasesPath = await getDatabasesPath();
    final databasePath = path.join(databasesPath, _databaseName);

    return openDatabase(
      databasePath,
      version: _databaseVersion,
      onConfigure: (db) async {
        // Enable WAL mode so the background isolate and foreground isolate can
        // write concurrently without locking each other out. Without WAL,
        // Android's default journal mode serialises all writes and the
        // background isolate's INSERT can be silently rejected under contention.
        await db.rawQuery('PRAGMA journal_mode = WAL');
        // Add a busy timeout to wait for locks instead of failing immediately.
        await db.rawQuery('PRAGMA busy_timeout = 5000');
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $sessionsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        started_at INTEGER NOT NULL,
        ended_at INTEGER
      )
    ''');

    await db.execute('''
      CREATE TABLE $measurementsTable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        device_id TEXT NOT NULL,
        device_make TEXT NOT NULL,
        device_model TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        rsrp REAL NOT NULL,
        rsrq REAL NOT NULL,
        sinr REAL NOT NULL,
        download REAL NOT NULL,
        upload REAL NOT NULL,
        pci INTEGER NOT NULL,
        carrier TEXT NOT NULL,
        network_type TEXT NOT NULL,
        velocity REAL NOT NULL,
        FOREIGN KEY (session_id) REFERENCES $sessionsTable (id) ON DELETE CASCADE
      )
    ''');

    await db.execute(
      'CREATE INDEX idx_measurements_session_id ON $measurementsTable(session_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Check if columns exist to avoid errors on some partial setups
      final columns = await db.rawQuery(
        'PRAGMA table_info($measurementsTable)',
      );
      
      final hasCarrier = columns.any((column) => column['name'] == 'carrier');
      if (!hasCarrier) {
        await db.execute(
          'ALTER TABLE $measurementsTable ADD COLUMN carrier TEXT NOT NULL DEFAULT "Unknown"',
        );
      }
      
      final hasNetworkType = columns.any((column) => column['name'] == 'network_type');
      if (!hasNetworkType) {
        await db.execute(
          'ALTER TABLE $measurementsTable ADD COLUMN network_type TEXT NOT NULL DEFAULT "Unknown"',
        );
      }
      
      final hasVelocity = columns.any((column) => column['name'] == 'velocity');
      if (!hasVelocity) {
        await db.execute(
          'ALTER TABLE $measurementsTable ADD COLUMN velocity REAL NOT NULL DEFAULT 0.0',
        );
      }
    }

    if (oldVersion < 3) {
      final columns = await db.rawQuery(
        'PRAGMA table_info($measurementsTable)',
      );
      
      final hasDeviceId = columns.any((column) => column['name'] == 'device_id');
      if (!hasDeviceId) {
        await db.execute(
          'ALTER TABLE $measurementsTable ADD COLUMN device_id TEXT NOT NULL DEFAULT ""',
        );
      }
      
      final hasDeviceMake = columns.any((column) => column['name'] == 'device_make');
      if (!hasDeviceMake) {
        await db.execute(
          'ALTER TABLE $measurementsTable ADD COLUMN device_make TEXT NOT NULL DEFAULT ""',
        );
      }
      
      final hasDeviceModel = columns.any((column) => column['name'] == 'device_model');
      if (!hasDeviceModel) {
        await db.execute(
          'ALTER TABLE $measurementsTable ADD COLUMN device_model TEXT NOT NULL DEFAULT ""',
        );
      }
    }
  }
}

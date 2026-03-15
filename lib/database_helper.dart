import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// A single medication reminder stored in SQLite.
class Medication {
  final int? id;
  final String name;
  final int hour;
  final int minute;
  final bool isActive;

  const Medication({
    this.id,
    required this.name,
    required this.hour,
    required this.minute,
    this.isActive = true,
  });

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'hour': hour,
        'minute': minute,
        'isActive': isActive ? 1 : 0,
      };

  factory Medication.fromMap(Map<String, dynamic> map) => Medication(
        id: map['id'] as int?,
        name: map['name'] as String,
        hour: map['hour'] as int,
        minute: map['minute'] as int,
        isActive: (map['isActive'] as int) == 1,
      );

  Medication copyWith({
    int? id,
    String? name,
    int? hour,
    int? minute,
    bool? isActive,
  }) =>
      Medication(
        id: id ?? this.id,
        name: name ?? this.name,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        isActive: isActive ?? this.isActive,
      );
}

/// Singleton SQLite helper for [Medication] persistence.
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mamie_meds.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE medications (
            id      INTEGER PRIMARY KEY AUTOINCREMENT,
            name    TEXT    NOT NULL,
            hour    INTEGER NOT NULL,
            minute  INTEGER NOT NULL,
            isActive INTEGER NOT NULL DEFAULT 1
          )
        ''');
      },
    );
  }

  Future<int> insertMedication(Medication med) async {
    final db = await database;
    return db.insert('medications', med.toMap());
  }

  Future<List<Medication>> getMedications() async {
    final db = await database;
    final maps = await db.query('medications', orderBy: 'id ASC');
    return maps.map(Medication.fromMap).toList();
  }

  Future<void> updateMedication(Medication med) async {
    final db = await database;
    await db.update(
      'medications',
      med.toMap(),
      where: 'id = ?',
      whereArgs: [med.id],
    );
  }

  Future<void> deleteMedication(int id) async {
    final db = await database;
    await db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }
}

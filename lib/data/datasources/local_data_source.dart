import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/database/database_helper.dart';

class LocalDataSource {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<int> saveRecord(String table, Map<String, dynamic> data, {bool isFromRemote = false}) async {
    if (kIsWeb) return 0; // SQLite (sqflite) is not supported on Web

    final db = await _dbHelper.database;
    final Map<String, dynamic> record = Map.of(data);
    
    if (!isFromRemote) {
      record['is_synced'] = 0;
    } else {
      record['is_synced'] = 1;
    }
    
    final String idField = _getIdField(table);
    final idValue = record[idField];
    
    if (idValue == null) {
      return await db.insert(table, record);
    }

    final existing = await db.query(table, where: '$idField = ?', whereArgs: [idValue]);
    
    if (existing.isNotEmpty) {
      return await db.update(table, record, where: '$idField = ?', whereArgs: [idValue]);
    } else {
      return await db.insert(table, record);
    }
  }

  Future<List<Map<String, dynamic>>> getUnsyncedRecords(String table) async {
    if (kIsWeb) return [];
    final db = await _dbHelper.database;
    return await db.query(table, where: 'is_synced = ?', whereArgs: [0]);
  }

  Future<void> markAsSynced(String table, dynamic id) async {
    if (kIsWeb) return;
    final db = await _dbHelper.database;
    final String idField = _getIdField(table);
    await db.update(table, {'is_synced': 1}, where: '$idField = ?', whereArgs: [id]);
  }

  String _getIdField(String table) {
    if (table == 'children') return 'child_id';
    if (table == 'users') return 'uid';
    return 'id'; 
  }
}

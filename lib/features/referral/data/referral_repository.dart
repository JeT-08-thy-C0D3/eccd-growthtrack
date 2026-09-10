import '../../../core/database/database_helper.dart';
import '../domain/referral_model.dart';

abstract class ReferralRepository {
  Future<int> addReferral(ReferralModel referral);
  Future<List<ReferralModel>> getReferralsByChild(String childId);
  Future<List<Map<String, dynamic>>> getAllReferrals();
  Future<int> updateReferral(ReferralModel referral);
  Future<int> deleteReferral(int id);
}

class ReferralRepositoryImpl implements ReferralRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  @override
  Future<int> addReferral(ReferralModel referral) async {
    final db = await _dbHelper.database;
    return await db.insert('referrals', referral.toMap());
  }

  @override
  Future<List<ReferralModel>> getReferralsByChild(String childId) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'referrals',
      where: 'child_id = ?',
      whereArgs: [childId],
      orderBy: 'referral_date DESC',
    );
    return maps.map((map) => ReferralModel.fromMap(map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllReferrals() async {
    final db = await _dbHelper.database;
    return await db.rawQuery('''
      SELECT r.*, c.first_name, c.last_name
      FROM referrals r
      JOIN children c ON r.child_id = c.child_id
      ORDER BY r.referral_date DESC
    ''');
  }

  @override
  Future<int> updateReferral(ReferralModel referral) async {
    final db = await _dbHelper.database;
    return await db.update(
      'referrals',
      referral.toMap(),
      where: 'id = ?',
      whereArgs: [referral.id],
    );
  }

  @override
  Future<int> deleteReferral(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      'referrals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}

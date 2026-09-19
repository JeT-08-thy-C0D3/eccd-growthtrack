import 'package:intl/intl.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/utils/audit_logger.dart';
import '../domain/referral_model.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../data/datasources/remote_data_source.dart';
import '../../../core/network/connectivity_service.dart';

abstract class ReferralRepository {
  Future<int> addReferral(ReferralModel referral);
  Future<List<ReferralModel>> getReferralsByChild(String childId);
  Future<List<Map<String, dynamic>>> getAllReferrals();
  Future<int> updateReferral(ReferralModel referral);
  Future<int> deleteReferral(int id);
}

class ReferralRepositoryImpl implements ReferralRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final LocalDataSource _local = LocalDataSource();
  final RemoteDataSource _remote = RemoteDataSource();
  final ConnectivityService _connectivity = ConnectivityService();

  @override
  Future<int> addReferral(ReferralModel referral) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final newReferral = referral.copyWith(
      updatedAt: now,
      isSynced: await _connectivity.isOnline,
    );

    // 1. Save Locally
    final id = await _local.saveRecord('referrals', newReferral.toMap());
    
    // 2. Sync to Cloud if online
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('referrals', id.toString(), newReferral.toMap());
        await _local.markAsSynced('referrals', id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    // 3. Log Action
    await AuditLogger.log(
      action: 'Create Referral',
      module: 'Referral',
      description: 'Created referral for concern: ${referral.concern}.',
    );
    
    return id;
  }

  @override
  Future<List<ReferralModel>> getReferralsByChild(String childId) async {
    final List<Map<String, dynamic>> maps = await _dbHelper.getReferralsByChild(childId);
    return maps.map((map) => ReferralModel.fromMap(map)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllReferrals() async {
    return await _dbHelper.getAllReferrals();
  }

  @override
  Future<int> updateReferral(ReferralModel referral) async {
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final updatedReferral = referral.copyWith(
      updatedAt: now,
      isSynced: await _connectivity.isOnline,
    );

    // 1. Update Locally
    final result = await _local.saveRecord('referrals', updatedReferral.toMap());
    
    // 2. Sync to Cloud if online
    if (await _connectivity.isOnline) {
      try {
        await _remote.uploadRecord('referrals', updatedReferral.id.toString(), updatedReferral.toMap());
        await _local.markAsSynced('referrals', updatedReferral.id);
      } catch (e) {
        print("Cloud Sync Failed: $e");
      }
    }

    // 3. Log Action
    await AuditLogger.log(
      action: 'Update Referral',
      module: 'Referral',
      description: 'Updated referral status to: ${referral.status}.',
    );
    
    return result;
  }

  @override
  Future<int> deleteReferral(int id) async {
    final result = await _dbHelper.delete('referrals', id);
    // Note: Remote delete usually handled by SyncService or direct call
    return result;
  }
}

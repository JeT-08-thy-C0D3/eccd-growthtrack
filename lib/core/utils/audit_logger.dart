import '../../features/admin/data/repositories/audit_repository.dart';

class AuditLogger {
  static final AuditRepository _auditRepo = AuditRepository();

  static Future<void> log({
    required String action,
    required String module,
    required String description,
    String? performedBy,
  }) async {
    await _auditRepo.logAction(
      action: action,
      performedBy: performedBy,
      targetRecord: '[$module] $description',
    );
  }
}

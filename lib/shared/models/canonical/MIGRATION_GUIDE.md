/// Migration Guide: Legacy Models → Canonical Models
/// 
/// This document outlines how to migrate from legacy AssessmentModel
/// and other scattered models to the canonical unified models.

// ==============================================================================
// MIGRATION MAPPING
// ==============================================================================

/// AssessmentModel → EvaluationSession + EvaluationObservation
/// 
/// OLD (AssessmentModel):
///   - id
///   - childId
///   - date
///   - domain
///   - score
///   - remarks
///
/// NEW (EvaluationSession):
///   - id (new UUID)
///   - childId (from AssessmentModel.childId)
///   - centerId (MUST be populated from Child record or context)
///   - evaluatorId (from current user or default)
///   - sessionDate (from AssessmentModel.date)
///   - ageBand (calculated from child's DOB at sessionDate)
///   - observations (list of EvaluationObservation)
///   - status ('draft' → 'submitted' on migration)
///   - humanVerified (false initially)
///   - checklistVersion ('1.0')
///   - remarks (from AssessmentModel.remarks)
///
/// NEW (EvaluationObservation):
///   - id (new UUID)
///   - evaluationSessionId (references EvaluationSession.id)
///   - domainId (from AssessmentModel.domain, mapped to EccdDomain.id)
///   - indicatorId (MUST be populated from domain configuration)
///   - score (from AssessmentModel.score)
///   - evidenceSource ('observation')
///   - isAutomated (false - this was manual)
///   - teacherConfirmed (true - human data is confirmed)
///   - createdAt (from AssessmentModel creation time)

// ==============================================================================
// MIGRATION QUERIES (For database update scripts)
// ==============================================================================

/// SQLite migration script (pseudocode):
/// 
/// 1. Create new tables:
///    - evaluation_sessions
///    - evaluation_observations
/// 
/// 2. Batch migrate old assessments:
///    INSERT INTO evaluation_sessions
///    SELECT 
///      generate_uuid() as id,
///      a.child_id,
///      c.center_id,
///      a.evaluator_id,
///      a.date,
///      calculate_age_band(c.date_of_birth, a.date),
///      '1.0' as checklist_version,
///      'submitted' as status,
///      0 as human_verified,
///      a.remarks,
///      a.created_at,
///      a.updated_at
///    FROM assessments a
///    JOIN children c ON a.child_id = c.id
///    WHERE a.deleted_at IS NULL;
/// 
/// 3. Migrate observations:
///    INSERT INTO evaluation_observations
///    SELECT
///      generate_uuid() as id,
///      es.id as evaluation_session_id,
///      map_domain(a.domain) as domain_id,
///      get_primary_indicator(map_domain(a.domain)) as indicator_id,
///      a.score,
///      'observation' as evidence_source,
///      NULL as evidence_description,
///      0 as is_automated,
///      NULL as automated_activity_id,
///      NULL as automated_confidence,
///      NULL as teacher_notes,
///      NULL as verified_at,
///      1 as teacher_confirmed,
///      a.created_at,
///      a.updated_at
///    FROM assessments a
///    JOIN evaluation_sessions es ON a.id = es.migrated_from_assessment_id
///    WHERE a.deleted_at IS NULL;
/// 
/// 4. Disable old assessment table (don't delete):
///    ALTER TABLE assessments RENAME TO assessments_legacy;

// ==============================================================================
// FIRESTORE MIGRATION (For cloud storage)
// ==============================================================================

/// Firestore collections to create:
/// 
/// /evaluation_sessions/{sessionId}
/// {
///   childId: string,
///   centerId: string,
///   evaluatorId: string,
///   sessionDate: timestamp,
///   ageBand: string,
///   observations: array (IDs only, reference subcollection),
///   status: string,
///   humanVerified: boolean,
///   checklistVersion: string,
///   remarks: string,
///   createdAt: timestamp,
///   updatedAt: timestamp,
///   serverTimestamp: timestamp (set by backend)
/// }
///
/// /evaluation_sessions/{sessionId}/observations/{observationId}
/// {
///   domainId: string,
///   indicatorId: string,
///   score: number,
///   evidenceSource: string,
///   evidenceDescription: string,
///   isAutomated: boolean,
///   automatedActivityId: string (if automated),
///   automatedConfidence: number (if automated),
///   teacherNotes: string,
///   teacherConfirmed: boolean,
///   verifiedAt: timestamp (null until verified),
///   createdAt: timestamp,
///   updatedAt: timestamp
/// }

// ==============================================================================
// VALIDATION CHECKS (Before migration)
// ==============================================================================

/// Run these checks before migrating any data:
/// 
/// 1. ALL children must have:
///    - Valid dateOfBirth (can calculate age band)
///    - Valid centerId (assignment exists)
/// 
/// 2. ALL assessments must have:
///    - Valid childId
///    - Valid date (parseable)
///    - Valid domain (maps to EccdDomainType)
/// 
/// 3. ALL domains must be defined in EccdDomainRegistry
///    with at least one indicator per domain
/// 
/// 4. NO passwords in user data to be synced to Firestore
/// 
/// If any check fails, those records should be:
///    - Logged as errors
///    - Moved to a 'migration_failed' table
///    - Reviewed manually before proceeding

// ==============================================================================
// ROLLBACK PLAN
// ==============================================================================

/// In case of issues:
/// 
/// 1. Keep old tables: assessments_legacy, children_legacy, etc.
/// 2. Maintain a migration_log table:
///    - Which old records were migrated
///    - Mapping between old IDs and new IDs
///    - Timestamp of migration
/// 
/// 3. To rollback:
///    - Restore from database backup
///    - OR manually revert specific records using migration_log

// ==============================================================================
// BACKWARD COMPATIBILITY
// ==============================================================================

/// During transition period (Phase 2), maintain both:
/// 
/// 1. Old AssessmentModel can still be read/queried
///    but deprecated with @Deprecated annotation
/// 
/// 2. New code should use EvaluationSession
/// 
/// 3. UI can conditionally display both old and new records
///    (marked with "Migrated" badge for old data)
/// 
/// 4. By Phase 4, old models can be archived

// ==============================================================================
// IMPLEMENTATION CHECKLIST
// ==============================================================================

/// Follow this order to implement migration:
/// 
/// [ ] 1. Create all new canonical model classes (DONE)
/// [ ] 2. Create database tables for new models
/// [ ] 3. Write validation script for old data
/// [ ] 4. Perform dry-run migration on test database
/// [ ] 5. Review migrated data for accuracy
/// [ ] 6. Create migration_log table for traceability
/// [ ] 7. Execute production migration (backup first!)
/// [ ] 8. Verify Firestore sync
/// [ ] 9. Update UI to use new models
/// [ ] 10. Archive old tables after verification period

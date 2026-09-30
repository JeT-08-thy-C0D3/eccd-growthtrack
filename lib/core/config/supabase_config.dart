import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  static const String url = 'https://qghrxybgqasjgqlykblc.supabase.co';
  static const String anonKey = 'sb_publishable_-lL057VQr2a0KLqwnSWHhA_hPNRJJGt';

  // Storage Buckets
  static const String childProfilePhotos = 'child-profile-photos';
  static const String homeActivityEvidence = 'home-activity-evidence';
  static const String referralAttachments = 'referral-attachments';
  static const String pdfReports = 'pdf-reports';

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: url,
      anonKey: anonKey,
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

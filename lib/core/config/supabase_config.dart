import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SupabaseConfig {
  static const String url = 'https://jevshtdblsxikquujhek.supabase.co';
  static const String anonKey =
      'sb_publishable_86e7nO1WxEbU1lIsbL6I1g_IctSVGzy';

  // One private bucket. Categories are object-path prefixes inside it.
  static const String filesBucket = 'eccd-files';
  static const String childProfilePhotos = filesBucket;
  static const String homeActivityEvidence = filesBucket;
  static const String referralAttachments = filesBucket;
  static const String pdfReports = filesBucket;

  static const String childProfileCategory = 'child-profile-photos';
  static const String homeActivityCategory = 'home-activity-evidence';
  static const String referralCategory = 'referral-attachments';
  static const String pdfReportsCategory = 'pdf-reports';

  static Future<void> initialize() async {
    if (anonKey.contains('service_role')) {
      throw StateError(
        'A Supabase service-role key must never be used in the Flutter app.',
      );
    }
    await Supabase.initialize(
      url: url,
      publishableKey: anonKey,
      // Supabase Third-Party Auth verifies this Firebase JWT after the
      // Firebase project is registered in Supabase Dashboard. This preserves
      // Firebase as the only user/session provider in the app.
      accessToken: () async {
        // Force a refreshed Firebase token so newly-added custom claims are
        // included when Supabase evaluates its storage RLS policies.
        return FirebaseAuth.instance.currentUser?.getIdToken(true);
      },
    );
  }

  static SupabaseClient get client => Supabase.instance.client;
}

import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads the project's public client settings at build/run time.
///
/// Never put a database password, service role key, or secret key here.
class SupabaseAppConfig {
  static const projectUrl = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static bool get isConfigured =>
      projectUrl.startsWith('https://') && publishableKey.isNotEmpty;

  static Future<SupabaseClient?> initializeIfConfigured() async {
    if (!isConfigured) return null;

    await Supabase.initialize(url: projectUrl, publishableKey: publishableKey);
    return Supabase.instance.client;
  }
}

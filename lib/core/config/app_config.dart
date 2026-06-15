import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  const AppConfig._();

  static String get supabaseUrl {
    final value = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    if (value.isNotEmpty) return value;

    return const String.fromEnvironment('SUPABASE_URL').trim();
  }

  static String get supabaseAnonKey {
    final value = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (value.isNotEmpty) return value;

    return const String.fromEnvironment('SUPABASE_ANON_KEY').trim();
  }

  static String get apiBaseUrl {
    final value = dotenv.env['API_BASE_URL']?.trim() ?? '';
    if (value.isNotEmpty) return value;

    final dartDefine = const String.fromEnvironment('API_BASE_URL').trim();
    if (dartDefine.isNotEmpty) return dartDefine;

    return 'https://aidverify.netlify.app';
  }

  static String? validate() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      return 'Missing Supabase environment variables. '
          'Set SUPABASE_URL and SUPABASE_ANON_KEY in .env.';
    }

    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'SUPABASE_URL is not a valid URL.';
    }

    return null;
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? dotenvLoadError;
  try {
    await dotenv.load(fileName: '.env');
  } catch (error) {
    dotenvLoadError = error;
  }

  final configError = AppConfig.validate();
  if (configError != null) {
    runApp(
      ConfigErrorApp(
        message: dotenvLoadError == null
            ? configError
            : '$configError\n\n.env load error: $dotenvLoadError',
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
    );
  } catch (error) {
    runApp(ConfigErrorApp(message: 'Supabase initialization failed: $error'));
    return;
  }

  runApp(const ProviderScope(child: VerifyAidMobileApp()));
}

class ConfigErrorApp extends StatelessWidget {
  const ConfigErrorApp({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Configuration error',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(message, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    const Text(
                      'Expected .env format:\n'
                      'SUPABASE_URL=https://your-project.supabase.co\n'
                      'SUPABASE_ANON_KEY=your-key\n'
                      'API_BASE_URL=https://your-api.example.com',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

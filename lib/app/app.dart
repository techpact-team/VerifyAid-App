import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'router.dart';

class VerifyAidMobileApp extends StatelessWidget {
  const VerifyAidMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VerifyAid',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: AppTheme.light,
    );
  }
}

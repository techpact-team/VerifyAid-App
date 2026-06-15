import 'package:flutter/material.dart';
import 'router.dart';

class VerifyAidMobileApp extends StatelessWidget {
  const VerifyAidMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'VerifyAid',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
    );
  }
}

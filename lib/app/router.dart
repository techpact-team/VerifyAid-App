import 'package:go_router/go_router.dart';

import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/beneficiaries/register_beneficiary_screen.dart';
import '../features/distribution/distribution_search_screen.dart';
import '../features/sync/sync_status_screen.dart';
import '../features/distribution/distribution_verify_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/beneficiaries/register',
      builder: (context, state) => const RegisterBeneficiaryScreen(),
    ),
    GoRoute(
      path: '/distribution',
      builder: (context, state) => const DistributionSearchScreen(),
    ),
    GoRoute(
      path: '/sync',
      builder: (context, state) => const SyncStatusScreen(),
    ),
    GoRoute(
     path: '/distribution/verify',
     builder: (context, state) {
       final extra = state.extra as Map<String, dynamic>;
       final beneficiary = extra['beneficiary'] as Map<String, dynamic>;
       final lookupMethod = extra['lookupMethod'] as String? ?? 'search';
       return DistributionVerifyScreen(
         beneficiary: beneficiary,
         lookupMethod: lookupMethod,
       );
     },
    ),
  ],
);

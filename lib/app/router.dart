import 'package:go_router/go_router.dart';

import '../features/artifacts/presentation/artifacts_page.dart';
import '../features/journal/presentation/timeline_page.dart';
import '../features/journal/presentation/today_page.dart';
import '../features/onboarding/presentation/onboarding_page.dart';
import '../features/settings/presentation/settings_page.dart';
import 'shell_page.dart';

final appRouter = GoRouter(
  initialLocation: '/onboarding',
  routes: [
    GoRoute(
      path: '/onboarding',
      builder: (context, state) => const OnboardingPage(),
    ),
    ShellRoute(
      builder: (context, state, child) => ShellPage(child: child),
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const TodayPage(),
        ),
        GoRoute(
          path: '/timeline',
          builder: (context, state) => const TimelinePage(),
        ),
        GoRoute(
          path: '/artifacts',
          builder: (context, state) => const ArtifactsPage(),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SettingsPage(),
        ),
      ],
    ),
  ],
);

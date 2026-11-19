import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/care/presentation/home_page.dart';
import '../features/onboarding/presentation/onboarding_controller.dart';
import '../features/onboarding/presentation/onboarding_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final isOnboardingFinished = ref.watch(
    onboardingControllerProvider.select((s) => s.isFinished),
  );

  return GoRouter(
    initialLocation: isOnboardingFinished ? '/home' : '/onboarding',
    redirect: (BuildContext context, GoRouterState state) {
      final path = state.uri.path;
      if (!isOnboardingFinished && path != '/onboarding') {
        return '/onboarding';
      }
      if (isOnboardingFinished && path == '/onboarding') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const HomePage(),
      ),
    ],
  );
});

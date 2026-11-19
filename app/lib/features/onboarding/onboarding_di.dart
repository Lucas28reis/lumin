import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/core_providers.dart';
import 'data/draft_local_store.dart';
import 'data/onboarding_repository_impl.dart';
import 'domain/onboarding_repository.dart';

final draftLocalStoreProvider = Provider<DraftLocalStore>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return DraftLocalStore(prefs);
});

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  final supabase = ref.watch(supabaseClientProvider);
  final localStore = ref.watch(draftLocalStoreProvider);
  return OnboardingRepositoryImpl(
    supabase: supabase,
    localStore: localStore,
  );
});

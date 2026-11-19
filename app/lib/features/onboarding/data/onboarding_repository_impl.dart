import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/error/failure.dart';
import '../domain/onboarding_draft.dart';
import '../domain/onboarding_repository.dart';
import 'draft_local_store.dart';

class OnboardingRepositoryImpl implements OnboardingRepository {
  OnboardingRepositoryImpl({
    required this._supabase,
    required this._localStore,
  });

  final SupabaseClient? _supabase;
  final DraftLocalStore _localStore;
  static const Uuid _uuid = Uuid();

  @override
  Future<void> signInAnonymouslyIfNeeded() async {
    final client = _supabase;
    if (client == null) return; // Modo local/offline

    if (client.auth.currentSession == null) {
      await client.auth.signInAnonymously();
    }
  }

  @override
  Future<OnboardingResult> completeOnboarding({
    required OnboardingDraft draft,
    required DateTime now,
  }) async {
    final client = _supabase;
    if (client != null) {
      await signInAnonymouslyIfNeeded();
      final payload = draft.toRpcPayload(now: now);
      final petId = await client.rpc<String>(
        'complete_onboarding',
        params: {'p': payload},
      );

      final petRow = await client
          .from('pets')
          .select('household_id')
          .eq('id', petId)
          .single();
      final householdId = petRow['household_id'] as String;

      final inviteCode = await client.rpc<String>(
        'create_invite',
        params: {'p_household': householdId, 'p_role': 'member'},
      );

      await _localStore.saveCompletedPet(petId: petId, inviteCode: inviteCode);

      return OnboardingResult(
        petId: petId,
        householdId: householdId,
        inviteCode: inviteCode,
      );
    }

    // Fallback determinístico em modo local/offline (sem chaves Supabase)
    final existingPetId = _localStore.loadCompletedPetId();
    final existingInvite = _localStore.loadInviteCode();
    final petId = existingPetId ?? _uuid.v4();
    final inviteCode = existingInvite ?? _generateLocalInviteCode();

    await _localStore.saveDraft(draft);
    await _localStore.saveCompletedPet(petId: petId, inviteCode: inviteCode);

    return OnboardingResult(
      petId: petId,
      householdId: 'local-household',
      inviteCode: inviteCode,
    );
  }

  @override
  Future<void> updateTutorDisplayName(String displayName) async {
    final trimmed = displayName.trim().isEmpty ? 'Tutor' : displayName.trim();
    final draft = _localStore.loadDraft().copyWith(tutorDisplayName: trimmed);
    await _localStore.saveDraft(draft);

    final client = _supabase;
    final uid = client?.auth.currentUser?.id;
    if (client != null && uid != null) {
      await client
          .from('household_members')
          .update({'display_name': trimmed})
          .eq('user_id', uid);
    }
  }

  @override
  Future<OnboardingResult> joinHousehold({
    required String code,
    required String displayName,
  }) async {
    final cleanCode = code.trim().toUpperCase();
    final validCode = RegExp(r'^[A-Z2-9]{6}$').hasMatch(cleanCode);
    if (!validCode) {
      throw const InvalidInviteFailure();
    }

    final client = _supabase;
    if (client != null) {
      await signInAnonymouslyIfNeeded();
      final householdId = await client.rpc<String>(
        'join_household',
        params: {
          'p_code': cleanCode,
          'p_display_name': displayName.trim().isEmpty
              ? 'Tutor'
              : displayName.trim(),
        },
      );
      final petRow = await client
          .from('pets')
          .select('id, name, species, avatar_dna')
          .eq('household_id', householdId)
          .limit(1)
          .single();
      final petId = petRow['id'] as String;
      await _localStore.saveCompletedPet(petId: petId, inviteCode: cleanCode);
      return OnboardingResult(
        petId: petId,
        householdId: householdId,
        inviteCode: cleanCode,
      );
    }

    // Modo local/offline: simula entrada na família do Paçoca com Ana
    final currentDraft = _localStore.loadDraft();
    final joinedDraft = currentDraft.copyWith(
      petName: currentDraft.petName.isEmpty ? 'Paçoca' : currentDraft.petName,
      tutorDisplayName: displayName.trim().isEmpty
          ? 'Co-tutor'
          : displayName.trim(),
    );
    final petId = _uuid.v4();
    await _localStore.saveDraft(joinedDraft);
    await _localStore.saveCompletedPet(petId: petId, inviteCode: cleanCode);

    return OnboardingResult(
      petId: petId,
      householdId: 'joined-household',
      inviteCode: cleanCode,
    );
  }

  static String _generateLocalInviteCode() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random();
    return List.generate(
      6,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/onboarding_draft.dart';

/// Armazenamento local para retomada do Onboarding e persistência offline.
class DraftLocalStore {
  DraftLocalStore(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyStep = 'lumin.onboarding.step';
  static const String _keyDraft = 'lumin.onboarding.draft';
  static const String _keyCompletedPetId = 'lumin.onboarding.pet_id';
  static const String _keyInviteCode = 'lumin.onboarding.invite_code';
  static const String _keyOnboardingFinished = 'lumin.onboarding.finished';

  int loadStep() => _prefs.getInt(_keyStep) ?? 0;

  Future<void> saveStep(int step) => _prefs.setInt(_keyStep, step);

  OnboardingDraft loadDraft() {
    final raw = _prefs.getString(_keyDraft);
    if (raw == null || raw.isEmpty) {
      return OnboardingDraft.initial();
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return OnboardingDraft.fromJson(decoded);
    } catch (_) {
      return OnboardingDraft.initial();
    }
  }

  Future<void> saveDraft(OnboardingDraft draft) {
    return _prefs.setString(_keyDraft, jsonEncode(draft.toJson()));
  }

  String? loadCompletedPetId() => _prefs.getString(_keyCompletedPetId);

  String? loadInviteCode() => _prefs.getString(_keyInviteCode);

  bool isOnboardingFinished() =>
      _prefs.getBool(_keyOnboardingFinished) ?? false;

  Future<void> saveCompletedPet({
    required String petId,
    required String inviteCode,
  }) async {
    await _prefs.setString(_keyCompletedPetId, petId);
    await _prefs.setString(_keyInviteCode, inviteCode);
  }

  Future<void> markOnboardingFinished() =>
      _prefs.setBool(_keyOnboardingFinished, true);

  Future<void> clearAll() async {
    await _prefs.remove(_keyStep);
    await _prefs.remove(_keyDraft);
    await _prefs.remove(_keyCompletedPetId);
    await _prefs.remove(_keyInviteCode);
    await _prefs.remove(_keyOnboardingFinished);
  }
}

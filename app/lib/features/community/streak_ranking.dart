import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/providers/core_providers.dart';
import '../care/presentation/care_controller.dart';
import '../onboarding/presentation/onboarding_controller.dart';

class StreakRanking extends ConsumerStatefulWidget {
  const StreakRanking({super.key});
  @override
  ConsumerState<StreakRanking> createState() => _RankingState();
}

class _RankingState extends ConsumerState<StreakRanking> {
  List<Map<String, dynamic>> entries = [];
  bool busy = true;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load({bool? participate}) async {
    final client = ref.read(supabaseClientProvider);
    final pet = ref.read(onboardingControllerProvider).petId;
    if (client == null || pet == null) {
      setState(() => busy = false);
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (participate == true) {
        await client.from('streak_participants').upsert({
          'pet_id': pet,
        }, ignoreDuplicates: true);
      } else if (participate == false) {
        await client.from('streak_participants').delete().eq('pet_id', pet);
      }
      final rows = await client.rpc<List<dynamic>>(
        'streak_leaderboard',
        params: {'p_pet': pet},
      );
      if (mounted) setState(() => entries = rows.cast<Map<String, dynamic>>());
    } catch (_) {
      if (mounted)
        setState(() => error = 'Não foi possível atualizar o ranking.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final care = ref.watch(careControllerProvider);
    final online =
        ref.watch(supabaseClientProvider) != null &&
        ref.watch(onboardingControllerProvider).petId != null;
    final joined = entries.any((e) => e['mine'] == true);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ranking de ofensivas'),
        actions: [
          if (online)
            IconButton(
              tooltip: 'Atualizar ranking',
              icon: const Icon(Icons.refresh),
              onPressed: busy ? null : () => load(),
            ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: ListTile(
                  leading: const Icon(Icons.local_fire_department),
                  title: Text(care.petName),
                  subtitle: const Text('Sua ofensiva atual'),
                  trailing: Text('${care.streakDays} dias'),
                ),
              ),
              if (!online)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'A classificação entre famílias fica disponível na versão conectada do Lumin.',
                    ),
                  ),
                )
              else if (busy)
                const Center(child: CircularProgressIndicator())
              else if (error != null)
                Card(
                  child: ListTile(
                    title: Text(error!),
                    trailing: TextButton(
                      onPressed: () => load(),
                      child: const Text('Tentar de novo'),
                    ),
                  ),
                )
              else ...[
                Card(
                  child: ListTile(
                    title: Text(
                      joined
                          ? 'Sua família participa do ranking'
                          : 'Participar do ranking',
                    ),
                    subtitle: const Text(
                      'As outras famílias verão o nome do pet e os dias de ofensiva.',
                    ),
                    trailing: Switch(
                      value: joined,
                      onChanged: (v) => load(participate: v),
                    ),
                  ),
                ),
                if (entries.isEmpty)
                  const Card(
                    child: ListTile(
                      title: Text('Ainda não há famílias no ranking.'),
                    ),
                  ),
                for (final entry in entries)
                  Card(
                    child: ListTile(
                      leading: Text('#${entry["position"]}'),
                      title: Text(entry['pet_name']),
                      subtitle: entry['mine'] == true
                          ? const Text('Sua família')
                          : null,
                      trailing: Text('${entry["days"]} dias'),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

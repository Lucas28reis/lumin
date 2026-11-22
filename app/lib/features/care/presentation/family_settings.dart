import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/providers/core_providers.dart';
import '../../community/scene_shop.dart';
import '../../onboarding/presentation/onboarding_controller.dart';
import 'care_controller.dart';

class FamilySettings extends ConsumerStatefulWidget {
  const FamilySettings({super.key});
  @override
  ConsumerState<FamilySettings> createState() => _FamilySettingsState();
}

class _FamilySettingsState extends ConsumerState<FamilySettings> {
  late final name = TextEditingController(
    text: ref.read(careControllerProvider).tutorName,
  );
  bool editing = false, busy = false, owner = false, editor = false;
  String? household, error;
  List<Map<String, dynamic>> members = [], invites = [];
  @override
  void initState() {
    super.initState();
    run(load);
  }

  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  Future<void> load() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) return;
    final pet = await client
        .from('pets')
        .select('household_id')
        .eq('id', ref.read(onboardingControllerProvider).petId!)
        .single();
    household = pet['household_id'];
    members = await client
        .from('household_members')
        .select('user_id,display_name,role,expires_at')
        .eq('household_id', household!);
    final role = members
        .where((m) => m['user_id'] == client.auth.currentUser?.id)
        .firstOrNull?['role'];
    owner = role == 'owner';
    editor = owner || role == 'member';
    if (editor) {
      invites = await client
          .from('household_invites')
          .select('code,role,uses,max_uses,expires_at')
          .eq('household_id', household!)
          .gt('expires_at', DateTime.now().toUtc().toIso8601String());
      invites = invites.where((i) => i['uses'] < i['max_uses']).toList();
    }
  }

  Future<void> run(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
    } catch (_) {
      error =
          'Não foi possível concluir. Verifique a conexão e tente novamente.';
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> confirm(String title) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    final care = ref.watch(careControllerProvider);
    final client = ref.watch(supabaseClientProvider);
    final user = client?.auth.currentUser;
    final selected = ref.watch(sceneProvider);
    final store = ref.read(sceneProvider.notifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil e família')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (busy) const LinearProgressIndicator(),
              if (error != null)
                ListTile(
                  title: Text(error!),
                  trailing: IconButton(
                    tooltip: 'Atualizar',
                    icon: const Icon(Icons.refresh),
                    onPressed: () => run(load),
                  ),
                ),
              Card(
                child: Column(
                  children: [
                    if (!editing)
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(care.tutorName),
                        subtitle: const Text('Nome do tutor'),
                        trailing: IconButton(
                          tooltip: 'Editar nome',
                          onPressed: busy
                              ? null
                              : () => setState(() {
                                  name.text = care.tutorName;
                                  editing = true;
                                }),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            TextField(
                              controller: name,
                              autofocus: true,
                              maxLength: 30,
                              decoration: const InputDecoration(
                                labelText: 'Nome do tutor',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: busy
                                      ? null
                                      : () => setState(() => editing = false),
                                  child: const Text('Cancelar'),
                                ),
                                FilledButton(
                                  onPressed: busy || name.text.trim().isEmpty
                                      ? null
                                      : () => run(() async {
                                          await ref
                                              .read(
                                                careControllerProvider.notifier,
                                              )
                                              .renameTutor(name.text.trim());
                                          editing = false;
                                          await load();
                                        }),
                                  child: const Text('Salvar nome'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ListTile(
                      leading: const Icon(Icons.email_outlined),
                      title: Text(user?.email ?? 'Sem e-mail vinculado'),
                      subtitle: const Text('E-mail da conta'),
                    ),
                    if (user?.isAnonymous == true)
                      TextButton(
                        onPressed: () => ref
                            .read(careControllerProvider.notifier)
                            .markAccountLinked('Google'),
                        child: const Text('Vincular conta Google'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Compartilhamento',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (client == null)
                ListTile(
                  leading: const Icon(Icons.phone_android),
                  title: Text('Perfil local de ${care.petName}'),
                  subtitle: const Text(
                    'Os cuidados estão neste aparelho. O acesso de outros tutores requer conexão com o serviço de famílias.',
                  ),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.ios_share),
                label: const Text('Compartilhar rotina de hoje'),
                onPressed: busy
                    ? null
                    : () => run(() async {
                        final lines = care.slots.map(
                          (slot) =>
                              '${slot.isDone ? "✓" : "○"} ${slot.timeLabel} · ${slot.title}',
                        );
                        await SharePlus.instance.share(
                          ShareParams(
                            text: [
                              'Rotina de ${care.petName}',
                              ...lines,
                            ].join('\n'),
                          ),
                        );
                      }),
              ),
              for (final member in members)
                ListTile(
                  title: Text(member['display_name']),
                  subtitle: Text(switch (member['role']) {
                    'owner' => 'Responsável',
                    'sitter' => 'Cuidador temporário',
                    _ => 'Familiar',
                  }),
                  trailing: owner && member['role'] != 'owner'
                      ? IconButton(
                          tooltip: 'Remover acesso',
                          icon: const Icon(Icons.person_remove_outlined),
                          onPressed: busy
                              ? null
                              : () async {
                                  if (await confirm(
                                        'Remover o acesso de ${member["display_name"]}?',
                                      ) &&
                                      mounted)
                                    await run(() async {
                                      await client!.rpc(
                                        'remove_family_member',
                                        params: {
                                          'p_household': household,
                                          'p_user': member['user_id'],
                                        },
                                      );
                                      await load();
                                    });
                                },
                        )
                      : null,
                ),
              if (editor) ...[
                OutlinedButton.icon(
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Criar convite'),
                  onPressed: busy
                      ? null
                      : () => run(() async {
                          await client!.rpc(
                            'create_invite',
                            params: {
                              'p_household': household,
                              'p_role': 'member',
                            },
                          );
                          await load();
                        }),
                ),
                for (final invite in invites)
                  ListTile(
                    title: Text(invite['code']),
                    subtitle: const Text('Convite ativo'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Compartilhar convite',
                          icon: const Icon(Icons.share_outlined),
                          onPressed: () => run(() async {
                            await SharePlus.instance.share(
                              ShareParams(
                                text:
                                    'Cuide de ${care.petName} comigo no Lumin. Código da família: ${invite["code"]}',
                              ),
                            );
                          }),
                        ),
                        IconButton(
                          tooltip: 'Revogar convite',
                          icon: const Icon(Icons.link_off),
                          onPressed: busy
                              ? null
                              : () async {
                                  if (await confirm(
                                        'Invalidar este convite?',
                                      ) &&
                                      mounted)
                                    await run(() async {
                                      await client!.rpc(
                                        'revoke_family_invite',
                                        params: {
                                          'p_household': household,
                                          'p_code': invite['code'],
                                        },
                                      );
                                      await load();
                                    });
                                },
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              Text(
                'Pagamentos e compras',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const ListTile(
                leading: Icon(Icons.receipt_long_outlined),
                title: Text('Compras na loja'),
                subtitle: Text(
                  'A loja atual oferece cenários gratuitos e resgates por ofensiva. Não há cobranças.',
                ),
              ),
              for (final scene in PetScene.values.where(store.owned))
                ListTile(
                  leading: const Icon(Icons.landscape_outlined),
                  title: Text(scene.label),
                  subtitle: Text(
                    scene.days == 0 ? 'Grátis' : 'Resgatado por ofensiva',
                  ),
                  trailing: selected == scene ? const Text('Em uso') : null,
                ),
              OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const SceneShop()),
                ),
                child: const Text('Abrir loja'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

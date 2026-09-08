import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanshooter/core/di/providers.dart';
import 'package:juanshooter/domain/entities/leaderboard_entry.dart';
import 'package:juanshooter/game.dart';

class LeaderboardOverlay extends ConsumerStatefulWidget {
  const LeaderboardOverlay({required this.game, super.key});

  final MyGame game;

  @override
  ConsumerState<LeaderboardOverlay> createState() => _LeaderboardOverlayState();
}

class _LeaderboardOverlayState extends ConsumerState<LeaderboardOverlay> {
  late final TextEditingController _callSignController;

  @override
  void initState() {
    super.initState();
    _callSignController = TextEditingController();
    Future<void>.microtask(() async {
      final pilot = await ref.read(pilotRepositoryProvider).current();
      if (!mounted) return;
      if (pilot != null) {
        _callSignController.text = pilot.callSign;
      }
      await ref.read(leaderboardControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _callSignController.dispose();
    super.dispose();
  }

  Future<void> _saveCallSign() async {
    final next = _callSignController.text.trim();
    if (next.isEmpty) return;
    await ref.read(pilotRepositoryProvider).updateCallSign(next);
    if (!mounted) return;
    final updated = await ref.read(pilotRepositoryProvider).current();
    _callSignController.text = updated.callSign;
    ref.invalidate(currentPilotProvider);
  }

  @override
  Widget build(BuildContext context) {
    final board = ref.watch(leaderboardControllerProvider);
    final flags = ref.watch(gameFlagsProvider);

    return Material(
      color: Colors.black.withValues(alpha: 0.72),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () => widget.game.overlays.remove('Leaderboard'),
                    child: const Text(
                      'VOLVER',
                      style: TextStyle(
                        color: Colors.cyanAccent,
                        fontFamily: 'Megatrans',
                        letterSpacing: 3,
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'RANKING',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Megatrans',
                      fontSize: 28,
                      letterSpacing: 8,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: board.isLoading
                        ? null
                        : () => ref
                            .read(leaderboardControllerProvider.notifier)
                            .load(),
                    icon: const Icon(Icons.refresh, color: Colors.cyanAccent),
                  ),
                ],
              ),
              flags.when(
                data: (value) => Text(
                  value.fromRemote
                      ? 'LINK LIVE  ·  ${value.transmissionTitle}'
                      : value.transmissionTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value.fromRemote
                        ? Colors.cyanAccent.withValues(alpha: 0.85)
                        : Colors.orangeAccent.withValues(alpha: 0.9),
                    fontFamily: 'Megatrans',
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Text(
                    'CALLSIGN',
                    style: TextStyle(
                      color: Colors.white54,
                      fontFamily: 'Megatrans',
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _callSignController,
                      maxLength: 16,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Megatrans',
                        letterSpacing: 2,
                      ),
                      decoration: const InputDecoration(
                        counterText: '',
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.cyanAccent),
                        ),
                      ),
                      onSubmitted: (_) => _saveCallSign(),
                    ),
                  ),
                  TextButton(
                    onPressed: _saveCallSign,
                    child: const Text(
                      'GUARDAR',
                      style: TextStyle(color: Colors.cyanAccent),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(child: _LeaderboardBody(state: board)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardBody extends StatelessWidget {
  const _LeaderboardBody({required this.state});

  final LeaderboardState state;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }
    if (state.errorMessage != null) {
      return Center(
        child: Text(
          state.errorMessage!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.orangeAccent, fontSize: 16),
        ),
      );
    }
    if (state.entries.isEmpty) {
      return const Center(
        child: Text(
          'NO TRANSMISSIONS YET',
          style: TextStyle(color: Colors.white54, fontFamily: 'Megatrans'),
        ),
      );
    }

    return ListView.separated(
      itemCount: state.entries.length,
      separatorBuilder: (_, __) =>
          const Divider(color: Colors.white10, height: 1),
      itemBuilder: (context, index) {
        return _RankRow(rank: index + 1, entry: state.entries[index]);
      },
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({required this.rank, required this.entry});

  final int rank;
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final accent = entry.isLocalPilot ? Colors.cyanAccent : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            child: Text(
              '$rank',
              style: TextStyle(
                color: accent,
                fontFamily: 'steel700',
                fontSize: 22,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.callSign,
                  style: TextStyle(
                    color: accent,
                    fontFamily: 'Megatrans',
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  entry.faction,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            '${entry.score}',
            style: TextStyle(
              color: accent,
              fontFamily: 'steel700',
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}

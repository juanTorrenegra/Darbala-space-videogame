import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanshooter/core/di/providers.dart';
import 'package:juanshooter/domain/entities/leaderboard_entry.dart';
import 'package:juanshooter/domain/entities/pilot_identity.dart';
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
    if (!mounted) return;
    if (updated != null) {
      _callSignController.text = updated.callSign;
    }
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
                  GestureDetector(
                    onLongPress: () =>
                        widget.game.overlays.add('FlagAdmin'),
                    child: const Text(
                      'RANKING',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Megatrans',
                        fontSize: 28,
                        letterSpacing: 8,
                      ),
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
              Expanded(
                child: Consumer(
                  builder: (context, ref, _) {
                    final pilot = ref.watch(currentPilotProvider).value;
                    return _LeaderboardBody(state: board, pilot: pilot);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LeaderboardBody extends ConsumerStatefulWidget {
  const _LeaderboardBody({required this.state, required this.pilot});

  final LeaderboardState state;
  final PilotIdentity? pilot;

  @override
  ConsumerState<_LeaderboardBody> createState() => _LeaderboardBodyState();
}

class _LeaderboardBodyState extends ConsumerState<_LeaderboardBody> {
  final ScrollController _scrollController = ScrollController();
  bool _hasScrolled = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToUser(int localIndex) {
    if (_hasScrolled || localIndex < 0) return;
    _hasScrolled = true;
    Future<void>.delayed(const Duration(seconds: 1), () {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      final target = localIndex * 61.0;
      final max = position.maxScrollExtent;
      final desired = target - position.viewportDimension * 0.4;
      _scrollController.animateTo(
        desired.clamp(0.0, max),
        duration: const Duration(milliseconds: 3000),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
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

    final entries = state.entries;
    final pilotId = widget.pilot?.id;
    final localIndex = entries.indexWhere((entry) => entry.pilotId == pilotId);
    final local = localIndex >= 0 ? entries[localIndex] : null;
    final localRank = localIndex >= 0 ? localIndex + 1 : null;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToUser(localIndex);
    });

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 1,
          child: _PilotSpotlight(
            entry: local,
            rank: localRank,
            total: entries.length,
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 2,
          child: ListView.separated(
            controller: _scrollController,
            itemCount: entries.length,
            separatorBuilder: (_, __) =>
                const Divider(color: Colors.white10, height: 1),
            itemBuilder: (context, index) {
              return _RankRow(
                rank: index + 1,
                entry: entries[index],
                isCurrent: entries[index].pilotId == pilotId,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PilotSpotlight extends StatelessWidget {
  const _PilotSpotlight({
    required this.entry,
    required this.rank,
    required this.total,
  });

  final LeaderboardEntry? entry;
  final int? rank;
  final int total;

  @override
  Widget build(BuildContext context) {
    if (entry == null || rank == null) {
      return const Center(
        child: Text(
          'SIN PILOTO LOCAL',
          style: TextStyle(
            color: Colors.white38,
            fontFamily: 'Megatrans',
            letterSpacing: 2,
          ),
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 0),
            child: Text(
              'TU POSICIÓN',
              style: TextStyle(
                color: Colors.cyanAccent,
                fontFamily: 'Megatrans',
                fontSize: 12,
                letterSpacing: 4,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              '#$rank',
              style: const TextStyle(
                color: Color(0xFFFFB74D),
                fontFamily: 'steel700',
                fontSize: 56,
                height: 1,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.only(left: 32),
            child: Text(
              entry!.callSign,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Megatrans',
                fontSize: 22,
                letterSpacing: 3,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              '${entry!.score} PTS',
              style: const TextStyle(
                color: Colors.cyanAccent,
                fontFamily: 'steel700',
                fontSize: 26,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 64),
            child: Text(
              'DE $total PILOTOS',
              style: const TextStyle(
                color: Colors.white38,
                fontFamily: 'Megatrans',
                fontSize: 11,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RankRow extends StatelessWidget {
  const _RankRow({
    required this.rank,
    required this.entry,
    required this.isCurrent,
  });

  final int rank;
  final LeaderboardEntry entry;
  final bool isCurrent;

  static const _glow = Color(0xFF69F0AE);

  @override
  Widget build(BuildContext context) {
    final accent = isCurrent ? _glow : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
      decoration: isCurrent
          ? BoxDecoration(
              color: _glow.withValues(alpha: 0.12),
              border: Border.all(color: _glow.withValues(alpha: 0.4)),
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: _glow.withValues(alpha: 0.28),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            )
          : null,
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

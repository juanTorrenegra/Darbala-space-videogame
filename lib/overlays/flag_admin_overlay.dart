import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanshooter/core/di/providers.dart';
import 'package:juanshooter/game.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Hidden remote-config panel. Opened by long-pressing the RANKING title.
/// Only profiles with `is_admin = true` can save; RLS enforces it server-side.
class FlagAdminOverlay extends ConsumerStatefulWidget {
  const FlagAdminOverlay({required this.game, super.key});

  final MyGame game;

  @override
  ConsumerState<FlagAdminOverlay> createState() => _FlagAdminOverlayState();
}

class _FlagAdminOverlayState extends ConsumerState<FlagAdminOverlay> {
  final Map<String, TextEditingController> _controllers = {};
  bool _loading = true;
  bool _saving = false;
  bool _denied = false;
  String? _status;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_load);
  }

  Future<void> _load() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      setState(() {
        _loading = false;
        _denied = true;
      });
      return;
    }
    try {
      final profile = await _client
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .maybeSingle();
      if (profile == null || profile['is_admin'] != true) {
        setState(() {
          _loading = false;
          _denied = true;
        });
        return;
      }
      final rows = await _client
          .from('game_flags')
          .select('key, value')
          .order('key');
      for (final row in rows) {
        final key = '${row['key']}';
        _controllers[key] = TextEditingController(text: '${row['value']}');
      }
      setState(() => _loading = false);
    } catch (_) {
      setState(() {
        _loading = false;
        _denied = true;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      final now = DateTime.now().toIso8601String();
      for (final entry in _controllers.entries) {
        await _client
            .from('game_flags')
            .update({'value': entry.value.text, 'updated_at': now})
            .eq('key', entry.key);
      }
      ref.invalidate(gameFlagsProvider);
      setState(() => _status = 'TRANSMITIDO');
    } catch (_) {
      setState(() => _status = 'ERROR AL TRANSMITIR');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.85),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  TextButton(
                    onPressed: () => widget.game.overlays.remove('FlagAdmin'),
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
                    'CONTROL DE FLAGS',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Megatrans',
                      fontSize: 22,
                      letterSpacing: 6,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 72),
                ],
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.cyanAccent),
      );
    }
    if (_denied) {
      return const Center(
        child: Text(
          'ACCESO DENEGADO',
          style: TextStyle(
            color: Colors.redAccent,
            fontFamily: 'Megatrans',
            fontSize: 20,
            letterSpacing: 4,
          ),
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              for (final entry in _controllers.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontFamily: 'Megatrans',
                          fontSize: 11,
                          letterSpacing: 3,
                        ),
                      ),
                      TextField(
                        controller: entry.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'Megatrans',
                          letterSpacing: 1,
                        ),
                        decoration: const InputDecoration(
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.cyanAccent),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        if (_status != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _status!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _status == 'TRANSMITIDO'
                    ? const Color(0xFF69F0AE)
                    : Colors.orangeAccent,
                fontFamily: 'Megatrans',
                letterSpacing: 3,
              ),
            ),
          ),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.cyanAccent.withValues(alpha: 0.15),
            foregroundColor: Colors.cyanAccent,
            side: const BorderSide(color: Colors.cyanAccent),
          ),
          child: Text(
            _saving ? 'TRANSMITIENDO…' : 'GUARDAR',
            style: const TextStyle(fontFamily: 'Megatrans', letterSpacing: 3),
          ),
        ),
      ],
    );
  }
}

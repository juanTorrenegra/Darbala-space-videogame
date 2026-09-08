import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:juanshooter/core/error/result.dart';
import 'package:juanshooter/core/di/providers.dart';
import 'package:juanshooter/domain/entities/pilot_identity.dart';
import 'package:juanshooter/game.dart';

class CreateAccountOverlay extends ConsumerStatefulWidget {
  const CreateAccountOverlay({required this.game, super.key});

  final MyGame game;

  @override
  ConsumerState<CreateAccountOverlay> createState() =>
      _CreateAccountOverlayState();
}

class _CreateAccountOverlayState extends ConsumerState<CreateAccountOverlay> {
  final _nombre = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final remembered =
        ref.read(pilotLocalDataSourceProvider).lastNombre();
    if (remembered != null && remembered.isNotEmpty) {
      _nombre.text = remembered;
    }
  }

  @override
  void dispose() {
    _nombre.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Result<PilotIdentity>> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await action();
    if (!mounted) return;
    result.when(
      success: (_) {
        widget.game.overlays.remove('CreateAccount');
      },
      failure: (error) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      },
    );
  }

  InputDecoration _field(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Colors.cyanAccent,
        fontFamily: 'Megatrans',
        letterSpacing: 2,
      ),
      enabledBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.white24),
      ),
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: Colors.cyanAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(pilotRepositoryProvider);
    return Material(
      color: Colors.black.withValues(alpha: 0.82),
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 36),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'CUENTA',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Megatrans',
                      fontSize: 28,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: _nombre,
                    enabled: !_busy,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Megatrans',
                      letterSpacing: 2,
                    ),
                    decoration: _field('NOMBRE'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: true,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'Megatrans',
                      letterSpacing: 2,
                    ),
                    decoration: _field('CONTRASEÑA'),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.orangeAccent,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (_busy)
                    const CircularProgressIndicator(color: Colors.cyanAccent)
                  else
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 18,
                      runSpacing: 10,
                      children: [
                        TextButton(
                          onPressed: () => _run(
                            () => repo.signUp(
                              nombre: _nombre.text,
                              password: _password.text,
                            ),
                          ),
                          child: const Text(
                            'CREAR',
                            style: TextStyle(
                              color: Colors.cyanAccent,
                              fontFamily: 'Megatrans',
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _run(
                            () => repo.signIn(
                              nombre: _nombre.text,
                              password: _password.text,
                            ),
                          ),
                          child: const Text(
                            'ENTRAR',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Megatrans',
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              widget.game.overlays.remove('CreateAccount'),
                          child: const Text(
                            'VOLVER',
                            style: TextStyle(
                              color: Colors.white54,
                              fontFamily: 'Megatrans',
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

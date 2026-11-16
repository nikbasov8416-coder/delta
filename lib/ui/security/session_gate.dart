import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../domain/security/device_authenticator.dart';
import '../providers.dart';

class SessionGate extends ConsumerStatefulWidget {
  const SessionGate({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends ConsumerState<SessionGate>
    with WidgetsBindingObserver {
  final _pin = TextEditingController(), _confirmation = TextEditingController();
  late final DeviceAuthenticator _deviceAuth;
  bool _loading = true,
      _configured = false,
      _opened = false,
      _hidden = false,
      _busy = false,
      _biometric = false;
  String? _error;
  DateTime? _away;
  Timer? _timer;
  Duration _timeout = const Duration(minutes: 1);
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _deviceAuth = ref.read(deviceAuthProvider);
    _load();
  }

  Future<void> _load() async {
    try {
      final store = ref.read(secretStoreProvider);
      final configured = await ref.read(pinServiceProvider).configured;
      final enabled = await store.read('biometric_enabled') == 'true';
      final minutes =
          int.tryParse(await store.read('lock_minutes') ?? '1') ?? 1;
      _timeout = Duration(minutes: minutes.clamp(1, 60));
      final protected = await store.read('screen_protected') != 'false';
      if (Platform.isAndroid) {
        await const MethodChannel('delta/security')
            .invokeMethod<void>('setProtected', protected);
      }
      final biometric = enabled && await _deviceAuth.available();
      if (mounted) {
        setState(() {
          _configured = configured;
          _biometric = biometric;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error =
              'Не удалось открыть защищённое хранилище. Данные не изменены.';
        });
      }
    }
  }

  void _lock() {
    if (!mounted || !_opened) return;
    ref.read(sessionAccessProvider.notifier).setUnlocked(false);
    setState(() {
      _opened = false;
      _error = null;
    });
    _pin.clear();
    _confirmation.clear();
    ref.invalidate(overviewProvider);
    ref.invalidate(snapshotProvider);
    ref.invalidate(repositoryProvider);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final elapsed = _away == null
          ? Duration.zero
          : DateTime.now().difference(_away!);
      _timer?.cancel();
      _timer = null;
      if (elapsed >= _timeout) _lock();
      _away = null;
      if (mounted) setState(() => _hidden = false);
    } else {
      _away ??= DateTime.now();
      if (mounted) setState(() => _hidden = true);
      _timer ??= Timer(_timeout, _lock);
      _rescheduleLock();
    }
  }

  Future<void> _rescheduleLock() async {
    try {
      final value = await ref.read(secretStoreProvider).read('lock_minutes');
      if (!mounted || _away == null) return;
      _timeout = Duration(
        minutes: (int.tryParse(value ?? '1') ?? 1).clamp(1, 60),
      );
      final remaining = _timeout - DateTime.now().difference(_away!);
      _timer?.cancel();
      _timer = Timer(remaining.isNegative ? Duration.zero : remaining, _lock);
    } catch (_) {
      _lock();
    }
  }

  Future<void> _submit({bool biometric = false}) async {
    if (_busy || _loading) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(pinServiceProvider);
      final delay = await service.delay();
      if (delay > Duration.zero) {
        throw StateError('Повторите через ${delay.inSeconds + 1} сек.');
      }
      var success = false;
      if (!_configured) {
        if (_pin.text != _confirmation.text) {
          throw const FormatException('PIN и подтверждение не совпадают');
        }
        await service.create(_pin.text);
        success = true;
      } else if (biometric) {
        if (await ref.read(secretStoreProvider).read('biometric_enabled') ==
                'true' &&
            await _deviceAuth.available()) {
          success = await _deviceAuth.authenticate();
          if (success) await service.resetFailures();
        }
      } else {
        success = await service.verify(_pin.text);
      }
      if (!success) {
        throw StateError(
          'Вход не выполнен. Проверьте PIN или повторите подтверждение.',
        );
      }
      if (!mounted) return;
      ref.read(sessionAccessProvider.notifier).setUnlocked(true);
      if (mounted) {
        setState(() {
          _configured = true;
          _opened = true;
        });
      }
      _pin.clear();
      _confirmation.clear();
    } on FormatException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } on StateError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось подтвердить вход. Попробуйте PIN.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_opened) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Offstage(offstage: _hidden, child: widget.child),
          if (_hidden) const ColoredBox(color: Colors.black),
        ],
      );
    }
    if (_hidden) {
      return const ColoredBox(color: Colors.black, child: SizedBox.expand());
    }
    return Overlay.wrap(
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _configured ? 'Вход в Delta' : 'Создайте PIN для Delta',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    if (_loading) const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _pin,
                      obscureText: true,
                      maxLength: 6,
                      enabled: !_busy && !_loading,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'PIN из 6 цифр',
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                    if (!_configured)
                      TextField(
                        controller: _confirmation,
                        obscureText: true,
                        maxLength: 6,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Повторите PIN',
                        ),
                        enabled: !_busy && !_loading,
                      ),
                    if (_error != null)
                      Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    FilledButton(
                      onPressed: _busy || _loading ? null : () => _submit(),
                      child: Text(
                        _busy
                            ? 'Проверка…'
                            : _configured
                            ? 'Войти'
                            : 'Создать PIN',
                      ),
                    ),
                    if (_configured && _biometric)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => _submit(biometric: true),
                        child: const Text('Отпечаток / Windows Hello'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }
}

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/route_paths.dart';
import '../core/config/api_config.dart';
import '../core/constants/api_endpoints.dart';
import '../core/localization/app_localizations.dart';
import '../features/onboarding/application/onboarding_providers.dart';
import '../features/onboarding/domain/onboarding_profile.dart';
import '../firebase_options.dart';

class EmailAuthScreen extends ConsumerStatefulWidget {
  final Dio? dio;

  const EmailAuthScreen({super.key, this.dio});

  @override
  ConsumerState<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends ConsumerState<EmailAuthScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  late final Dio _dio;

  bool _register = false;
  bool _sent = false;
  bool _busy = false;
  String? _error;

  Timer? _cooldownTimer;
  int _cooldownSeconds = 0;

  static final RegExp _emailRegExp = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  @override
  void initState() {
    super.initState();
    _dio =
        widget.dio ??
        Dio(
          BaseOptions(
            baseUrl: ApiConfig.baseUrl,
            connectTimeout: ApiConfig.connectTimeout,
            receiveTimeout: ApiConfig.receiveTimeout,
            sendTimeout: ApiConfig.sendTimeout,
            contentType: 'application/json',
          ),
        );
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _email.dispose();
    _code.dispose();
    if (widget.dio == null) {
      _dio.close();
    }
    super.dispose();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    setState(() => _cooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cooldownSeconds > 1) {
          _cooldownSeconds--;
        } else {
          _cooldownSeconds = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = context.l10n;

    final email = _email.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _error = l10n.authEnterEmailError);
      return;
    }
    if (!_emailRegExp.hasMatch(email)) {
      setState(() => _error = l10n.authInvalidEmailError);
      return;
    }

    if (_sent) {
      final code = _code.text.trim();
      if (code.length != 6) {
        setState(() => _error = l10n.authEnterCodeError);
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final mode = _register ? 'register' : 'login';

    try {
      if (!_sent) {
        await _dio.post(
          ApiEndpoints.authEmailRequest,
          data: {'email': email, 'mode': mode},
        );
        if (mounted) {
          setState(() {
            _sent = true;
            _code.clear();
          });
          _startCooldown();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.authCodeSentNotice),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        final response = await _dio.post<Map<String, dynamic>>(
          ApiEndpoints.authEmailVerify,
          data: {'email': email, 'mode': mode, 'code': _code.text.trim()},
        );
        final token = response.data?['firebase_token'] as String?;
        if (token == null || token.isEmpty) {
          throw FormatException(l10n.authFailedError);
        }
        if (Firebase.apps.isNotEmpty) {
          await FirebaseAuth.instance.signInWithCustomToken(token);
        }
        if (mounted) {
          context.go(RoutePaths.splash);
        }
      }
    } on DioException catch (error) {
      if (!mounted) return;
      final detail = error.response?.data;
      String message;
      if (detail is Map && detail['detail'] != null) {
        message = '${detail['detail']}';
      } else if (error.type == DioExceptionType.connectionTimeout ||
          error.type == DioExceptionType.receiveTimeout ||
          error.type == DioExceptionType.connectionError) {
        message = l10n.authNetworkError;
      } else {
        message = l10n.authFailedError;
      }
      setState(() => _error = message);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = error is FormatException
            ? error.message
            : l10n.authFailedError,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isConfigured =
        widget.dio != null || DefaultFirebaseOptions.isConfigured;

    return Scaffold(
      appBar: AppBar(
        title: Text(_register ? l10n.authTitleRegister : l10n.authTitleLogin),
        actions: [
          TextButton.icon(
            key: const Key('auth_language_toggle'),
            icon: const Icon(Icons.language_rounded, size: 18),
            label: Text(
              l10n.isBangla ? 'English' : 'বাংলা',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            onPressed: () {
              final next = l10n.isBangla
                  ? AppLanguage.english
                  : AppLanguage.bangla;
              ref.read(onboardingControllerProvider.notifier).setLanguage(next);
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            children: [
              const Center(
                child: Icon(Icons.eco_rounded, size: 64, color: Colors.green),
              ),
              const SizedBox(height: 16),
              Text(
                _register ? l10n.authHeadingRegister : l10n.authHeadingLogin,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.authSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (!isConfigured) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F261C),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF22E57F).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        color: Color(0xFF22E57F),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n.authDemoModeNote,
                          style: const TextStyle(
                            color: Color(0xFFBFD3C8),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                key: const Key('auth_email_input'),
                controller: _email,
                enabled: !_sent && !_busy,
                keyboardType: TextInputType.emailAddress,
                textInputAction: _sent
                    ? TextInputAction.next
                    : TextInputAction.done,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(
                  labelText: l10n.authEmailLabel,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) {
                  if (!_sent) _submit();
                },
              ),
              if (_sent) ...[
                const SizedBox(height: 16),
                TextField(
                  key: const Key('auth_code_input'),
                  controller: _code,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textInputAction: TextInputAction.done,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.authCodeLabel,
                    prefixIcon: const Icon(Icons.pin_outlined),
                    counterText: '',
                  ),
                  onChanged: (_) {
                    if (_error != null) setState(() => _error = null);
                  },
                  onSubmitted: (_) => _submit(),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  key: const Key('auth_error_text'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 20),
              FilledButton(
                key: const Key('auth_submit_button'),
                onPressed: _busy ? null : _submit,
                child: Text(
                  _busy
                      ? l10n.authPleaseWait
                      : _sent
                      ? l10n.authVerifyAndContinue
                      : l10n.authSendCode,
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('auth_mode_toggle_button'),
                onPressed: _busy
                    ? null
                    : () => setState(() {
                        _register = !_register;
                        _sent = false;
                        _code.clear();
                        _error = null;
                        _cooldownSeconds = 0;
                        _cooldownTimer?.cancel();
                      }),
                child: Text(
                  _register
                      ? l10n.authSwitchToLogin
                      : l10n.authSwitchToRegister,
                ),
              ),
              if (_sent)
                TextButton(
                  key: const Key('auth_resend_button'),
                  onPressed: _busy || _cooldownSeconds > 0
                      ? null
                      : () {
                          setState(() {
                            _sent = false;
                            _code.clear();
                            _error = null;
                          });
                        },
                  child: Text(
                    _cooldownSeconds > 0
                        ? l10n.authResendInSeconds(_cooldownSeconds)
                        : l10n.authRequestAnotherCode,
                  ),
                ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const Key('auth_demo_mode_button'),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: Text(l10n.authDemoModeAction),
                onPressed: _busy ? null : () => context.go(RoutePaths.splash),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

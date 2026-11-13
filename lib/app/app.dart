import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_localizations.dart';
import '../core/theme/app_theme.dart';
import '../features/fields/application/fields_providers.dart';
import '../features/onboarding/application/onboarding_providers.dart';
import '../features/onboarding/domain/onboarding_profile.dart';
import '../features/voice_guide/presentation/voice_guide_overlay.dart';
import 'router.dart';

class AgriGuardianApp extends ConsumerStatefulWidget {
  const AgriGuardianApp({super.key});

  @override
  ConsumerState<AgriGuardianApp> createState() => _AgriGuardianAppState();
}

class _AgriGuardianAppState extends ConsumerState<AgriGuardianApp> {
  StreamSubscription<bool>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    startAuthRouterRefresh();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final connectivity = ref.read(connectivityServiceProvider);
      _connectivitySub = connectivity.onConnectivityChanged().listen((
        isConnected,
      ) {
        if (isConnected) {
          ref.read(fieldSyncServiceProvider).syncPendingMutations();
        }
      });
      // Initial sync check on startup
      ref.read(fieldSyncServiceProvider).syncPendingMutations();
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final language =
        ref.watch(onboardingControllerProvider).valueOrNull?.language ??
        AppLanguage.bangla;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: AppLocalizations.forLocale(Locale(language.code)).appTitle,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      locale: Locale(language.code),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: appRouter,
      // Floating Bangla voice-guide button, drawn above every route.
      builder: (context, child) =>
          VoiceGuideOverlay(child: child ?? const SizedBox.shrink()),
    );
  }
}

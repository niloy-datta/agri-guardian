import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../application/weather_providers.dart';
import '../../domain/weather_risk_models.dart';
import '../widgets/weather_hero_card.dart';
import '../widgets/weather_sections.dart';
import '../widgets/weather_states.dart';
import '../widgets/weather_theme.dart';

/// আবহাওয়া ঝুঁকি কেন্দ্র - nested under the Home shell branch, so
/// `MainShell`'s bottom nav stays visible below it.
///
/// Reads only [WeatherRiskSnapshot]; which repository fills it (demo for
/// now - see `weather_providers.dart`) is decided outside this screen.
class WeatherScreen extends ConsumerWidget {
  const WeatherScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshotAsync = ref.watch(weatherRiskSnapshotProvider);
    final isOffline =
        ref.watch(weatherIsOfflineProvider).valueOrNull ?? false;
    // valueOrNull, not value: in the error state `.value` rethrows.
    final snapshot = snapshotAsync.valueOrNull;

    void retry() => ref.invalidate(weatherRiskSnapshotProvider);

    return Scaffold(
      backgroundColor: WeatherTheme.bg,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: RefreshIndicator(
              color: WeatherTheme.green,
              backgroundColor: WeatherTheme.card,
              onRefresh: () => ref.refresh(weatherRiskSnapshotProvider.future),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                children: [
                  _Header(origin: snapshot?.origin),
                  const SizedBox(height: 14),
                  if (isOffline) ...[
                    WeatherOfflineBanner(origin: snapshot?.origin),
                    const SizedBox(height: 10),
                  ],
                  ...snapshotAsync.when(
                    skipLoadingOnRefresh: true,
                    loading: () => const [WeatherLoadingSkeleton()],
                    error: (_, _) => [WeatherErrorView(onRetry: retry)],
                    data: (s) => _content(context, s),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context, WeatherRiskSnapshot s) {
    final alert = s.alert;
    return [
      if (s.origin != WeatherDataOrigin.live) ...[
        WeatherOriginBanner(origin: s.origin, retrievedAt: s.retrievedAt),
        const SizedBox(height: 12),
      ],
      WeatherHeroCard(snapshot: s),
      const SizedBox(height: 12),
      WeatherRiskStrip(hazards: s.hazards),
      const SizedBox(height: 22),
      WeatherReveal(
        index: 2,
        child: WeatherDecisionCard(decision: s.irrigation, origin: s.origin),
      ),
      if (alert != null) ...[
        const SizedBox(height: 12),
        WeatherReveal(index: 3, child: WeatherAlertCard(alert: alert)),
      ],
      const SizedBox(height: 22),
      WeatherSectionTitle(title: context.l10n.forecast7Days),
      const SizedBox(height: 10),
      WeatherForecastCard(days: s.forecast),
      const SizedBox(height: 22),
      WeatherSectionTitle(title: context.l10n.dataAndEvidence),
      const SizedBox(height: 10),
      WeatherEvidenceCard(snapshot: s),
    ];
  }
}

class _Header extends StatelessWidget {
  final WeatherDataOrigin? origin;

  const _Header({required this.origin});

  void _back(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      GoRouter.maybeOf(context)?.go(RoutePaths.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final origin = this.origin;
    return Row(
      children: [
        WeatherPressable(
          onTap: () => _back(context),
          child: Semantics(
            button: true,
            label: context.l10n.goBack,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: WeatherTheme.card,
                shape: BoxShape.circle,
                border: Border.all(color: WeatherTheme.line),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: WeatherTheme.text,
                size: 19,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.weatherCenterTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: WeatherTheme.text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        if (origin != null) ...[
          const SizedBox(width: 8),
          WeatherPill(
            key: const ValueKey('weather-origin-chip'),
            label: origin.label(context.l10n),
            color: origin.color,
          ),
        ],
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';

import '../../domain/weather_risk_models.dart';
import 'weather_theme.dart';

// ============================================================
// Risk strip
// ============================================================

class WeatherRiskStrip extends StatelessWidget {
  final List<HazardRisk> hazards;

  const WeatherRiskStrip({super.key, required this.hazards});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < hazards.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: WeatherReveal(
              index: i + 1,
              child: _HazardCard(hazard: hazards[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _HazardCard extends StatelessWidget {
  final HazardRisk hazard;
  const _HazardCard({required this.hazard});

  IconData get _icon => switch (hazard.kind) {
    WeatherHazardKind.rainfall => Icons.grain_rounded,
    WeatherHazardKind.heat => Icons.thermostat_rounded,
    WeatherHazardKind.wind => Icons.air_rounded,
  };

  String _label(AppLocalizations l10n) => switch (hazard.kind) {
    WeatherHazardKind.rainfall => l10n.hazardRainfall,
    WeatherHazardKind.heat => l10n.hazardHeat,
    WeatherHazardKind.wind => l10n.hazardWind,
  };

  @override
  Widget build(BuildContext context) {
    final icon = _icon;
    final label = _label(context.l10n);
    final color = hazard.level.color;
    final reduce = WeatherTheme.reduceMotion(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 11),
      decoration: WeatherTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 15),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  hazard.level.label(context.l10n),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: WeatherTheme.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          // Risk meter animates from empty to its level.
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 4,
              child: Stack(
                children: [
                  Container(color: WeatherTheme.line),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: hazard.level.fraction),
                    duration: reduce
                        ? Duration.zero
                        : const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, v, _) => FractionallySizedBox(
                      widthFactor: v,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color.withValues(alpha: 0.6), color],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hazard.detail.resolve(isBangla: context.l10n.isBangla),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: WeatherTheme.muted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 7-day forecast
// ============================================================

class WeatherForecastCard extends StatelessWidget {
  final List<DailyForecast> days;

  const WeatherForecastCard({super.key, required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      decoration: WeatherTheme.cardDecoration(),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 300;
          return Column(
            children: [
              for (var i = 0; i < days.length; i++) ...[
                if (i > 0)
                  Divider(height: 1, thickness: 1, color: WeatherTheme.line),
                WeatherReveal(
                  index: i,
                  child: _ForecastRow(
                    key: ValueKey('weather-forecast-day-$i'),
                    day: days[i],
                    isToday: i == 0,
                    compact: compact,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ForecastRow extends StatelessWidget {
  final DailyForecast day;
  final bool isToday;
  final bool compact;

  const _ForecastRow({
    super.key,
    required this.day,
    required this.isToday,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final riskColor = day.risk.color;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: compact ? 50 : 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? context.l10n.todayLabel : context.l10n.weekdayShort(day.date),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isToday ? WeatherTheme.mint : WeatherTheme.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  context.l10n.dayMonth(day.date.day, day.date.month),
                  style: const TextStyle(
                    color: WeatherTheme.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Icon(day.condition.icon, color: day.condition.tint, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.water_drop_rounded,
                  color: WeatherTheme.blue,
                  size: 11,
                ),
                const SizedBox(width: 3),
                Flexible(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 30),
                    child: Text(
                      '${context.l10n.digits(day.rainProbabilityPercent)}%',
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.fade,
                      style: const TextStyle(
                        color: WeatherTheme.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                if (!compact)
                  Expanded(
                    flex: 2,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: day.rainProbabilityPercent / 100,
                        minHeight: 3,
                        backgroundColor: WeatherTheme.line,
                        valueColor: AlwaysStoppedAnimation(
                          WeatherTheme.blue.withValues(alpha: 0.75),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: context.l10n.temperature(day.maxTempC),
                  style: const TextStyle(
                    color: WeatherTheme.text,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: ' / ${context.l10n.temperature(day.minTempC)}',
                  style: const TextStyle(
                    color: WeatherTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            style: const TextStyle(fontSize: 12.5),
          ),
          const SizedBox(width: 8),
          Tooltip(
            message: context.l10n.riskPrefixed(day.risk.label(context.l10n)),
            child: Container(
              width: compact ? 10 : 40,
              height: compact ? 10 : 20,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: riskColor.withValues(alpha: compact ? 1 : 0.14),
                borderRadius: BorderRadius.circular(10),
                border: compact
                    ? null
                    : Border.all(color: riskColor.withValues(alpha: 0.4)),
              ),
              child: compact
                  ? null
                  : Text(
                      day.risk.label(context.l10n),
                      maxLines: 1,
                      style: TextStyle(
                        color: riskColor,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// "আজ কী করবেন?" farm decision
// ============================================================

class WeatherDecisionCard extends StatefulWidget {
  final IrrigationDecision decision;
  final WeatherDataOrigin origin;

  const WeatherDecisionCard({
    super.key,
    required this.decision,
    required this.origin,
  });

  @override
  State<WeatherDecisionCard> createState() => _WeatherDecisionCardState();
}

class _WeatherDecisionCardState extends State<WeatherDecisionCard> {
  bool _expanded = false;

  (IconData, Color) get _actionMeta => switch (widget.decision.action) {
    IrrigationAction.irrigate => (Icons.water_rounded, WeatherTheme.blue),
    IrrigationAction.reduce => (Icons.opacity_rounded, WeatherTheme.amber),
    IrrigationAction.skip => (Icons.block_rounded, WeatherTheme.mint),
  };

  String _actionLabel(AppLocalizations l10n) => switch (widget.decision.action) {
    IrrigationAction.irrigate => l10n.actionIrrigate,
    IrrigationAction.reduce => l10n.actionReduce,
    IrrigationAction.skip => l10n.actionSkip,
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _actionMeta;
    final actionLabel = _actionLabel(context.l10n);
    final isDemo = widget.origin == WeatherDataOrigin.demo;
    final reduce = WeatherTheme.reduceMotion(context);

    return Container(
      key: const ValueKey('weather-decision'),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(WeatherTheme.radius + 2),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            WeatherTheme.mint.withValues(alpha: 0.55),
            WeatherTheme.green.withValues(alpha: 0.12),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: WeatherTheme.green.withValues(alpha: 0.16),
            blurRadius: 26,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(1.4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(WeatherTheme.radius),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F2B1F), Color(0xFF0A1C15), Color(0xFF07130E)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.l10n.decisionTitle,
                        style: TextStyle(
                          color: WeatherTheme.text,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      WeatherEnLabel(context.l10n.decisionCaption),
                    ],
                  ),
                ),
                if (isDemo)
                  WeatherPill(
                    label: context.l10n.demoGuidancePill,
                    color: WeatherTheme.amber,
                    dense: true,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        actionLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.decision.headline.resolve(
                          isBangla: context.l10n.isBangla,
                        ),
                        style: const TextStyle(
                          color: WeatherTheme.text,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.decision.reason.resolve(
                          isBangla: context.l10n.isBangla,
                        ),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            WeatherPressable(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: WeatherTheme.border),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      color: WeatherTheme.muted,
                      size: 15,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        context.l10n.adviceBasisQuestion,
                        style: TextStyle(
                          color: WeatherTheme.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: reduce
                          ? Duration.zero
                          : const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: WeatherTheme.muted,
                        size: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: reduce
                  ? Duration.zero
                  : const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        isDemo
                            ? context.l10n.adviceBasisDemo
                            : context.l10n.adviceBasisLive,
                        style: const TextStyle(
                          color: WeatherTheme.muted,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          height: 1.45,
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// Extreme weather alert
// ============================================================

class WeatherAlertCard extends StatefulWidget {
  final WeatherRiskAlert alert;

  const WeatherAlertCard({super.key, required this.alert});

  @override
  State<WeatherAlertCard> createState() => _WeatherAlertCardState();
}

class _WeatherAlertCardState extends State<WeatherAlertCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (WeatherTheme.reduceMotion(context)) {
      _pulse.stop();
    } else if (!_pulse.isAnimating) {
      _pulse.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alert = widget.alert;
    final color = alert.level.color;

    return Container(
      key: const ValueKey('weather-alert'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(WeatherTheme.radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.16),
            WeatherTheme.card,
            WeatherTheme.card,
          ],
        ),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            height: 46,
            child: AnimatedBuilder(
              animation: _pulse,
              builder: (context, child) {
                final v = _pulse.value;
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    if (_pulse.isAnimating)
                      Container(
                        width: 30 + 16 * v,
                        height: 30 + 16 * v,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color.withValues(alpha: 0.5 * (1 - v)),
                            width: 1.5,
                          ),
                        ),
                      ),
                    child!,
                  ],
                );
              },
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.warning_amber_rounded, color: color, size: 20),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      alert.title.resolve(isBangla: context.l10n.isBangla),
                      style: const TextStyle(
                        color: WeatherTheme.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    WeatherPill(
                      label: context.l10n.severityLabel(alert.level.label(context.l10n)),
                      color: color,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  alert.detail.resolve(isBangla: context.l10n.isBangla),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded, color: color, size: 13),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        alert.window.resolve(isBangla: context.l10n.isBangla),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Data & evidence
// ============================================================

class WeatherEvidenceCard extends StatelessWidget {
  final WeatherRiskSnapshot snapshot;

  const WeatherEvidenceCard({super.key, required this.snapshot});

  @override
  Widget build(BuildContext context) {
    final retrievedAt = snapshot.retrievedAt;
    final origin = snapshot.origin;

    return Container(
      key: const ValueKey('weather-evidence'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: WeatherTheme.cardDecoration(),
      child: Column(
        children: [
          _MetaRow(
            label: context.l10n.dataTypeLabel,
            value: origin.label(context.l10n),
            valueColor: origin.color,
          ),
          _MetaRow(
            label: context.l10n.lastUpdatedLabel,
            value: retrievedAt == null
                ? context.l10n.notApplicableNotFetched
                : '${context.l10n.dayMonth(retrievedAt.day, retrievedAt.month)} '
                      '${context.l10n.clockTime(retrievedAt)}',
            valueColor: WeatherTheme.text,
          ),
          const SizedBox(height: 6),
          Divider(height: 1, color: WeatherTheme.line),
          for (final source in snapshot.sources) _SourceRow(source: source),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _MetaRow({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: const TextStyle(
                color: WeatherTheme.muted,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final EvidenceSource source;
  const _SourceRow({required this.source});

  (IconData, Color) get _statusMeta => switch (source.status) {
    EvidenceSourceStatus.connected => (Icons.check_circle_rounded, WeatherTheme.green),
    EvidenceSourceStatus.unavailable => (Icons.link_off_rounded, WeatherTheme.muted),
    EvidenceSourceStatus.demo => (Icons.science_outlined, WeatherTheme.amber),
  };

  String _statusLabel(AppLocalizations l10n) => switch (source.status) {
    EvidenceSourceStatus.connected => l10n.sourceConnected,
    EvidenceSourceStatus.unavailable => l10n.sourceNotConnected,
    EvidenceSourceStatus.demo => l10n.sourceDemo,
  };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _statusMeta;
    final statusText = _statusLabel(context.l10n);
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  source.name.resolve(isBangla: context.l10n.isBangla),
                  style: const TextStyle(
                    color: WeatherTheme.text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  source.description.resolve(isBangla: context.l10n.isBangla),
                  style: const TextStyle(
                    color: WeatherTheme.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          WeatherPill(label: statusText, color: color, dense: true),
        ],
      ),
    );
  }
}

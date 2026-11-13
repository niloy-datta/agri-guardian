import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../shared/models/field.dart' show GeoJsonPolygon;
import '../../../fields/presentation/widgets/field_boundary_picker.dart';
import '../../application/onboarding_providers.dart';
import '../../domain/onboarding_profile.dart';
import 'farm_info_screen.dart' show onboardingCommonCrops;
import '../widgets/onboarding_scaffold.dart';

/// Opens the real boundary picker. Injectable so widget tests can drive
/// this step without a map tile server.
typedef BoundaryPicker = Future<GeoJsonPolygon?> Function(BuildContext context);

final onboardingBoundaryPickerProvider = Provider<BoundaryPicker>((ref) {
  return showFieldBoundaryPicker;
});

/// Step 4 - the field itself. The boundary comes from the same picker
/// "My Fields" uses, so what the farmer draws here is a real polygon, not
/// a mock shape. Soil type and previous crop are optional.
class OnboardingFieldScreen extends ConsumerStatefulWidget {
  const OnboardingFieldScreen({super.key});

  @override
  ConsumerState<OnboardingFieldScreen> createState() =>
      _OnboardingFieldScreenState();
}

class _OnboardingFieldScreenState extends ConsumerState<OnboardingFieldScreen> {
  FieldBoundaryDraft? _boundary;
  String? _previousCrop;
  SoilType? _soil;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingControllerProvider).valueOrNull;
    _boundary = saved?.fieldBoundary;
    _previousCrop = saved?.previousCrop;
    _soil = saved?.soilType;
  }

  Future<void> _drawBoundary() async {
    final picker = ref.read(onboardingBoundaryPickerProvider);
    final polygon = await picker(context);
    if (polygon == null || !mounted) return;

    setState(() {
      _boundary = FieldBoundaryDraft(
        geoJson: polygon,
        vertexCount: _vertexCount(polygon),
      );
    });
  }

  /// Counts the ring's vertices, excluding the closing point that repeats
  /// the first (RFC 7946).
  static int _vertexCount(GeoJsonPolygon polygon) {
    final coordinates = polygon['coordinates'];
    if (coordinates is! List || coordinates.isEmpty) return 0;
    final ring = coordinates.first;
    if (ring is! List || ring.isEmpty) return 0;
    return ring.length - 1;
  }

  Future<void> _continue() async {
    await ref
        .read(onboardingControllerProvider.notifier)
        .setFieldDetails(
          boundary: _boundary,
          previousCrop: _previousCrop,
          soilType: _soil,
        );
    if (mounted) context.go(RoutePaths.onboardingGoal);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final boundary = _boundary;

    return OnboardingScaffold(
      step: 4,
      title: l10n.markYourField,
      subtitle: l10n.markFieldSubtitle,
      onBack: () => context.go(RoutePaths.onboardingFarm),
      primaryLabel: l10n.nextStep,
      onPrimary: _continue,
      secondaryLabel: boundary == null ? l10n.skipForNow : null,
      onSecondary: boundary == null ? _continue : null,
      children: [
        _BoundaryCard(boundary: boundary, onDraw: _drawBoundary),
        const SizedBox(height: 22),
        Text(
          l10n.previousCropQuestion,
          style: TextStyle(
            color: OnboardingTheme.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final crop in onboardingCommonCrops)
              _SmallChip(
                label: l10n.cropName(crop),
                selected: _previousCrop == crop,
                onTap: () => setState(
                  () => _previousCrop = _previousCrop == crop ? null : crop,
                ),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          l10n.soilTypeQuestion,
          style: TextStyle(
            color: OnboardingTheme.muted,
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final soil in SoilType.values)
              _SmallChip(
                key: ValueKey('onboarding-soil-${soil.name}'),
                label: _soilLabel(l10n, soil),
                selected: _soil == soil,
                onTap: () =>
                    setState(() => _soil = _soil == soil ? null : soil),
              ),
          ],
        ),
      ],
    );
  }

  static String _soilLabel(AppLocalizations l10n, SoilType soil) =>
      switch (soil) {
        SoilType.clay => l10n.soilClay,
        SoilType.loam => l10n.soilLoam,
        SoilType.sandy => l10n.soilSandy,
        SoilType.silt => l10n.soilSilt,
        SoilType.unknown => l10n.soilUnknown,
      };
}

class _BoundaryCard extends StatelessWidget {
  final FieldBoundaryDraft? boundary;
  final VoidCallback onDraw;

  const _BoundaryCard({required this.boundary, required this.onDraw});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final drawn = boundary != null;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(OnboardingTheme.radius),
        border: Border.all(
          color: drawn ? OnboardingTheme.green : OnboardingTheme.border,
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 140,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/images/runtime/satellite_field.jpg',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: OnboardingTheme.cardRaised,
                    child: const Icon(
                      Icons.map_rounded,
                      color: OnboardingTheme.green,
                      size: 34,
                    ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.25),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
                if (drawn)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: OnboardingTheme.green.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: OnboardingTheme.green),
                        ),
                        child: Text(
                          l10n.pointCount(boundary!.vertexCount),
                          style: const TextStyle(
                            color: OnboardingTheme.green,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        drawn ? l10n.boundaryDrawn : l10n.boundaryNotDrawn,
                        style: TextStyle(
                          color: drawn
                              ? OnboardingTheme.green
                              : OnboardingTheme.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        drawn ? l10n.canRedrawBoundary : l10n.tapMapToDraw,
                        style: const TextStyle(
                          color: OnboardingTheme.muted,
                          fontSize: 11.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                FilledButton.icon(
                  key: const ValueKey('onboarding-draw-field'),
                  onPressed: onDraw,
                  icon: Icon(
                    drawn ? Icons.edit_rounded : Icons.draw_rounded,
                    size: 17,
                  ),
                  label: Text(drawn ? l10n.redrawBoundary : l10n.drawBoundary),
                  style: FilledButton.styleFrom(
                    backgroundColor: OnboardingTheme.green,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SmallChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: OnboardingTheme.reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 40),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          decoration: BoxDecoration(
            color: selected
                ? OnboardingTheme.mint.withValues(alpha: 0.12)
                : OnboardingTheme.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? OnboardingTheme.mint : OnboardingTheme.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? OnboardingTheme.mint : OnboardingTheme.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

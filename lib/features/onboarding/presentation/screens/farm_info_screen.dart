import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../application/onboarding_providers.dart';
import '../widgets/onboarding_scaffold.dart';

const onboardingCommonCrops = [
  'বোরো ধান',
  'আমন ধান',
  'গম',
  'ভুট্টা',
  'আলু',
  'পাট',
  'সরিষা',
  'টমেটো',
];

/// Step 3 - who the farmer is and what they are growing now.
class OnboardingFarmInfoScreen extends ConsumerStatefulWidget {
  const OnboardingFarmInfoScreen({super.key});

  @override
  ConsumerState<OnboardingFarmInfoScreen> createState() =>
      _OnboardingFarmInfoScreenState();
}

class _OnboardingFarmInfoScreenState
    extends ConsumerState<OnboardingFarmInfoScreen> {
  final _nameController = TextEditingController();
  final _sizeController = TextEditingController();
  String? _crop;
  bool _restored = false;

  void _restoreSavedProfile() {
    final saved = ref.watch(onboardingControllerProvider).valueOrNull;
    if (_restored || saved == null) return;
    _restored = true;
    _nameController.text = saved.farmerName ?? '';
    final size = saved.farmSizeAcres;
    if (size != null) _sizeController.text = _trim(size);
    _crop = saved.currentCrop;
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void dispose() {
    _nameController.dispose();
    _sizeController.dispose();
    super.dispose();
  }

  double? get _parsedSize {
    var raw = _sizeController.text.trim();
    const digits = '০১২৩৪৫৬৭৮৯';
    for (var i = 0; i < digits.length; i++) {
      raw = raw.replaceAll(digits[i], '$i');
    }
    if (raw.isEmpty) return null;
    final value = double.tryParse(raw);
    if (value == null || !value.isFinite || value <= 0) return null;
    return value;
  }

  bool get _canContinue =>
      _nameController.text.trim().isNotEmpty &&
      _parsedSize != null &&
      (_crop?.isNotEmpty ?? false);

  Future<void> _continue() async {
    if (!_canContinue) return;
    await ref
        .read(onboardingControllerProvider.notifier)
        .setFarmInfo(
          farmerName: _nameController.text.trim(),
          farmSizeAcres: _parsedSize!,
          currentCrop: _crop!,
        );
    if (mounted) context.go(RoutePaths.onboardingField);
  }

  @override
  Widget build(BuildContext context) {
    _restoreSavedProfile();
    final l10n = AppLocalizations.of(context);
    final sizeText = _sizeController.text.trim();
    final sizeInvalid = sizeText.isNotEmpty && _parsedSize == null;

    return OnboardingScaffold(
      step: 3,
      title: l10n.aboutYourFarm,
      subtitle: l10n.farmInfoPrivacy,
      onBack: () => context.go(RoutePaths.onboardingLanguage),
      primaryLabel: l10n.nextStep,
      onPrimary: _canContinue ? _continue : null,
      children: [
        OnboardingTextField(
          key: const ValueKey('onboarding-farmer-name'),
          controller: _nameController,
          label: l10n.yourName,
          hint: l10n.yourNameHint,
          icon: Icons.person_outline_rounded,
          onChanged: (_) => setState(() => _restored = true),
        ),
        const SizedBox(height: 16),
        OnboardingTextField(
          key: const ValueKey('onboarding-farm-size'),
          controller: _sizeController,
          label: l10n.farmSize,
          hint: l10n.farmSizeHint,
          icon: Icons.crop_square_rounded,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          suffix: l10n.acreUnit,
          onChanged: (_) => setState(() => _restored = true),
        ),
        if (sizeInvalid) ...[
          const SizedBox(height: 6),
          Text(
            l10n.farmSizeInvalid,
            style: TextStyle(
              color: OnboardingTheme.amber,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        const SizedBox(height: 20),
        Text(
          l10n.currentCropQuestion,
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
              _CropChip(
                label: l10n.cropName(crop),
                selected: _crop == crop,
                onTap: () => setState(() {
                  _restored = true;
                  _crop = crop;
                }),
              ),
          ],
        ),
      ],
    );
  }
}

class _CropChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CropChip({
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
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: OnboardingTheme.reduceMotion(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected
                ? OnboardingTheme.green.withValues(alpha: 0.12)
                : OnboardingTheme.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? OnboardingTheme.green : OnboardingTheme.border,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? OnboardingTheme.green : OnboardingTheme.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }
}

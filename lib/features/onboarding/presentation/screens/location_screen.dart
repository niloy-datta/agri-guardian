import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../application/onboarding_providers.dart';
import '../../data/device_location_resolver.dart';
import '../../domain/onboarding_profile.dart';

final deviceLocationResolverProvider = Provider<DeviceLocationResolver>((ref) {
  return GeolocatorLocationResolver();
});

/// Step 1 / Splash 2 - Farm Location setup.
///
/// Features cinematic satellite targeting artwork (satellite light pyramid
/// focusing on the agricultural plot with a glowing location pin).
/// Clean, futuristic design with minimal copy:
/// - Top small label: FARM LOCATION
/// - Main title: Where is your farm?
/// - Subtitle: Set your location to personalize weather, crops and field insights.
/// - Primary: Use My Location
/// - Secondary: Choose Manually
/// - Bottom small text: You can change this anytime.
class OnboardingLocationScreen extends ConsumerStatefulWidget {
  const OnboardingLocationScreen({super.key});

  @override
  ConsumerState<OnboardingLocationScreen> createState() =>
      _OnboardingLocationScreenState();
}

class _OnboardingLocationScreenState
    extends ConsumerState<OnboardingLocationScreen> {
  static const _bg = Color(0xFF050C09);
  static const _green = Color(0xFF22E57F);
  static const _text = Color(0xFFF5FFF8);
  static const _muted = Color(0xFFBFD3C8);
  static const _heroImage = 'assets/images/runtime/hero_location_pin.png';

  final _areaController = TextEditingController();

  LocationMode? _mode;
  bool _locating = false;
  double? _latitude;
  double? _longitude;
  LocationFailure? _failure;

  @override
  void initState() {
    super.initState();
    final saved = ref.read(onboardingControllerProvider).valueOrNull?.location;
    if (saved != null) {
      _mode = saved.mode;
      _areaController.text = saved.label;
      _latitude = saved.latitude;
      _longitude = saved.longitude;
    }
  }

  @override
  void dispose() {
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _useDeviceLocation() async {
    setState(() {
      _mode = LocationMode.device;
      _locating = true;
      _failure = null;
    });

    final result = await ref.read(deviceLocationResolverProvider).resolve();
    if (!mounted) return;

    setState(() {
      _locating = false;
      if (result.isSuccess) {
        _latitude = result.latitude;
        _longitude = result.longitude;
      } else {
        _latitude = null;
        _longitude = null;
        _failure = result.failure;
        _mode = LocationMode.manual;
      }
    });
  }

  void _chooseManually() {
    setState(() {
      _mode = LocationMode.manual;
      _latitude = null;
      _longitude = null;
      _failure = null;
    });
  }

  bool get _canContinue =>
      _mode != null &&
      (_areaController.text.trim().isNotEmpty || _latitude != null) &&
      !_locating;

  Future<void> _continue() async {
    final label = _areaController.text.trim().isNotEmpty
        ? _areaController.text.trim()
        : (_latitude != null
              ? formatCoordinates(_latitude!, _longitude!)
              : 'Bangladesh');

    await ref
        .read(onboardingControllerProvider.notifier)
        .setLocation(
          buildFarmLocation(
            mode: _latitude != null ? LocationMode.device : LocationMode.manual,
            label: label,
            latitude: _latitude,
            longitude: _longitude,
          ),
        );
    if (mounted) context.go(RoutePaths.onboardingLanguage);
  }

  /// Localized text for a failed device-location attempt. Failures are
  /// stable codes from the data layer; the wording lives in the catalog.
  static String _failureText(AppLocalizations l10n, LocationFailure failure) =>
      switch (failure) {
        LocationFailure.permissionDenied => l10n.locationPermissionDenied,
        LocationFailure.serviceDisabled => l10n.locationServiceOff,
        LocationFailure.unavailable => l10n.locationUnavailable,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = _failure;
    final hasFix = _latitude != null && _longitude != null;

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Full-bleed cinematic satellite location artwork
          Image.asset(
            _heroImage,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            errorBuilder: (_, _, _) => const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF0A1F16), Color(0xFF071710), _bg],
                ),
              ),
            ),
          ),

          // Scrim gradients: legibility protection for top copy and bottom actions
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _bg.withValues(alpha: 0.78),
                    _bg.withValues(alpha: 0.25),
                    Colors.transparent,
                    _bg.withValues(alpha: 0.50),
                    _bg.withValues(alpha: 0.92),
                  ],
                  stops: const [0.0, 0.26, 0.50, 0.75, 1.0],
                ),
              ),
            ),
          ),

          // Content Layout
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Back button & Top small label
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () => context.go(RoutePaths.splash),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: _text,
                          size: 18,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.40),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: _green.withValues(alpha: 0.35),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _green.withValues(alpha: 0.12),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: _green,
                              size: 14,
                            ),
                            SizedBox(width: 6),
                            Text(
                              l10n.locationEyebrow,
                              style: TextStyle(
                                color: _text,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Main title: "Where is your farm?"
                  Text(
                    l10n.whereIsFarm,
                    style: TextStyle(
                      color: _text,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                      letterSpacing: -0.6,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 16,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Subtitle: "Set your location to personalize weather, crops and field insights."
                  Text(
                    l10n.locationSubtitle,
                    style: TextStyle(
                      color: _muted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      shadows: [
                        Shadow(
                          color: Colors.black87,
                          blurRadius: 10,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),

                  // Center area with status feedback
                  const Spacer(),

                  if (_locating) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _green.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _green,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text(
                            l10n.locatingFarm,
                            style: TextStyle(
                              color: _text,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (hasFix) ...[
                    Container(
                      key: const ValueKey('onboarding-location-fix'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: _green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _green.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle_rounded,
                            color: _green,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l10n.locationFixed,
                                  style: TextStyle(
                                    color: _green,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  formatCoordinates(_latitude!, _longitude!),
                                  style: const TextStyle(
                                    color: _text,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (failure != null) ...[
                    Container(
                      key: const ValueKey('onboarding-location-failure'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.amber.withValues(alpha: 0.45),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: Colors.amber,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _failureText(l10n, failure),
                              style: const TextStyle(
                                color: Colors.amber,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  if (_mode != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.50),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _green.withValues(alpha: 0.35),
                        ),
                      ),
                      child: TextField(
                        controller: _areaController,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          icon: Icon(
                            Icons.place_rounded,
                            color: _green,
                            size: 18,
                          ),
                          hintText: l10n.areaOrDistrictHint,
                          hintStyle: TextStyle(
                            color: Color(0xFF7E978B),
                            fontSize: 13,
                          ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // Action Buttons Section
                  if (_mode == null) ...[
                    // Primary button: Use My Location
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        key: const ValueKey('onboarding-use-my-location'),
                        onPressed: _locating ? null : _useDeviceLocation,
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: Text(l10n.useMyLocation),
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: _bg,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 10,
                          shadowColor: _green.withValues(alpha: 0.40),
                          textStyle: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Secondary button: Choose Manually
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        key: const ValueKey('onboarding-choose-manually'),
                        onPressed: _chooseManually,
                        icon: const Icon(
                          Icons.edit_location_alt_rounded,
                          size: 18,
                        ),
                        label: Text(l10n.chooseManually),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _text,
                          side: BorderSide(
                            color: _text.withValues(alpha: 0.22),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          backgroundColor: Colors.black.withValues(alpha: 0.35),
                          textStyle: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    // Continue button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        key: const ValueKey('onboarding-continue'),
                        onPressed: _canContinue ? _continue : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          foregroundColor: _bg,
                          disabledBackgroundColor: _green.withValues(
                            alpha: 0.25,
                          ),
                          disabledForegroundColor: _text.withValues(
                            alpha: 0.35,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 10,
                          shadowColor: _green.withValues(alpha: 0.40),
                          textStyle: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(l10n.nextStep),
                            SizedBox(width: 8),
                            Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Switch option
                    Center(
                      child: TextButton(
                        onPressed: _mode == LocationMode.manual
                            ? _useDeviceLocation
                            : _chooseManually,
                        style: TextButton.styleFrom(
                          foregroundColor: _muted,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                        ),
                        child: Text(
                          _mode == LocationMode.manual
                              ? l10n.useGpsInstead
                              : l10n.typeDifferentArea,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Bottom small text: "You can change this anytime."
                  Center(
                    child: Text(
                      l10n.locationChangeAnytime,
                      style: TextStyle(
                        color: Color(0xFF7E978B),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

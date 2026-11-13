import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/route_paths.dart';
import '../core/localization/app_localizations.dart';
import '../features/onboarding/application/onboarding_providers.dart';
import '../features/onboarding/domain/onboarding_profile.dart';
import '../services/firebase_service.dart';
import '../shared/demo/showcase_story.dart';

class ProfileScreen extends ConsumerWidget {
  final VoidCallback? onBack;

  const ProfileScreen({super.key, this.onBack});

  static const bg = Color(0xFF06110E);
  static const card = Color(0xFF0D1D18);
  static const card2 = Color(0xFF10271E);
  static const line = Color(0xFF1D382F);

  static const green = Color(0xFF20E27A);
  static const blue = Color(0xFF4DA3FF);
  static const orange = Color(0xFFFFB020);

  static const text = Color(0xFFF5FFF8);
  static const muted = Color(0xFF8EA69A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    var l10n = AppLocalizations.of(context);
    var language = AppLanguage.bangla;
    // Some standalone showcase tests render this screen without a
    // ProviderScope. The real app always has one, but the fallback keeps the
    // screen renderable in isolation too.
    try {
      language =
          ref.watch(onboardingControllerProvider).valueOrNull?.language ??
          AppLanguage.bangla;
    } on StateError {
      language = AppLanguage.bangla;
      // Preserve the legacy English showcase output when this standalone
      // screen is rendered outside the app's ProviderScope and delegates.
      l10n = AppLocalizations.forLocale(const Locale('en'));
    }

    return Scaffold(
      backgroundColor: bg,

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),

            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),

              children: [
                ListTile(
                  title: Text(
                    FirebaseService.instance.currentUser?.email ??
                        context.l10n.account,
                  ),
                  trailing: TextButton(
                    onPressed: FirebaseService.instance.currentUser == null
                        ? null
                        : () async {
                            await FirebaseService.instance.signOut();
                            if (context.mounted) context.go(RoutePaths.auth);
                          },
                    child: Text(context.l10n.logOut),
                  ),
                ),
                // HEADER
                Row(
                  children: [
                    if (onBack != null) ...[
                      IconButton(
                        onPressed: onBack,
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: text,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],

                    Expanded(
                      child: Text(
                        l10n.profile,
                        style: TextStyle(
                          color: text,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    const _RoundIcon(icon: Icons.settings_outlined),
                  ],
                ),

                const SizedBox(height: 25),

                // PROFILE HERO
                Container(
                  padding: const EdgeInsets.all(20),

                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),

                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF174831),
                        Color(0xFF0D2B1E),
                        Color(0xFF07140F),
                      ],
                    ),

                    border: Border.all(color: green.withOpacity(.25)),
                  ),

                  child: Column(
                    children: [
                      // PROFILE IMAGE
                      Stack(
                        children: [
                          Container(
                            width: 100,
                            height: 100,

                            decoration: BoxDecoration(
                              shape: BoxShape.circle,

                              border: Border.all(color: green, width: 3),

                              boxShadow: [
                                BoxShadow(
                                  color: green.withOpacity(.25),
                                  blurRadius: 25,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),

                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/runtime/plant_avatar.jpg',
                                fit: BoxFit.cover,

                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: card2,

                                    alignment: Alignment.center,

                                    child: const Text(
                                      'ND',
                                      style: TextStyle(
                                        color: green,
                                        fontSize: 30,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          Positioned(
                            right: 0,
                            bottom: 3,

                            child: Container(
                              width: 31,
                              height: 31,

                              decoration: BoxDecoration(
                                color: green,
                                shape: BoxShape.circle,

                                border: Border.all(color: bg, width: 3),
                              ),

                              child: const Icon(
                                Icons.edit_rounded,
                                color: bg,
                                size: 15,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 15),

                      Text(
                        DemoStory.farmer.nameEn,
                        style: TextStyle(
                          color: text,
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      const SizedBox(height: 5),

                      Text(
                        '${l10n.isBangla ? DemoStory.farmer.roleBn : DemoStory.farmer.roleEn} • ${l10n.isBangla ? DemoStory.location.districtBn : DemoStory.location.districtEn}',
                        style: TextStyle(color: muted, fontSize: 13),
                      ),

                      const SizedBox(height: 15),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _Pill(
                            icon: Icons.eco_rounded,
                            text: l10n.fieldCount(DemoStory.fieldCount),
                          ),

                          const SizedBox(width: 8),

                          _Pill(
                            icon: Icons.workspace_premium_outlined,
                            text: l10n.activeUser,
                            color: blue,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 15),

                // STATS
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        value: '6.2',
                        label: l10n.acres,
                        icon: Icons.landscape_outlined,
                        color: green,
                      ),
                    ),

                    SizedBox(width: 9),

                    Expanded(
                      child: _Stat(
                        value: '82',
                        label: l10n.averageHealth,
                        icon: Icons.eco_outlined,
                        color: green,
                      ),
                    ),

                    SizedBox(width: 9),

                    Expanded(
                      child: _Stat(
                        value: '12',
                        label: l10n.scans,
                        icon: Icons.center_focus_strong,
                        color: blue,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                Text(
                  l10n.farmSettings,
                  style: TextStyle(
                    color: text,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 12),

                // SETTINGS
                Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: line),
                  ),

                  child: Column(
                    children: [
                      _MenuItem(
                        icon: Icons.language_rounded,
                        title: l10n.language,
                        value: language == AppLanguage.bangla
                            ? l10n.bangla
                            : l10n.english,
                        onTap: () =>
                            _showLanguagePicker(context, ref, language),
                      ),

                      _Divider(),

                      _MenuItem(
                        icon: Icons.notifications_outlined,
                        title: l10n.notifications,
                        value: l10n.notificationsOn,
                      ),

                      _Divider(),

                      _MenuItem(
                        icon: Icons.location_on_outlined,
                        title: l10n.farmLocation,
                        value: l10n.bangladesh,
                      ),

                      _Divider(),

                      _MenuItem(
                        icon: Icons.water_drop_outlined,
                        title: l10n.irrigationSettings,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 25),

                Text(
                  l10n.marketplace,
                  style: TextStyle(
                    color: text,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: line),
                  ),

                  child: Column(
                    children: [
                      _MenuItem(
                        icon: Icons.storefront_outlined,
                        title: l10n.sellOnMarketplace,
                        onTap: () =>
                            context.push(RoutePaths.marketplaceCreateListing),
                      ),

                      const _Divider(),

                      _MenuItem(
                        icon: Icons.history_rounded,
                        title: l10n.scanHistory,
                      ),

                      const _Divider(),

                      _MenuItem(
                        icon: Icons.help_outline_rounded,
                        title: l10n.helpSupport,
                      ),

                      const _Divider(),

                      _MenuItem(
                        icon: Icons.shield_outlined,
                        title: l10n.privacyData,
                      ),

                      const _Divider(),

                      _MenuItem(
                        icon: Icons.info_outline_rounded,
                        title: l10n.aboutApp,
                        value: 'v1.0',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // LOG OUT
                SizedBox(
                  height: 54,

                  child: OutlinedButton.icon(
                    onPressed: () {},

                    icon: const Icon(Icons.logout_rounded),

                    label: Text(
                      l10n.logOut,
                      style: TextStyle(fontWeight: FontWeight.w900),
                    ),

                    style: OutlinedButton.styleFrom(
                      foregroundColor: orange,

                      side: BorderSide(color: orange.withOpacity(.35)),

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _showLanguagePicker(
  BuildContext context,
  WidgetRef ref,
  AppLanguage current,
) async {
  final l10n = AppLocalizations.of(context);
  final selected = await showModalBottomSheet<AppLanguage>(
    context: context,
    backgroundColor: ProfileScreen.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              l10n.chooseLanguage,
              style: const TextStyle(
                color: ProfileScreen.text,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          RadioListTile<AppLanguage>(
            value: AppLanguage.bangla,
            groupValue: current,
            activeColor: ProfileScreen.green,
            title: Text(
              l10n.bangla,
              style: const TextStyle(color: ProfileScreen.text),
            ),
            onChanged: (value) => Navigator.pop(sheetContext, value),
          ),
          RadioListTile<AppLanguage>(
            value: AppLanguage.english,
            groupValue: current,
            activeColor: ProfileScreen.green,
            title: Text(
              l10n.english,
              style: const TextStyle(color: ProfileScreen.text),
            ),
            onChanged: (value) => Navigator.pop(sheetContext, value),
          ),
          const SizedBox(height: 10),
        ],
      ),
    ),
  );

  if (selected != null && selected != current) {
    await ref.read(onboardingControllerProvider.notifier).setLanguage(selected);
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;

  const _Stat({
    required this.value,
    required this.label,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 105,
      padding: const EdgeInsets.all(13),

      decoration: BoxDecoration(
        color: ProfileScreen.card,
        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: ProfileScreen.line),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),

          const Spacer(),

          Text(
            value,
            style: const TextStyle(
              color: ProfileScreen.text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),

          Text(
            label,
            style: const TextStyle(color: ProfileScreen.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  final VoidCallback? onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),

        child: Row(
          children: [
            Container(
              width: 41,
              height: 41,

              decoration: BoxDecoration(
                color: ProfileScreen.green.withOpacity(.08),
                borderRadius: BorderRadius.circular(13),
              ),

              child: Icon(icon, color: ProfileScreen.green, size: 20),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: ProfileScreen.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),

            if (value != null)
              Text(
                value!,
                style: const TextStyle(
                  color: ProfileScreen.muted,
                  fontSize: 11,
                ),
              ),

            const SizedBox(width: 6),

            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: ProfileScreen.muted,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Pill({
    required this.icon,
    required this.text,
    this.color = ProfileScreen.green,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),

      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(50),

        border: Border.all(color: color.withOpacity(.25)),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),

          const SizedBox(width: 5),

          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  final IconData icon;

  const _RoundIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,

      decoration: BoxDecoration(
        color: ProfileScreen.card,
        shape: BoxShape.circle,

        border: Border.all(color: ProfileScreen.line),
      ),

      child: Icon(icon, color: ProfileScreen.text, size: 20),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 68, color: ProfileScreen.line);
  }
}

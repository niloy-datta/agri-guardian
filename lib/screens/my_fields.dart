import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/localization/app_localizations.dart';

import '../app/route_paths.dart';
import '../core/storage/app_database.dart';
import '../features/fields/application/fields_providers.dart';
import '../features/fields/presentation/widgets/add_field_sheet.dart';
import '../shared/models/field.dart';

class MyFieldsScreen extends ConsumerWidget {
  final VoidCallback? onBack;

  const MyFieldsScreen({
    super.key,
    this.onBack,
  });

  static const bg = Color(0xFF06110E);
  static const card = Color(0xFF0D1D18);
  static const card2 = Color(0xFF10271E);
  static const line = Color(0xFF1D382F);

  static const green = Color(0xFF20E27A);
  static const blue = Color(0xFF53A9FF);
  static const orange = Color(0xFFFFB020);
  static const red = Color(0xFFFF6060);

  static const text = Color(0xFFF5FFF8);
  static const muted = Color(0xFF8EA69A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsAsync = ref.watch(fieldsControllerProvider);
    final pendingMutationsAsync = ref.watch(pendingMutationsProvider);
    final mutations = pendingMutationsAsync.valueOrNull ?? [];
    final activeMutations =
        mutations.where((m) => m.status != 'completed').toList();

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: RefreshIndicator(
              color: green,
              backgroundColor: card,
              onRefresh: () async {
                await ref.read(fieldSyncServiceProvider).syncPendingMutations();
                await ref.read(fieldsControllerProvider.notifier).refresh();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
                children: [
                  _Header(
                    fields: fieldsAsync.valueOrNull,
                    onBack: onBack ?? () => context.pop(),
                    onAdd: () => showAddFieldSheet(context),
                  ),
                  if (activeMutations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SyncBanner(mutations: activeMutations),
                  ],
                  const SizedBox(height: 22),
                  fieldsAsync.when(
                    loading: () => const _LoadingBlock(),
                    error: (error, _) => _ErrorBlock(
                      message: '$error',
                      onRetry: () => ref
                          .read(fieldsControllerProvider.notifier)
                          .refresh(),
                    ),
                    data: (fields) => fields.isEmpty && activeMutations.isEmpty
                        ? _EmptyBlock(onAdd: () => showAddFieldSheet(context))
                        : _FieldsContent(
                            fields: fields,
                            mutations: activeMutations,
                          ),
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

// ================= SYNC BANNER =================

class _SyncBanner extends ConsumerStatefulWidget {
  final List<PendingMutation> mutations;

  const _SyncBanner({required this.mutations});

  @override
  ConsumerState<_SyncBanner> createState() => _SyncBannerState();
}

class _SyncBannerState extends ConsumerState<_SyncBanner> {
  bool _syncing = false;

  Future<void> _handleSync() async {
    setState(() => _syncing = true);
    try {
      await ref.read(fieldSyncServiceProvider).syncPendingMutations();
      await ref.read(fieldsControllerProvider.notifier).refresh();
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount =
        widget.mutations.where((m) => m.status == 'pending').length;
    final conflictCount =
        widget.mutations.where((m) => m.status == 'conflict').length;
    final blockedCount =
        widget.mutations.where((m) => m.status == 'blocked').length;

    final String statusText;
    final Color badgeColor;

    if (conflictCount > 0 || blockedCount > 0) {
      statusText =
          context.l10n.conflictBlockedSummary(conflictCount, blockedCount);
      badgeColor = MyFieldsScreen.red;
    } else {
      statusText = context.l10n.pendingSyncSummary(pendingCount);
      badgeColor = Colors.amber;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: badgeColor.withOpacity(.35)),
      ),
      child: Row(
        children: [
          Icon(
            _syncing ? Icons.sync_rounded : Icons.cloud_upload_outlined,
            color: badgeColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.myFieldsSyncQueue,
                  style: TextStyle(
                    color: MyFieldsScreen.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  statusText,
                  style: const TextStyle(
                    color: MyFieldsScreen.muted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _syncing ? null : _handleSync,
            style: ElevatedButton.styleFrom(
              backgroundColor: badgeColor,
              foregroundColor: MyFieldsScreen.bg,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _syncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MyFieldsScreen.bg,
                    ),
                  )
                : Text(
                    context.l10n.syncNow,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
                  ),
          ),
        ],
      ),
    );
  }
}

// ================= HEADER =================

class _Header extends StatelessWidget {
  final List<Field>? fields;
  final VoidCallback onBack;
  final VoidCallback onAdd;

  const _Header({
    required this.fields,
    required this.onBack,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = fields == null
        ? context.l10n.loadingFields
        : context.l10n.fieldsSummary(fields!.length, _totalArea(fields!).toStringAsFixed(1));

    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: MyFieldsScreen.text,
            size: 20,
          ),
        ),
        const SizedBox(width: 3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'আমার জমি',
                style: TextStyle(
                  color: MyFieldsScreen.text,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: MyFieldsScreen.muted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(50),
          onTap: onAdd,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: MyFieldsScreen.card,
              shape: BoxShape.circle,
              border: Border.all(color: MyFieldsScreen.line),
            ),
            child: const Icon(
              Icons.add_rounded,
              color: MyFieldsScreen.green,
            ),
          ),
        ),
      ],
    );
  }

  double _totalArea(List<Field> fields) =>
      fields.fold(0.0, (sum, field) => sum + field.areaAcres);
}

// ================= LOADING / ERROR / EMPTY =================

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 80),
      child: Center(
        child: CircularProgressIndicator(color: MyFieldsScreen.green),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: MyFieldsScreen.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: MyFieldsScreen.red.withOpacity(.3)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: MyFieldsScreen.red,
            size: 34,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: MyFieldsScreen.text, fontSize: 14),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              backgroundColor: MyFieldsScreen.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(context.l10n.tryAgainAction),
          ),
        ],
      ),
    );
  }
}

class _EmptyBlock extends StatelessWidget {
  final VoidCallback onAdd;

  const _EmptyBlock({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: MyFieldsScreen.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MyFieldsScreen.line),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: MyFieldsScreen.green.withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.grass_rounded,
              color: MyFieldsScreen.green,
              size: 30,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.noFieldsYet,
            style: TextStyle(
              color: MyFieldsScreen.text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.firstFieldHint,
            textAlign: TextAlign.center,
            style: TextStyle(color: MyFieldsScreen.muted, fontSize: 13),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: onAdd,
              style: FilledButton.styleFrom(
                backgroundColor: MyFieldsScreen.green,
                foregroundColor: MyFieldsScreen.bg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                context.l10n.addFieldAction,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= POPULATED CONTENT =================

class _FieldsContent extends StatelessWidget {
  final List<Field> fields;
  final List<PendingMutation> mutations;

  const _FieldsContent({
    required this.fields,
    required this.mutations,
  });

  @override
  Widget build(BuildContext context) {
    final featured = fields.isNotEmpty ? fields.first : null;
    final totalArea = fields.fold(0.0, (sum, f) => sum + f.areaAcres);
    final activeCount =
        fields.where((f) => f.status == FieldStatus.active).length;
    final fieldMutations =
        mutations.where((m) => m.type == 'field_create').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // SATELLITE HERO
        if (featured != null)
          Container(
            height: 275,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: MyFieldsScreen.green.withOpacity(.23),
              ),
              boxShadow: [
                BoxShadow(
                  color: MyFieldsScreen.green.withOpacity(.06),
                  blurRadius: 28,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(
                    painter: _SatellitePainter(),
                  ),
                ),
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          MyFieldsScreen.bg.withOpacity(.15),
                          MyFieldsScreen.bg.withOpacity(.82),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  child: _Pill(
                    icon: Icons.map_outlined,
                    text: context.l10n.boundaryLabel,
                  ),
                ),
                Positioned(
                  top: 16,
                  right: 16,
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: MyFieldsScreen.bg.withOpacity(.78),
                      shape: BoxShape.circle,
                      border: Border.all(color: MyFieldsScreen.line),
                    ),
                    child: const Icon(
                      Icons.layers_outlined,
                      color: MyFieldsScreen.text,
                      size: 20,
                    ),
                  ),
                ),
                Positioned(
                  left: 55,
                  top: 82,
                  child: Container(
                    width: 180,
                    height: 96,
                    decoration: BoxDecoration(
                      color: MyFieldsScreen.green.withOpacity(.14),
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: MyFieldsScreen.green,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 13,
                        height: 13,
                        decoration: BoxDecoration(
                          color: MyFieldsScreen.green,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: MyFieldsScreen.green.withOpacity(.55),
                              blurRadius: 15,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 18,
                  right: 18,
                  bottom: 17,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              featured.name,
                              style: const TextStyle(
                                color: MyFieldsScreen.text,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${context.l10n.acresText(featured.areaAcres.toStringAsFixed(1))}'
                              '${featured.district != null ? ' • ${featured.district}' : ''}',
                              style: const TextStyle(
                                color: MyFieldsScreen.muted,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _StatusBadge(status: featured.status),
                    ],
                  ),
                ),
              ],
            ),
          ),

        if (featured != null) const SizedBox(height: 14),

        // SUMMARY
        Row(
          children: [
            Expanded(
              child: _MiniMetric(
                icon: Icons.grass_outlined,
                value: context.l10n.digits(fields.length),
                label: context.l10n.totalFieldsLabel,
                color: MyFieldsScreen.green,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _MiniMetric(
                icon: Icons.crop_square_outlined,
                value: totalArea.toStringAsFixed(1),
                label: context.l10n.totalAcresLabel,
                color: MyFieldsScreen.blue,
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: _MiniMetric(
                icon: Icons.check_circle_outline_rounded,
                value: '$activeCount',
                label: context.l10n.activeLabel,
                color: MyFieldsScreen.orange,
              ),
            ),
          ],
        ),

        const SizedBox(height: 28),

        // SECTION TITLE
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.yourFieldsTitle,
                style: TextStyle(
                  color: MyFieldsScreen.text,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Pending Unsynced Local Field Cards
        for (final mutation in fieldMutations) ...[
          _PendingFieldCard(mutation: mutation),
          const SizedBox(height: 10),
        ],

        // Synced Server Field Cards
        for (final field in fields) ...[
          _FieldCard(field: field),
          const SizedBox(height: 10),
        ],

        const SizedBox(height: 14),

        // HONEST STATE - no fabricated intelligence until the
        // NASA/Copernicus earth-observation pipeline exists.
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: MyFieldsScreen.card,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: MyFieldsScreen.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.satellite_alt_outlined,
                color: MyFieldsScreen.muted,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.satelliteNotRunYet,
                      style: TextStyle(
                        color: MyFieldsScreen.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'বিশ্লেষণের অপেক্ষায় • জমির স্বাস্থ্য ও ঝুঁকির তথ্য যুক্ত হলে এখানে দেখা যাবে।',
                      style: TextStyle(
                        color: MyFieldsScreen.muted,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ================= PENDING FIELD CARD =================

class _PendingFieldCard extends StatelessWidget {
  final PendingMutation mutation;

  const _PendingFieldCard({required this.mutation});

  @override
  Widget build(BuildContext context) {
    String name = context.l10n.newFieldFallback;
    try {
      final json = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
      if (json['name'] != null) name = json['name'] as String;
    } catch (_) {}

    final (statusLabel, badgeColor) = switch (mutation.status) {
      'pending' => (context.l10n.syncPendingStatus, Colors.amber),
      'conflict' => (context.l10n.conflictStatus, MyFieldsScreen.red),
      'blocked' => (context.l10n.blockedStatus, MyFieldsScreen.red),
      _ => (mutation.status, MyFieldsScreen.muted),
    };

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: MyFieldsScreen.card,
        borderRadius: BorderRadius.circular(23),
        border: Border.all(
          color: badgeColor.withOpacity(.4),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(.10),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.cloud_upload_outlined,
              color: badgeColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: MyFieldsScreen.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  mutation.lastErrorMessage ?? context.l10n.savedLocallyNeedsSync,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor.withOpacity(.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: badgeColor.withOpacity(.4)),
            ),
            child: Text(
              statusLabel,
              style: TextStyle(
                color: badgeColor,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= FIELD CARD =================

class _FieldCard extends StatelessWidget {
  final Field field;

  const _FieldCard({required this.field});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(23),
      onTap: () {
        context.push(RoutePaths.fieldDetailsPath(field.id));
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: MyFieldsScreen.card,
          borderRadius: BorderRadius.circular(23),
          border: Border.all(
            color: MyFieldsScreen.line,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: MyFieldsScreen.green.withOpacity(.10),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.grass_rounded,
                color: MyFieldsScreen.green,
                size: 28,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    field.name,
                    style: const TextStyle(
                      color: MyFieldsScreen.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _locationLabel(field),
                          style: const TextStyle(
                            color: MyFieldsScreen.muted,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const Text(
                        '  •  ',
                        style: TextStyle(
                          color: MyFieldsScreen.muted,
                        ),
                      ),
                      Text(
                        context.l10n.acresText(field.areaAcres.toStringAsFixed(1)),
                        style: const TextStyle(
                          color: MyFieldsScreen.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            _StatusBadge(status: field.status, compact: true),
            const SizedBox(width: 7),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: MyFieldsScreen.muted,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  String _locationLabel(Field field) {
    return field.district ?? field.region ?? field.countryCode;
  }
}

// ================= SMALL METRIC =================

class _MiniMetric extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniMetric({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 102,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MyFieldsScreen.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MyFieldsScreen.line,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: color,
            size: 22,
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: MyFieldsScreen.text,
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: MyFieldsScreen.muted,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

// ================= STATUS BADGE =================

class _StatusBadge extends StatelessWidget {
  final String status;
  final bool compact;

  const _StatusBadge({required this.status, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      FieldStatus.active => (context.l10n.statusActive, MyFieldsScreen.green),
      FieldStatus.inactive => (context.l10n.statusInactive, MyFieldsScreen.orange),
      FieldStatus.archived => (context.l10n.statusArchived, MyFieldsScreen.muted),
      _ => (status, MyFieldsScreen.muted),
    };

    if (compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(.4)),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: MyFieldsScreen.bg.withOpacity(.75),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
      ),
    );
  }
}

// ================= PILL =================

class _Pill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Pill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: MyFieldsScreen.bg.withOpacity(.78),
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: MyFieldsScreen.green.withOpacity(.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: MyFieldsScreen.green,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: MyFieldsScreen.green,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

// ================= FAKE SATELLITE MAP =================

class _SatellitePainter extends CustomPainter {
  const _SatellitePainter();

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF1B3E26),
          Color(0xFF344D24),
          Color(0xFF172D20),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(
        Rect.fromLTWH(
          0,
          0,
          size.width,
          size.height,
        ),
      );

    canvas.drawRect(
      Offset.zero & size,
      bgPaint,
    );

    final fieldPaint = Paint()
      ..color = const Color(0xFF527B36).withOpacity(.45)
      ..style = PaintingStyle.fill;

    final border = Paint()
      ..color = Colors.white.withOpacity(.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paths = <Path>[
      Path()
        ..moveTo(0, 20)
        ..lineTo(size.width * .42, 0)
        ..lineTo(size.width * .36, size.height * .38)
        ..lineTo(0, size.height * .43)
        ..close(),
      Path()
        ..moveTo(size.width * .45, 0)
        ..lineTo(size.width, 5)
        ..lineTo(size.width, size.height * .31)
        ..lineTo(size.width * .58, size.height * .36)
        ..close(),
      Path()
        ..moveTo(0, size.height * .47)
        ..lineTo(size.width * .36, size.height * .42)
        ..lineTo(size.width * .43, size.height)
        ..lineTo(0, size.height)
        ..close(),
      Path()
        ..moveTo(size.width * .40, size.height * .40)
        ..lineTo(size.width, size.height * .35)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width * .47, size.height)
        ..close(),
    ];

    for (int i = 0; i < paths.length; i++) {
      fieldPaint.color = i.isEven
          ? const Color(0xFF51793B).withOpacity(.42)
          : const Color(0xFF284D29).withOpacity(.65);

      canvas.drawPath(
        paths[i],
        fieldPaint,
      );

      canvas.drawPath(
        paths[i],
        border,
      );
    }

    final roadPaint = Paint()
      ..color = const Color(0xFFB79B63).withOpacity(.18)
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(
        size.width * .03,
        size.height * .75,
      ),
      Offset(
        size.width * .95,
        size.height * .17,
      ),
      roadPaint,
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter oldDelegate,
  ) =>
      false;
}

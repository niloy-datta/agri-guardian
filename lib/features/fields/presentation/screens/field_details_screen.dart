import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../../../shared/models/crop_cycle.dart';
import '../../../../shared/models/field.dart';
import '../../application/fields_providers.dart';
import '../../../../core/localization/app_localizations.dart';

const _bg = Color(0xFF06110E);
const _card = Color(0xFF10271E);
const _line = Color(0xFF1D382F);
const _green = Color(0xFF20E27A);
const _muted2 = Color(0xFF8EA69A);
const _text2 = Color(0xFFF5FFF8);

class FieldDetailsScreen extends ConsumerWidget {
  final String fieldId;

  const FieldDetailsScreen({super.key, required this.fieldId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldsAsync = ref.watch(fieldsControllerProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _text2,
        title: Text(context.l10n.fieldDetailsTitle),
      ),
      body: fieldsAsync.when(
        loading: () => const LoadingView(),
        error: (error, _) => ErrorView(
          message: '$error',
          onRetry: () => ref.read(fieldsControllerProvider.notifier).refresh(),
        ),
        data: (_) {
          final field = ref.watch(fieldByIdProvider(fieldId));
          if (field == null) {
            return ErrorView(message: context.l10n.fieldNotFound);
          }
          return _FieldDetailsBody(field: field);
        },
      ),
    );
  }
}

class _FieldDetailsBody extends ConsumerWidget {
  final Field field;

  const _FieldDetailsBody({required this.field});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cyclesAsync = ref.watch(fieldCropCyclesControllerProvider(field.id));

    return RefreshIndicator(
      color: _green,
      backgroundColor: _card,
      onRefresh: () => ref
          .read(fieldCropCyclesControllerProvider(field.id).notifier)
          .refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            field.name,
            style: const TextStyle(
              color: _text2,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _locationLine(field),
            style: const TextStyle(color: _muted2, fontSize: 13),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  icon: Icons.crop_square_rounded,
                  label: context.l10n.areaServerLabel,
                  value: context.l10n.acresText(field.areaAcres.toStringAsFixed(2)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricCard(
                  icon: Icons.flag_outlined,
                  label: context.l10n.fieldStatusLabel,
                  value: _statusLabel(context.l10n, field.status),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const _SatelliteAwaitingCard(),
          const SizedBox(height: 16),
          Text(
            context.l10n.cropCyclesTitle,
            style: TextStyle(
              color: _text2,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          cyclesAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: _green),
              ),
            ),
            error: (error, _) => _CropCycleErrorCard(
              message: '$error',
              onRetry: () => ref
                  .read(fieldCropCyclesControllerProvider(field.id).notifier)
                  .refresh(),
            ),
            data: (cycles) => cycles.isEmpty
                ? const _NoCropCycleCard()
                : Column(
                    children: [
                      for (final cycle in cycles) ...[
                        _CropCycleCard(cycle: cycle),
                        const SizedBox(height: 10),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _locationLine(Field field) {
    final parts = [
      field.upazila,
      field.district,
      field.region,
      field.countryCode,
    ].whereType<String>().where((part) => part.trim().isNotEmpty);
    return parts.isEmpty ? field.countryCode : parts.join(', ');
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case FieldStatus.active:
        return l10n.statusActive;
      case FieldStatus.inactive:
        return l10n.statusInactive;
      case FieldStatus.archived:
        return l10n.statusArchived;
      default:
        return status;
    }
  }
}

/// Honest placeholder until the NASA/Copernicus earth-observation pipeline
/// exists. No fabricated health, NDVI,
/// or risk value is ever shown here.
class _SatelliteAwaitingCard extends StatelessWidget {
  const _SatelliteAwaitingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.satellite_alt_outlined, color: _muted2, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.satelliteNotRunYet,
                  style: TextStyle(
                    color: _text2,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  context.l10n.satelliteWaitingHint,
                  style: TextStyle(color: _muted2, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _MetricCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _green, size: 20),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(color: _text2, fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: _muted2, fontSize: 11)),
        ],
      ),
    );
  }
}

class _NoCropCycleCard extends StatelessWidget {
  const _NoCropCycleCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Text(
        context.l10n.noCropCyclesYet,
        style: TextStyle(color: _muted2, fontSize: 13),
      ),
    );
  }
}

class _CropCycleErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _CropCycleErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF6060).withOpacity(.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: _text2, fontSize: 13)),
          const SizedBox(height: 10),
          TextButton(
            onPressed: onRetry,
            child: const Text('পুনরায় চেষ্টা করুন', style: TextStyle(color: _green)),
          ),
        ],
      ),
    );
  }
}

class _CropCycleCard extends StatelessWidget {
  final CropCycle cycle;

  const _CropCycleCard({required this.cycle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  cycle.variety != null
                      ? '${cycle.cropCode} • ${cycle.variety}'
                      : cycle.cropCode,
                  style: const TextStyle(
                    color: _text2,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusPill(status: cycle.status),
            ],
          ),
          if (cycle.currentStage != null) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.cycleStage(cycle.currentStage!),
              style: const TextStyle(color: _muted2, fontSize: 12),
            ),
          ],
          if (cycle.plantingDate != null || cycle.expectedHarvestDate != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (cycle.plantingDate != null)
                  context.l10n.plantedOn(_formatDate(cycle.plantingDate!)),
                if (cycle.expectedHarvestDate != null)
                  context.l10n.expectedHarvest(_formatDate(cycle.expectedHarvestDate!)),
              ].join(' • '),
              style: const TextStyle(color: _muted2, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      CropCycleStatus.planned => context.l10n.cycleStatusPlanned,
      CropCycleStatus.active => context.l10n.cycleStatusActive,
      CropCycleStatus.harvested => context.l10n.cycleStatusHarvested,
      CropCycleStatus.failed => context.l10n.cycleStatusFailed,
      CropCycleStatus.cancelled => context.l10n.cycleStatusCancelled,
      _ => status,
    };
    final color = switch (status) {
      CropCycleStatus.active => _green,
      CropCycleStatus.failed => const Color(0xFFFF6060),
      CropCycleStatus.cancelled => _muted2,
      _ => const Color(0xFF53A9FF),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(.4)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
      ),
    );
  }
}

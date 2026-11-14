import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/rotation_providers.dart';
import '../../domain/rotation_models.dart';

/// Farmer-facing explanation of the server's recorded, sourced rotation logic.
/// Never computes local mock scores or claims predicted farm outcomes.
class RotationComparisonScreen extends ConsumerStatefulWidget {
  final String fieldId;

  const RotationComparisonScreen({super.key, required this.fieldId});

  @override
  ConsumerState<RotationComparisonScreen> createState() =>
      _RotationComparisonScreenState();
}

class _RotationComparisonScreenState extends ConsumerState<RotationComparisonScreen> {
  String _irrigation = 'none';
  String _priority = 'water_saving';
  int _overlapDays = 0;

  @override
  Widget build(BuildContext context) {
    final query = (
      fieldId: widget.fieldId,
      maxOverlapDays: _overlapDays,
      irrigationAccess: _irrigation,
      priority: _priority,
    );
    final result = ref.watch(rotationComparisonProvider(query));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Rotation Explorer'),
        actions: [
          IconButton(
            tooltip: 'Reload real evidence',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(rotationComparisonProvider(query)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Explore feasible rotations for this field. Results describe regional '
            'conditions, not a measured yield or forecast.',
          ),
          const SizedBox(height: 16),
          const Text('Irrigation access', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              _chip('No irrigation', 'none', _irrigation, (value) {
                setState(() => _irrigation = value);
              }),
              _chip('Supplementary', 'supplementary', _irrigation, (value) {
                setState(() => _irrigation = value);
              }),
              _chip('Full irrigation', 'full', _irrigation, (value) {
                setState(() => _irrigation = value);
              }),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Farmer priority', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              _chip('Save water', 'water_saving', _priority, (value) {
                setState(() => _priority = value);
              }),
              _chip('Food security', 'food_security', _priority, (value) {
                setState(() => _priority = value);
              }),
              _chip('Soil health', 'soil_health', _priority, (value) {
                setState(() => _priority = value);
              }),
            ],
          ),
          SwitchListTile(
            title: const Text('Allow a 7-day calendar overlap'),
            subtitle: const Text('Transitions still need local verification.'),
            contentPadding: EdgeInsets.zero,
            value: _overlapDays == 7,
            onChanged: (value) => setState(() => _overlapDays = value ? 7 : 0),
          ),
          const Divider(),
          result.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, _) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Unable to obtain rotation evidence.',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SelectableText('$error'),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () => ref.invalidate(rotationComparisonProvider(query)),
                  child: const Text('Retry'),
                ),
              ],
            ),
            data: _comparisonView,
          ),
        ],
      ),
    );
  }

  Widget _chip(
    String label, String value, String selected, ValueChanged<String> onSelect
  ) {
    return ChoiceChip(
      label: Text(label),
      selected: value == selected,
      onSelected: (_) => onSelect(value),
    );
  }

  Widget _comparisonView(RotationComparison result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '${result.location.district ?? "Unknown district"} · '
          '${result.location.bamisRegion ?? "Calendar unavailable"}',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (result.location.nearBoundary)
          const Text('Location is near a district boundary: verify the selected calendar.'),
        if (result.isStale(DateTime.now()))
          const Text('Evidence is old or undated. Check retrieval time before using.'),
        const SizedBox(height: 10),
        if (result.insufficientEvidence)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: Text('Insufficient evidence for a safe comparison. '
                  'Do not treat a partial result as farming advice.'),
            ),
          ),
        for (final reason in result.reasons)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(reason),
          ),
        for (var i = 0; i < result.scenarios.length; i++)
          _scenarioCard(result.scenarios[i], i + 1),
        if (result.excluded.isNotEmpty)
          ExpansionTile(
            title: Text('Excluded crops (${result.excluded.length})'),
            children: [
              for (final item in result.excluded)
                ListTile(
                  title: Text(item.crop),
                  subtitle: Text(item.reason),
                ),
            ],
          ),
        if (result.unsupportedPriorities.isNotEmpty)
          Text('Unsupported priorities: ${result.unsupportedPriorities.join(", ")}'),
        ExpansionTile(
          initiallyExpanded: true,
          title: Text('Data sources (${result.evidence.length})'),
          children: [
            for (final item in result.evidence) _evidenceTile(item),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          result.disclaimer.isEmpty
              ? 'Confirm crop choices with local agricultural experts.'
              : result.disclaimer,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  Widget _scenarioCard(RotationScenario scenario, int rank) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Option $rank: ${scenario.crops.join(" → ")}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Calendar overlap: ${scenario.overlapDays} day(s)'),
            if (scenario.irrigationDependent.isNotEmpty)
              Text('Irrigation needed: ${scenario.irrigationDependent.join(", ")}'),
            if (scenario.unknownWaterNeed.isNotEmpty)
              Text('Water requirement unknown: ${scenario.unknownWaterNeed.join(", ")}'),
            if (scenario.hasPulse)
              const Text('Contains a pulse crop; soil benefit is not measured.'),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Why this option?'),
              children: [
                for (final claim in scenario.claims)
                  ListTile(
                    title: Text(claim.text),
                    subtitle: SelectableText(
                      '${claim.uncertainty}\nSource: ${claim.source}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _evidenceTile(EvidenceSummary item) {
    return ListTile(
      title: Text(item.name),
      subtitle: SelectableText(
        'Status: ${item.status}\nScale: ${item.resolution}\n'
        '${item.caveat}\n${item.reason}\nSource: ${item.sourceUrl}',
      ),
    );
  }
}

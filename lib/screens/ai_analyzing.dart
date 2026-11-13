import 'package:flutter/material.dart';

import '../features/plant_scan/domain/scan_analysis_result.dart';

class AiAnalyzingScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  final String? imagePath;

  const AiAnalyzingScreen({super.key, this.onComplete, this.imagePath});

  @override
  State<AiAnalyzingScreen> createState() => _AiAnalyzingScreenState();
}

class _AiAnalyzingScreenState extends State<AiAnalyzingScreen> {
  late final ScanAnalysisResult _result;

  static const bg = Color(0xFF06110E);
  static const card = Color(0xFF0D1D18);
  static const line = Color(0xFF1D382F);
  static const green = Color(0xFF20E27A);
  static const text = Color(0xFFF5FFF8);
  static const muted = Color(0xFF8EA69A);

  @override
  void initState() {
    super.initState();
    _result = ScanAnalysisResult.unavailable(checkedAt: DateTime.now());
  }

  void _close() {
    if (widget.onComplete != null) {
      widget.onComplete!();
      return;
    }
    Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        foregroundColor: text,
        title: const Text('গাছের ছবি বিশ্লেষণ'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.cloud_off_rounded, color: muted, size: 54),
                  const SizedBox(height: 20),
                  const Text(
                    'রোগ শনাক্তকরণ এখন unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: text,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _result.limitation,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: muted, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: card,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: line),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _EvidenceRow(
                          label: 'STATUS',
                          value: _result.status.name.toUpperCase(),
                          valueColor: const Color(0xFFFFB020),
                        ),
                        const SizedBox(height: 12),
                        _EvidenceRow(label: 'SOURCE', value: _result.source),
                        const SizedBox(height: 12),
                        _EvidenceRow(
                          label: 'CHECKED AT',
                          value: _result.checkedAt.toLocal().toIso8601String(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _close,
                    icon: const Icon(Icons.arrow_back_rounded),
                    label: const Text('স্ক্যানে ফিরে যান'),
                    style: FilledButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: bg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
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

class _EvidenceRow extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _EvidenceRow({
    required this.label,
    required this.value,
    this.valueColor = const Color(0xFFF5FFF8),
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8EA69A),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.7,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_localizations.dart';
import '../features/voice_guide/application/voice_guide_controller.dart';
import '../shared/demo/showcase_story.dart';

class TreatmentPlanScreen extends ConsumerStatefulWidget {
  const TreatmentPlanScreen({super.key});

  @override
  ConsumerState<TreatmentPlanScreen> createState() =>
      _TreatmentPlanScreenState();
}

class _TreatmentPlanScreenState extends ConsumerState<TreatmentPlanScreen> {
  static const bg = Color(0xFF06110E);
  static const card = Color(0xFF0D1D18);
  static const line = Color(0xFF1D382F);

  static const green = Color(0xFF20E27A);
  static const greenLight = Color(0xFF38F28D);
  static const blue = Color(0xFF4DA3FF);
  static const orange = Color(0xFFFFB020);

  static const text = Color(0xFFF5FFF8);
  static const muted = Color(0xFF8EA69A);

  bool _isAudioPlaying = false;
  bool _planStarted = false;
  late final VoiceGuideController _voiceController;

  @override
  void initState() {
    super.initState();
    _voiceController = ref.read(voiceGuideControllerProvider);
    _voiceController.isSpeaking.addListener(_syncAudio);
  }

  @override
  void dispose() {
    _voiceController.isSpeaking.removeListener(_syncAudio);
    super.dispose();
  }

  /// The audio pill reflects real playback, not a local toggle.
  void _syncAudio() {
    if (mounted) {
      setState(() => _isAudioPlaying = _voiceController.isSpeaking.value);
    }
  }

  /// Plays the plan through the voice guide in the selected language.
  Future<void> _toggleAudio() async {
    final l10n = context.l10n;
    final result = await _voiceController.speakLines(
      _narration(l10n),
      isBangla: l10n.isBangla,
    );
    if (result == VoiceRunResult.voiceUnavailable && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.voiceNotInstalled)));
    }
  }

  List<String> _narration(AppLocalizations l) => [
    l.treatPlanTitle,
    l.treatDemoNotice,
    l.treatStep1Day,
    l.treatStep1Title,
    l.treatStep1Desc,
    l.treatStep1Task1,
    l.treatStep1Task2,
    l.treatStep1Task3,
    l.treatStep2Day,
    l.treatStep2Title,
    l.treatStep2Desc,
    l.treatStep2Task1,
    l.treatStep2Task2,
    l.treatStep2Task3,
    l.treatStep3Day,
    l.treatStep3Title,
    l.treatStep3Desc,
    l.treatStep3Task1,
    l.treatStep3Task2,
    l.treatStep3Task3,
    l.treatWarningBody,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                // ================= TOP BAR =================
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                  child: Row(
                    children: [
                      _CircleButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.treatPlanTitle,
                              style: TextStyle(
                                color: text,
                                fontSize: 17.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              l10n.treatSubtitle(
                                l10n.isBangla
                                    ? DemoStory.diagnosis.nameBn
                                    : DemoStory.diagnosis.nameEn,
                                l10n.isBangla
                                    ? DemoStory.field.nameBn
                                    : DemoStory.field.nameEn,
                                l10n.isBangla
                                    ? DemoStory.field.areaBn
                                    : DemoStory.field.areaEn,
                              ),
                              style: TextStyle(color: muted, fontSize: 11.5),
                            ),
                          ],
                        ),
                      ),
                      // Audio Listen Button ("শুনুন")
                      GestureDetector(
                        onTap: _toggleAudio,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _isAudioPlaying
                                ? green.withOpacity(0.18)
                                : card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _isAudioPlaying ? green : line,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _isAudioPlaying
                                    ? Icons.volume_up_rounded
                                    : Icons.volume_mute_rounded,
                                color: _isAudioPlaying ? green : text,
                                size: 16,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                l10n.treatListen,
                                style: TextStyle(
                                  color: _isAudioPlaying ? green : text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ================= SCROLLABLE ROADMAP =================
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    children: [
                      Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: orange.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: orange.withOpacity(0.55)),
                        ),
                        child: Text(
                          l10n.treatDemoNotice,
                          style: TextStyle(
                            color: Color(0xFFFFD58A),
                            fontSize: 12,
                            height: 1.45,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // NEXT EVALUATION COUNTDOWN CARD (From 07_seven_day_management_plan_dark.jpg)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: green.withOpacity(0.35)),
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0F2B1F),
                              Color(0xFF0A1B14),
                              Color(0xFF06120D),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: green.withOpacity(0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              alignment: WrapAlignment.spaceBetween,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(7),
                                      decoration: BoxDecoration(
                                        color: green.withOpacity(0.14),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.timer_outlined,
                                        color: green,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        l10n.treatNextEvaluation,
                                        style: TextStyle(
                                          color: text,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: green.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: green.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Text(
                                    l10n.treatHoursLeft(48),
                                    style: TextStyle(
                                      color: green,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              l10n.treatPhotoNote,
                              style: TextStyle(
                                color: muted,
                                fontSize: 11.5,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: const LinearProgressIndicator(
                                value: 0.18,
                                minHeight: 6,
                                backgroundColor: line,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // TIMELINE HEADER
                      Text(
                        l10n.treatTimelineTitle,
                        style: TextStyle(
                          color: text,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ================= VERTICAL CONNECTED TIMELINE =================
                      // STEP 1: আজ (Day 1)
                      _TimelineStepCard(
                        dayLabel: l10n.treatStep1Day,
                        badgeText: l10n.treatStep1Badge,
                        badgeColor: green,
                        title: l10n.treatStep1Title,
                        desc: l10n.treatStep1Desc,
                        tasks: [
                          l10n.treatStep1Task1,
                          l10n.treatStep1Task2,
                          l10n.treatStep1Task3,
                        ],
                        isActive: true,
                        isCompleted: false,
                        isLast: false,
                      ),

                      // STEP 2: দিন ২–৩ (Day 2-3)
                      _TimelineStepCard(
                        dayLabel: l10n.treatStep2Day,
                        badgeText: l10n.treatStep2Badge,
                        badgeColor: orange,
                        title: l10n.treatStep2Title,
                        desc: l10n.treatStep2Desc,
                        tasks: [
                          l10n.treatStep2Task1,
                          l10n.treatStep2Task2,
                          l10n.treatStep2Task3,
                        ],
                        isActive: false,
                        isCompleted: false,
                        isLast: false,
                      ),

                      // STEP 3: দিন ৫–৭ (Day 5-7)
                      _TimelineStepCard(
                        dayLabel: l10n.treatStep3Day,
                        badgeText: l10n.treatStep3Badge,
                        badgeColor: blue,
                        title: l10n.treatStep3Title,
                        desc: l10n.treatStep3Desc,
                        tasks: [
                          l10n.treatStep3Task1,
                          l10n.treatStep3Task2,
                          l10n.treatStep3Task3,
                        ],
                        isActive: false,
                        isCompleted: false,
                        isLast: true,
                      ),

                      const SizedBox(height: 16),

                      // WHY THIS PLAN CARD (কেন এই পরিকল্পনা?)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: line),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.verified_outlined,
                              color: green,
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.treatWhyTitle,
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    l10n.treatWhyBody,
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 10),

                      // WARNING / IMPORTANT NOTE (মনে রাখুন)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: card,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: orange.withOpacity(0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              color: orange,
                              size: 22,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    l10n.treatWarningTitle,
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    l10n.treatWarningBody,
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 11.5,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ================= BOTTOM STICKY CTA =================
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  decoration: BoxDecoration(
                    color: card,
                    border: const Border(top: BorderSide(color: line)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _planStarted ? greenLight : green,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        setState(() {
                          _planStarted = true;
                        });
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            backgroundColor: card,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: const BorderSide(color: green),
                            ),
                            title: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: green),
                                SizedBox(width: 8),
                                Text(
                                  l10n.treatDemoDialogTitle,
                                  style: TextStyle(color: text, fontSize: 18),
                                ),
                              ],
                            ),
                            content: Text(
                              l10n.treatDemoDialogBody,
                              style: TextStyle(color: muted, fontSize: 13),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: Text(
                                  l10n.treatOk,
                                  style: TextStyle(
                                    color: green,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              _planStarted
                                  ? l10n.treatMarkedDemo
                                  : l10n.treatStartPlan,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
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

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: const Color(0xFF0D1D18),
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF1D382F)),
        ),
        child: Icon(icon, color: const Color(0xFFF5FFF8), size: 18),
      ),
    );
  }
}

class _TimelineStepCard extends StatelessWidget {
  final String dayLabel;
  final String badgeText;
  final Color badgeColor;
  final String title;
  final String desc;
  final List<String> tasks;
  final bool isActive;
  final bool isCompleted;
  final bool isLast;

  const _TimelineStepCard({
    required this.dayLabel,
    required this.badgeText,
    required this.badgeColor,
    required this.title,
    required this.desc,
    required this.tasks,
    required this.isActive,
    required this.isCompleted,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF20E27A);
    const line = Color(0xFF1D382F);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left vertical timeline axis
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isActive ? green : const Color(0xFF0D1D18),
                    border: Border.all(
                      color: isActive ? green : line,
                      width: 3,
                    ),
                  ),
                ),
                if (!isLast) Expanded(child: Container(width: 2, color: line)),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Right Card
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF10281F)
                    : const Color(0xFF0D1D18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? green.withOpacity(0.5) : line,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Text(
                          dayLabel,
                          style: const TextStyle(
                            color: Color(0xFFF5FFF8),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.14),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: badgeColor.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: TextStyle(
                      color: isActive ? green : const Color(0xFFF5FFF8),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    desc,
                    style: const TextStyle(
                      color: Color(0xFF8EA69A),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Tasks Checklist
                  ...tasks.map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isActive
                                ? Icons.check_circle_outline_rounded
                                : Icons.circle_outlined,
                            size: 13,
                            color: isActive ? green : const Color(0xFF8EA69A),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              task,
                              style: TextStyle(
                                color: isActive
                                    ? const Color(0xFFF5FFF8)
                                    : const Color(0xFF8EA69A),
                                fontSize: 10.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

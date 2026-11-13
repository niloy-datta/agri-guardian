import 'dart:async';

import '../../../../core/localization/app_localizations.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../../../../core/services/camera_service.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../screens/ai_analyzing.dart';

class ScanScreen extends StatefulWidget {
  final VoidCallback? onCapture;

  /// Optional seams for tests; production uses the default services.
  final CameraService? cameraService;
  final PermissionService? permissionService;

  const ScanScreen({
    super.key,
    this.onCapture,
    this.cameraService,
    this.permissionService,
  });

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const bg = Color(0xFF06110E);
  static const card = Color(0xFF0D1D18);
  static const line = Color(0xFF1D382F);

  static const green = Color(0xFF20E27A);

  static const text = Color(0xFFF5FFF8);
  static const muted = Color(0xFF8EA69A);

  late AnimationController _laserController;
  late Animation<double> _laserAnimation;

  late final CameraService _cameraService =
      widget.cameraService ?? CameraService();
  late final PermissionService _permissionService =
      widget.permissionService ?? PermissionService();

  int _selectedZoom = 0; // 0 = 1x, 1 = 2x, 2 = 3x
  bool _flashAuto = true;
  bool _isInitializingCamera = true;
  bool _isCapturing = false;
  String? _cameraError;
  CameraZoomRange? _zoomRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserAnimation = Tween<double>(begin: 0.08, end: 0.92).animate(
      CurvedAnimation(parent: _laserController, curve: Curves.easeInOut),
    );
    unawaited(_initializeCamera());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_cameraService.dispose());
    _laserController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (_cameraService.isInitialized) {
        unawaited(_cameraService.dispose());
      }
    } else if (state == AppLifecycleState.resumed && mounted) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _initializeCamera() async {
    if (!mounted) return;

    setState(() {
      _isInitializingCamera = true;
      _cameraError = null;
      _zoomRange = null;
      _selectedZoom = 0;
    });

    final permissionGranted = await _permissionService
        .requestCameraPermission();
    if (!mounted) return;
    if (!permissionGranted) {
      setState(() {
        _isInitializingCamera = false;
        _cameraError = context.l10n.scanCameraPermissionNeeded;
      });
      return;
    }

    try {
      await _cameraService.initialize();
      final zoomRange = await _cameraService.getZoomRange();
      if (!mounted) return;
      setState(() {
        _zoomRange = zoomRange;
        _isInitializingCamera = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Camera initialization failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _isInitializingCamera = false;
        _cameraError = context.l10n.scanCameraStartFailed;
      });
    }
  }

  Future<void> _setFlashMode() async {
    final targetMode = _flashAuto ? FlashMode.off : FlashMode.auto;
    final applied = await _cameraService.setFlashMode(targetMode);
    if (!mounted) return;
    if (!applied) {
      _showMessage(context.l10n.scanFlashUnsupported);
      return;
    }
    setState(() {
      _flashAuto = targetMode == FlashMode.auto;
    });
  }

  Future<void> _setZoom(double zoom, int index) async {
    final range = _zoomRange;
    if (range == null || zoom < range.min || zoom > range.max) {
      _showMessage(context.l10n.scanZoomUnsupported(zoom));
      return;
    }

    final applied = await _cameraService.setZoomLevel(zoom);
    if (!mounted) return;
    if (!applied) {
      _showMessage(context.l10n.scanZoomUnavailable);
      return;
    }
    setState(() {
      _selectedZoom = index;
    });
  }

  bool _supportsZoom(double zoom) {
    final range = _zoomRange;
    return range != null && zoom >= range.min && zoom <= range.max;
  }

  Future<void> _capturePhoto() async {
    if (_isCapturing) return;

    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) {
      _showMessage(_cameraError ?? context.l10n.scanCameraNotReady);
      return;
    }

    setState(() {
      _isCapturing = true;
    });

    try {
      final imagePath = await _cameraService.capturePhoto();
      if (!mounted) return;
      if (imagePath == null || imagePath.isEmpty) {
        throw StateError('Camera returned an empty image path.');
      }

      widget.onCapture?.call();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AiAnalyzingScreen(imagePath: imagePath),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Photo capture failed: $error\n$stackTrace');
      if (mounted) {
        _showMessage(context.l10n.scanCaptureFailed);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCapturing = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
      );
  }

  Widget _buildCameraPreview() {
    final controller = _cameraService.controller;
    if (_isInitializingCamera) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: green),
        ),
      );
    }

    if (_cameraError != null ||
        controller == null ||
        !controller.value.isInitialized) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined, color: muted, size: 34),
              const SizedBox(height: 10),
              Text(
                _cameraError ?? context.l10n.scanCameraUnavailable,
                textAlign: TextAlign.center,
                style: const TextStyle(color: text, fontSize: 12),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _initializeCamera,
                style: OutlinedButton.styleFrom(
                  foregroundColor: green,
                  side: BorderSide(color: green.withOpacity(0.5)),
                ),
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    return CameraPreview(controller);
  }

  @override
  Widget build(BuildContext context) {
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
                      // Back Button
                      _CircleIconButton(
                        icon: Icons.arrow_back_ios_new_rounded,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 14),

                      // Title & Subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.scanTitle,
                              style: TextStyle(
                                color: text,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              context.l10n.scanCenterLeaf,
                              style: TextStyle(
                                color: muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Flash Button
                      GestureDetector(
                        onTap: _setFlashMode,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: _flashAuto ? green.withOpacity(0.12) : card,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _flashAuto
                                  ? green.withOpacity(0.35)
                                  : line,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _flashAuto
                                    ? Icons.flash_auto_rounded
                                    : Icons.flash_off_rounded,
                                color: _flashAuto ? green : muted,
                                size: 16,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _flashAuto
                                    ? context.l10n.flashAuto
                                    : context.l10n.flashOff,
                                style: TextStyle(
                                  color: _flashAuto ? green : muted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Info Button
                      _CircleIconButton(
                        icon: Icons.info_outline_rounded,
                        onTap: () {
                          _showGuideSheet(context);
                        },
                      ),
                    ],
                  ),
                ),

                // ================= VIEWFINDER =================
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Container(
                      width: double.infinity,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(26),
                        border: Border.all(
                          color: green.withOpacity(0.30),
                          width: 1.5,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // 1. Live camera preview, loading state, or error state
                          Positioned.fill(child: _buildCameraPreview()),

                          // Dark vignette
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.35),
                                      Colors.transparent,
                                      Colors.black.withOpacity(0.55),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 2. Top "Keep affected area in focus" chip
                          Positioned(
                            top: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: bg.withOpacity(0.88),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: green.withOpacity(0.35),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: green.withOpacity(0.12),
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.center_focus_strong_rounded,
                                    color: green,
                                    size: 15,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    context.l10n.scanKeepFocus,
                                    style: TextStyle(
                                      color: text,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 3. Neon Focus Reticle Frame
                          SizedBox(
                            width: 250,
                            height: 250,
                            child: CustomPaint(
                              painter: _FocusReticlePainter(color: green),
                            ),
                          ),

                          // 4. Animated Laser Scanner Bar
                          AnimatedBuilder(
                            animation: _laserAnimation,
                            builder: (context, child) {
                              return Positioned(
                                top: 40 + (220 * _laserAnimation.value),
                                child: Container(
                                  width: 230,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: green,
                                    boxShadow: [
                                      BoxShadow(
                                        color: green.withOpacity(0.9),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          // 5. Center Aim Crosshair
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: green.withOpacity(0.4),
                              border: Border.all(color: green, width: 2),
                            ),
                          ),

                          // 6. Zoom Selector Pill (1x, 2x, 3x)
                          if (_cameraError == null)
                            Positioned(
                              bottom: 14,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.75),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.12),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    _ZoomButton(
                                      label: '1x',
                                      selected: _selectedZoom == 0,
                                      enabled: _supportsZoom(1),
                                      onTap: () => _setZoom(1, 0),
                                    ),
                                    _ZoomButton(
                                      label: '2x',
                                      selected: _selectedZoom == 1,
                                      enabled: _supportsZoom(2),
                                      onTap: () => _setZoom(2, 1),
                                    ),
                                    _ZoomButton(
                                      label: '3x',
                                      selected: _selectedZoom == 2,
                                      enabled: _supportsZoom(3),
                                      onTap: () => _setZoom(3, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ================= PHOTO QUALITY EXAMPLES ROW =================
                // Exactly matching 08_plant_scan_camera_guide.png
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        context.l10n.photoGuideTitle,
                        style: TextStyle(
                          color: text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        context.l10n.howToTakePhoto,
                        style: TextStyle(
                          color: green.withOpacity(0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                SizedBox(
                  height: 92,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    children: [
                      _QualityCard(
                        isSuccess: true,
                        badgeText: context.l10n.exampleGood,
                        desc: context.l10n.exampleGoodDesc,
                        icon: Icons.check_circle_rounded,
                      ),
                      _QualityCard(
                        isSuccess: false,
                        badgeText: context.l10n.exampleTooFar,
                        desc: context.l10n.exampleTooFarDesc,
                        icon: Icons.cancel_rounded,
                      ),
                      _QualityCard(
                        isSuccess: false,
                        badgeText: context.l10n.exampleBlurry,
                        desc: context.l10n.exampleBlurryDesc,
                        icon: Icons.cancel_rounded,
                      ),
                      _QualityCard(
                        isSuccess: false,
                        badgeText: context.l10n.exampleObstructed,
                        desc: context.l10n.exampleObstructedDesc,
                        icon: Icons.cancel_rounded,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // ================= BOTTOM CONTROLS =================
                // Gallery, Shutter, Tips
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 6, 28, 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Gallery Button
                      _BottomButton(
                        icon: Icons.photo_library_outlined,
                        label: context.l10n.galleryLabel,
                        onTap: () =>
                            _showMessage(context.l10n.galleryUnavailable),
                      ),

                      // Large Glowing Shutter Button
                      GestureDetector(
                        onTap: _isCapturing ? null : _capturePhoto,
                        child: Container(
                          width: 76,
                          height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: green.withOpacity(0.55),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: green.withOpacity(0.40),
                                blurRadius: 22,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 60,
                              height: 60,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF32F58E),
                                    Color(0xFF16C265),
                                    Color(0xFF0B9349),
                                  ],
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt_rounded,
                                color: Colors.black,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Tips Button
                      _BottomButton(
                        icon: Icons.lightbulb_outline_rounded,
                        label: context.l10n.tipsLabel,
                        onTap: () => _showGuideSheet(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showGuideSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: green.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.eco_rounded, color: green, size: 22),
                ),
                const SizedBox(width: 12),
                Text(
                  context.l10n.photographyGuidelines,
                  style: TextStyle(
                    color: text,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              [
                context.l10n.guideTip1,
                context.l10n.guideTip2,
                context.l10n.guideTip3,
                context.l10n.guideTip4,
              ].join('\n'),
              style: TextStyle(color: muted, fontSize: 14, height: 1.6),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: green,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  context.l10n.gotIt,
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

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

class _ZoomButton extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ZoomButton({
    required this.label,
    required this.selected,
    this.enabled = true,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF20E27A) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: !enabled
                ? Colors.white24
                : selected
                ? Colors.black
                : Colors.white70,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _QualityCard extends StatelessWidget {
  final bool isSuccess;
  final String badgeText;
  final String desc;
  final IconData icon;

  const _QualityCard({
    required this.isSuccess,
    required this.badgeText,
    required this.desc,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = isSuccess
        ? const Color(0xFF20E27A)
        : const Color(0xFFFF5252);

    return Container(
      width: 125,
      margin: const EdgeInsets.only(right: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1D18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuccess
              ? statusColor.withOpacity(0.4)
              : const Color(0xFF1D382F),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: statusColor, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  badgeText,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            desc,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF8EA69A),
              fontSize: 10,
              height: 1.25,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF0D1D18),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1D382F)),
            ),
            child: Icon(icon, color: const Color(0xFFF5FFF8), size: 20),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF8EA69A),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _FocusReticlePainter extends CustomPainter {
  final Color color;

  _FocusReticlePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const cornerLength = 32.0;

    // Top-Left
    canvas.drawLine(const Offset(0, 0), const Offset(cornerLength, 0), paint);
    canvas.drawLine(const Offset(0, 0), const Offset(0, cornerLength), paint);

    // Top-Right
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width - cornerLength, 0),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, 0),
      Offset(size.width, cornerLength),
      paint,
    );

    // Bottom-Left
    canvas.drawLine(
      Offset(0, size.height),
      Offset(cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(0, size.height),
      Offset(0, size.height - cornerLength),
      paint,
    );

    // Bottom-Right
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - cornerLength, size.height),
      paint,
    );
    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - cornerLength),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

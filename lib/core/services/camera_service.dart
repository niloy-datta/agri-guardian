import 'package:camera/camera.dart';

class CameraZoomRange {
  final double min;
  final double max;

  const CameraZoomRange({required this.min, required this.max});
}

class CameraService {
  CameraController? _controller;
  Future<void>? _initializationFuture;
  int _lifecycleToken = 0;

  CameraController? get controller => _controller;

  bool get isInitialized => _controller?.value.isInitialized ?? false;

  bool get isInitializing => _initializationFuture != null;

  Future<void> initialize() {
    if (isInitialized) {
      return Future<void>.value();
    }

    final pendingInitialization = _initializationFuture;
    if (pendingInitialization != null) {
      return pendingInitialization;
    }

    final initialization = _initializeCamera();
    _initializationFuture = initialization;
    return initialization.whenComplete(() {
      if (identical(_initializationFuture, initialization)) {
        _initializationFuture = null;
      }
    });
  }

  Future<void> _initializeCamera() async {
    final token = ++_lifecycleToken;
    final previousController = _controller;
    _controller = null;
    await previousController?.dispose();

    final cameras = await availableCameras();
    if (token != _lifecycleToken) {
      return;
    }
    if (cameras.isEmpty) {
      throw StateError('No cameras are available on this device.');
    }

    final camera = cameras.firstWhere(
      (candidate) => candidate.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    final controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _controller = controller;

    try {
      await controller.initialize();
      if (token != _lifecycleToken || !identical(_controller, controller)) {
        await controller.dispose();
      }
    } catch (_) {
      if (identical(_controller, controller)) {
        _controller = null;
      }
      await controller.dispose();
      rethrow;
    }
  }

  Future<String?> capturePhoto() async {
    final controller = _initializedController;
    final photo = await controller.takePicture();
    return photo.path;
  }

  Future<bool> setFlashMode(FlashMode mode) async {
    final controller = _initializedControllerOrNull;
    if (controller == null) {
      return false;
    }

    try {
      await controller.setFlashMode(mode);
      return true;
    } on CameraException {
      return false;
    } on StateError {
      return false;
    }
  }

  Future<CameraZoomRange?> getZoomRange() async {
    final controller = _initializedControllerOrNull;
    if (controller == null) {
      return null;
    }

    try {
      final min = await controller.getMinZoomLevel();
      final max = await controller.getMaxZoomLevel();
      return CameraZoomRange(min: min, max: max);
    } on CameraException {
      return null;
    } on StateError {
      return null;
    }
  }

  Future<bool> setZoomLevel(double zoom) async {
    final controller = _initializedControllerOrNull;
    if (controller == null) {
      return false;
    }

    try {
      await controller.setZoomLevel(zoom);
      return true;
    } on CameraException {
      return false;
    } on StateError {
      return false;
    }
  }

  CameraController get _initializedController {
    final controller = _initializedControllerOrNull;
    if (controller == null) {
      throw StateError('Camera is not initialized.');
    }
    return controller;
  }

  CameraController? get _initializedControllerOrNull {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return null;
    }
    return controller;
  }

  Future<void> dispose() async {
    ++_lifecycleToken;
    final controller = _controller;
    _controller = null;
    await controller?.dispose();
  }
}


//agrilume-fieldshift
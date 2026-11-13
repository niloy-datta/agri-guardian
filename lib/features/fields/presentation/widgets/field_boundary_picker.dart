import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' as latlng;

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/permission_service.dart';
import '../../../../shared/models/field.dart';
import '../../domain/field_boundary_builder.dart';

const _bg = Color(0xFF06110E);
const _card = Color(0xFF10271E);
const _line = Color(0xFF1D382F);
const _green = Color(0xFF20E27A);
const _text = Color(0xFFF5FFF8);
const _muted = Color(0xFF8EA69A);
const _red = Color(0xFFFF6060);

const int minBoundaryVertices = 3;

/// Bangladesh's approximate centroid - used only as the initial map view
/// before a location fix (or a tap) exists. Never written anywhere as
/// field data.
const _fallbackCenter = latlng.LatLng(23.685, 90.3563);

/// Opens a full-screen map for the farmer to draw their field's real
/// boundary by tapping vertices, and returns the closed GeoJSON Polygon
/// (longitude first, per RFC 7946) on confirm, or null if cancelled.
///
/// No area/perimeter is computed here - PostGIS is the only authority on
/// derived geometry (`backend/api/app/modules/fields/repository.py`); this
/// widget's only job is collecting a structurally valid boundary.
Future<GeoJsonPolygon?> showFieldBoundaryPicker(BuildContext context) {
  return Navigator.of(context).push<GeoJsonPolygon>(
    MaterialPageRoute(builder: (context) => const _FieldBoundaryPickerScreen()),
  );
}

class _FieldBoundaryPickerScreen extends StatefulWidget {
  const _FieldBoundaryPickerScreen();

  @override
  State<_FieldBoundaryPickerScreen> createState() =>
      _FieldBoundaryPickerScreenState();
}

class _FieldBoundaryPickerScreenState
    extends State<_FieldBoundaryPickerScreen> {
  final MapController _mapController = MapController();
  final List<latlng.LatLng> _points = [];
  bool _locating = false;

  @override
  void initState() {
    super.initState();
    // Best-effort: if permission is denied or location fails, the map just
    // stays on the fallback view and the farmer can still tap anywhere.
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnCurrentLocation());
  }

  Future<void> _centerOnCurrentLocation() async {
    setState(() => _locating = true);
    try {
      final granted =
          await PermissionService().requestLocationPermission();
      if (!granted) return;

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;
      final here = latlng.LatLng(position.latitude, position.longitude);
      _mapController.move(here, 17);
    } catch (_) {
      // No GPS fix available; the farmer draws against the fallback view.
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  void _addPoint(latlng.LatLng point) {
    setState(() => _points.add(point));
  }

  void _undoLastPoint() {
    if (_points.isEmpty) return;
    setState(() => _points.removeLast());
  }

  void _clearPoints() {
    setState(() => _points.clear());
  }

  bool get _hasEnoughVertices =>
      FieldBoundaryBuilder.hasEnoughVertices(_points);

  int _uniquePointCount() => FieldBoundaryBuilder.uniquePointCount(_points);

  GeoJsonPolygon _buildGeoJson() =>
      FieldBoundaryBuilder.buildGeoJson(_points)!;

  void _confirm() {
    if (!_hasEnoughVertices) return;
    Navigator.of(context).pop(_buildGeoJson());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _text,
        title: Text(context.l10n.boundaryPickerTitle),
        actions: [
          if (_locating)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _green,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _fallbackCenter,
              initialZoom: 15,
              onTap: (_, point) => _addPoint(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.agriguardian.app',
              ),
              if (_points.length >= 2)
                PolygonLayer(
                  polygons: [
                    Polygon(
                      points: _points,
                      color: _green.withOpacity(.22),
                      borderColor: _green,
                      borderStrokeWidth: 2.5,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  for (int i = 0; i < _points.length; i++)
                    Marker(
                      point: _points[i],
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: i == 0 ? _green : _bg,
                          shape: BoxShape.circle,
                          border: Border.all(color: _green, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _InstructionBanner(pointCount: _uniquePointCount()),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _Controls(
              canUndo: _points.isNotEmpty,
              canClear: _points.isNotEmpty,
              canConfirm: _hasEnoughVertices,
              onUndo: _undoLastPoint,
              onClear: _clearPoints,
              onConfirm: _confirm,
              onLocate: _centerOnCurrentLocation,
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionBanner extends StatelessWidget {
  final int pointCount;

  const _InstructionBanner({required this.pointCount});

  @override
  Widget build(BuildContext context) {
    final enough = pointCount >= minBoundaryVertices;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _bg.withOpacity(.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: enough ? _green : _line),
      ),
      child: Row(
        children: [
          Icon(
            enough ? Icons.check_circle_outline_rounded : Icons.touch_app_rounded,
            color: enough ? _green : _muted,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              enough
                  ? context.l10n.boundaryPointsMarked(pointCount)
                  : context.l10n.boundaryTapHint(minBoundaryVertices),
              style: const TextStyle(color: _text, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  final bool canUndo;
  final bool canClear;
  final bool canConfirm;
  final VoidCallback onUndo;
  final VoidCallback onClear;
  final VoidCallback onConfirm;
  final VoidCallback onLocate;

  const _Controls({
    required this.canUndo,
    required this.canClear,
    required this.canConfirm,
    required this.onUndo,
    required this.onClear,
    required this.onConfirm,
    required this.onLocate,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _RoundIconButton(
              icon: Icons.my_location_rounded,
              onTap: onLocate,
            ),
            const SizedBox(width: 10),
            _RoundIconButton(
              icon: Icons.undo_rounded,
              onTap: canUndo ? onUndo : null,
            ),
            const SizedBox(width: 10),
            _RoundIconButton(
              icon: Icons.delete_outline_rounded,
              onTap: canClear ? onClear : null,
              color: _red,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton(
            onPressed: canConfirm ? onConfirm : null,
            style: FilledButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: _bg,
              disabledBackgroundColor: _card,
              disabledForegroundColor: _muted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Text(
              context.l10n.confirmBoundary,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  const _RoundIconButton({required this.icon, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      borderRadius: BorderRadius.circular(50),
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: _card,
          shape: BoxShape.circle,
          border: Border.all(color: _line),
        ),
        child: Icon(
          icon,
          color: enabled ? (color ?? _text) : _muted.withOpacity(.4),
        ),
      ),
    );
  }
}

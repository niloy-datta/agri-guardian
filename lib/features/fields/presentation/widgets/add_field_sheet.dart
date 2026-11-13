import 'package:flutter/material.dart';
import '../../../../core/localization/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/models/field.dart';
import '../../application/fields_providers.dart';
import '../../data/crop_cycle_repository.dart';
import '../../data/field_repository.dart';
import '../../data/offline/offline_write_result.dart';
import 'field_boundary_picker.dart';

const _bg = Color(0xFF06110E);
const _card = Color(0xFF10271E);
const _line = Color(0xFF1D382F);
const _green = Color(0xFF20E27A);
const _text = Color(0xFFF5FFF8);
const _muted = Color(0xFF8EA69A);
const _red = Color(0xFFFF6060);

/// Opens the Add Field flow as a dark-themed modal bottom sheet.
Future<void> showAddFieldSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    isDismissible: false,
    enableDrag: false,
    builder: (context) => const _AddFieldSheet(),
  );
}

class _AddFieldSheet extends ConsumerStatefulWidget {
  const _AddFieldSheet();

  @override
  ConsumerState<_AddFieldSheet> createState() => _AddFieldSheetState();
}

class _AddFieldSheetState extends ConsumerState<_AddFieldSheet> {
  final String _fieldIdempotencyKey =
      'field-${DateTime.now().microsecondsSinceEpoch}';

  OfflineWriteResult<Field>? _fieldResult;
  String _submittedFieldName = '';

  @override
  Widget build(BuildContext context) {
    final result = _fieldResult;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * .92,
        ),
        decoration: const BoxDecoration(
          color: _bg,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(
            top: BorderSide(color: _line),
            left: BorderSide(color: _line),
            right: BorderSide(color: _line),
          ),
        ),
        child: result == null
            ? _FieldStep(
                idempotencyKey: _fieldIdempotencyKey,
                onCreated: (writeResult, name) {
                  setState(() {
                    _fieldResult = writeResult;
                    _submittedFieldName = name;
                  });
                },
              )
            : _CropCycleStep(
                fieldId: result.isSynced ? result.data!.id : result.tempId!,
                fieldName: result.isSynced ? result.data!.name : _submittedFieldName,
                isOfflineQueued: result.isQueued,
              ),
      ),
    );
  }
}

// ================= STEP 1: FIELD =================

class _FieldStep extends ConsumerStatefulWidget {
  final String idempotencyKey;
  final Function(OfflineWriteResult<Field>, String fieldName) onCreated;

  const _FieldStep({required this.idempotencyKey, required this.onCreated});

  @override
  ConsumerState<_FieldStep> createState() => _FieldStepState();
}

class _FieldStepState extends ConsumerState<_FieldStep> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _countryController = TextEditingController(text: 'BD');
  final _regionController = TextEditingController();
  final _districtController = TextEditingController();
  final _upazilaController = TextEditingController();

  GeoJsonPolygon? _boundary;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _countryController.dispose();
    _regionController.dispose();
    _districtController.dispose();
    _upazilaController.dispose();
    super.dispose();
  }

  Future<void> _pickBoundary() async {
    final result = await showFieldBoundaryPicker(context);
    if (result != null) {
      setState(() {
        _boundary = result;
        _error = null;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_boundary == null) {
      setState(() => _error = context.l10n.boundaryRequired);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    final name = _nameController.text.trim();
    try {
      final result =
          await ref.read(fieldsControllerProvider.notifier).addOrQueueField(
                name: name,
                boundary: _boundary!,
                countryCode: _countryController.text.trim(),
                region: _emptyToNull(_regionController.text),
                district: _emptyToNull(_districtController.text),
                upazila: _emptyToNull(_upazilaController.text),
                idempotencyKey: widget.idempotencyKey,
              );
      widget.onCreated(result, name);
    } on FieldRepositoryException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 18),
            Text(
              context.l10n.addFieldTitle,
              style: TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.addFieldStep1,
              style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            _TextInput(
              controller: _nameController,
              label: context.l10n.fieldNameLabel,
              hint: context.l10n.fieldNameHint,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? context.l10n.fieldNameRequired : null,
            ),
            const SizedBox(height: 14),
            _BoundaryPickerField(boundary: _boundary, onTap: _pickBoundary),
            const SizedBox(height: 14),
            _TextInput(
              controller: _countryController,
              label: context.l10n.countryCodeLabel,
              hint: context.l10n.countryCodeHint,
              validator: (value) {
                final trimmed = (value ?? '').trim();
                if (trimmed.length != 2) return context.l10n.countryCodeInvalid;
                return null;
              },
            ),
            const SizedBox(height: 14),
            _TextInput(
              controller: _regionController,
              label: context.l10n.divisionLabel,
              hint: context.l10n.divisionHint,
            ),
            const SizedBox(height: 14),
            _TextInput(
              controller: _districtController,
              label: context.l10n.districtOptionalLabel,
              hint: context.l10n.districtOptionalHint,
            ),
            const SizedBox(height: 14),
            _TextInput(
              controller: _upazilaController,
              label: context.l10n.upazilaLabel,
              hint: context.l10n.upazilaHint,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: _red, fontSize: 13)),
            ],
            const SizedBox(height: 22),
            _PrimaryButton(
              label: context.l10n.nextAddCrop,
              loading: _saving,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _BoundaryPickerField extends StatelessWidget {
  final GeoJsonPolygon? boundary;
  final VoidCallback onTap;

  const _BoundaryPickerField({required this.boundary, required this.onTap});

  int get _vertexCount {
    if (boundary == null) return 0;
    final rings = boundary!['coordinates'] as List;
    if (rings.isEmpty) return 0;
    return (rings.first as List).length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final drawn = boundary != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.boundaryLabel,
          style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 7),
        InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: drawn ? _green : _line),
            ),
            child: Row(
              children: [
                Icon(
                  drawn ? Icons.check_circle_outline_rounded : Icons.map_outlined,
                  color: drawn ? _green : _muted,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    drawn
                        ? context.l10n.boundaryDrawnCount(_vertexCount)
                        : context.l10n.tapMapToDrawBoundary,
                    style: TextStyle(color: drawn ? _text : _muted, fontSize: 14),
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: _muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ================= STEP 2: CROP CYCLE =================

class _CropCycleStep extends ConsumerStatefulWidget {
  final String fieldId;
  final String fieldName;
  final bool isOfflineQueued;

  const _CropCycleStep({
    required this.fieldId,
    required this.fieldName,
    required this.isOfflineQueued,
  });

  @override
  ConsumerState<_CropCycleStep> createState() => _CropCycleStepState();
}

class _CropCycleStepState extends ConsumerState<_CropCycleStep> {
  final _formKey = GlobalKey<FormState>();
  final _cropCodeController = TextEditingController();
  final _varietyController = TextEditingController();

  String? _idempotencyKey;
  bool _saving = false;
  String? _error;
  bool _cycleCreated = false;
  bool _cycleQueuedOffline = false;

  String get _freshIdempotencyKey =>
      _idempotencyKey ??= 'crop-cycle-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void dispose() {
    _cropCodeController.dispose();
    _varietyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(fieldCropCyclesControllerProvider(widget.fieldId).notifier)
          .addOrQueueCycle(
            cropCode: _cropCodeController.text.trim(),
            variety: _emptyToNull(_varietyController.text),
            idempotencyKey: _freshIdempotencyKey,
          );
      setState(() {
        _cycleCreated = true;
        _cycleQueuedOffline = result.isQueued;
      });
    } on CropCycleRepositoryException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _emptyToNull(String value) =>
      value.trim().isEmpty ? null : value.trim();

  @override
  Widget build(BuildContext context) {
    if (_cycleCreated) {
      return _SuccessStep(
        fieldName: widget.fieldName,
        isOfflineQueued: widget.isOfflineQueued || _cycleQueuedOffline,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isOfflineQueued
                    ? Colors.amber.withOpacity(.10)
                    : _green.withOpacity(.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: widget.isOfflineQueued
                      ? Colors.amber.withOpacity(.3)
                      : _green.withOpacity(.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.isOfflineQueued
                        ? Icons.cloud_off_rounded
                        : Icons.check_circle_rounded,
                    color: widget.isOfflineQueued ? Colors.amber : _green,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.isOfflineQueued
                          ? context.l10n.savedOfflineQueue(widget.fieldName)
                          : context.l10n.fieldSaved(widget.fieldName),
                      style: const TextStyle(color: _text, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.addCropTitle,
              style: TextStyle(color: _text, fontSize: 21, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(
              context.l10n.addCropStep2,
              style: TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 18),
            _TextInput(
              controller: _cropCodeController,
              label: context.l10n.cropCodeLabel,
              hint: context.l10n.cropCodeHint,
              validator: (value) =>
                  (value == null || value.trim().isEmpty) ? context.l10n.cropCodeRequired : null,
            ),
            const SizedBox(height: 14),
            _TextInput(
              controller: _varietyController,
              label: context.l10n.varietyLabel,
              hint: context.l10n.varietyHint,
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: const TextStyle(color: _red, fontSize: 13)),
            ],
            const SizedBox(height: 22),
            _PrimaryButton(
              label: _error == null ? context.l10n.addCropCycleAction : context.l10n.retry,
              loading: _saving,
              onPressed: _submit,
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: Text(
                context.l10n.addLaterAction,
                style: TextStyle(color: _muted, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SuccessStep extends StatelessWidget {
  final String fieldName;
  final bool isOfflineQueued;

  const _SuccessStep({
    required this.fieldName,
    required this.isOfflineQueued,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _SheetHandle(),
          const SizedBox(height: 28),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: (isOfflineQueued ? Colors.amber : _green).withOpacity(.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOfflineQueued ? Icons.cloud_queue_rounded : Icons.check_rounded,
              color: isOfflineQueued ? Colors.amber : _green,
              size: 36,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            isOfflineQueued ? context.l10n.savedInSyncQueue : context.l10n.doneLabel,
            style: const TextStyle(color: _text, fontSize: 19, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(
            isOfflineQueued
                ? context.l10n.successOfflineText(fieldName)
                : context.l10n.successSavedText(fieldName),
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 13),
          ),
          const SizedBox(height: 22),
          _PrimaryButton(
            label: context.l10n.closeAction,
            loading: false,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

// ================= SHARED WIDGETS =================

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: _bg,
          disabledBackgroundColor: _green.withOpacity(.4),
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.4, color: _bg),
              )
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;

  const _TextInput({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: _muted, fontSize: 12, fontWeight: FontWeight.w700)),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(color: _text, fontSize: 15),
          cursorColor: _green,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: _muted, fontSize: 14),
            filled: true,
            fillColor: _card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _green),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _red),
            ),
          ),
        ),
      ],
    );
  }
}

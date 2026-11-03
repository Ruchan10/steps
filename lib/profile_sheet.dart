import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'metrics.dart';

/// Bottom sheet to edit height, weight and units. Returns the new profile, or null if dismissed.
Future<BodyProfile?> showProfileSheet(BuildContext context, BodyProfile current) {
  HapticFeedback.selectionClick();
  return showModalBottomSheet<BodyProfile>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ProfileSheet(initial: current),
  );
}

class _ProfileSheet extends StatefulWidget {
  const _ProfileSheet({required this.initial});

  final BodyProfile initial;

  @override
  State<_ProfileSheet> createState() => _ProfileSheetState();
}

class _ProfileSheetState extends State<_ProfileSheet> {
  late BodyProfile? _draft = widget.initial;

  void _save() {
    final draft = _draft;
    if (draft != null) Navigator.pop(context, draft);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.yourDetails, style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              l.yourDetailsBody,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            ProfileForm(
              initial: widget.initial,
              onChanged: (profile) => setState(() => _draft = profile),
              onSubmitted: _save,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _draft == null ? null : _save,
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}

/// Units toggle plus height and weight fields. Used by the details sheet and onboarding.
class ProfileForm extends StatefulWidget {
  const ProfileForm({
    super.key,
    required this.initial,
    this.startEmpty = false,
    required this.onChanged,
    this.onSubmitted,
  });

  final BodyProfile initial;

  /// Leave height and weight blank for the user to fill in, instead of showing [initial]'s.
  final bool startEmpty;

  /// The edited profile, or null while a field is empty or out of range.
  final ValueChanged<BodyProfile?> onChanged;
  final VoidCallback? onSubmitted;

  @override
  State<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends State<ProfileForm> {
  static const _cmPerInch = 2.54;
  static const _lbPerKg = 2.20462;

  // Kept in metric with full precision so toggling units back and forth doesn't drift.
  late double? _heightCm = widget.startEmpty ? null : widget.initial.heightCm.toDouble();
  late double? _weightKg = widget.startEmpty ? null : widget.initial.weightKg.toDouble();
  late bool _imperial = widget.initial.imperial;

  final _height = TextEditingController();
  final _feet = TextEditingController();
  final _inches = TextEditingController();
  final _weight = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fillFields();
  }

  @override
  void dispose() {
    for (final c in [_height, _feet, _inches, _weight]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fillFields() {
    final cm = _heightCm;
    final kg = _weightKg;
    if (_imperial) {
      if (cm != null) {
        final totalInches = (cm / _cmPerInch).round();
        _feet.text = '${totalInches ~/ 12}';
        _inches.text = '${totalInches % 12}';
      }
      _weight.text = kg == null ? '' : '${(kg * _lbPerKg).round()}';
    } else {
      _height.text = cm == null ? '' : '${cm.round()}';
      _weight.text = kg == null ? '' : '${kg.round()}';
    }
  }

  void _readHeight() {
    if (_imperial) {
      final ft = int.tryParse(_feet.text);
      final inch = int.tryParse(_inches.text.isEmpty ? '0' : _inches.text);
      _heightCm = ft == null || inch == null ? null : (ft * 12 + inch) * _cmPerInch;
    } else {
      _heightCm = double.tryParse(_height.text);
    }
    _changed();
  }

  void _readWeight() {
    final v = double.tryParse(_weight.text);
    _weightKg = v == null ? null : (_imperial ? v / _lbPerKg : v);
    _changed();
  }

  void _setUnits(bool imperial) {
    HapticFeedback.selectionClick();
    setState(() => _imperial = imperial);
    _fillFields();
    _changed();
  }

  void _changed() {
    setState(() {});
    widget.onChanged(
      _heightValid && _weightValid
          ? widget.initial.copyWith(heightCm: _heightCm!.round(), weightKg: _weightKg!.round(), imperial: _imperial)
          : null,
    );
  }

  bool get _heightValid => _heightCm != null && _heightCm! >= 100 && _heightCm! <= 250;
  bool get _weightValid => _weightKg != null && _weightKg! >= 25 && _weightKg! <= 300;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final digits = [const DigitsFormatter(), LengthLimitingTextInputFormatter(3)];
    // Blank fields just disable saving; only point out values that are out of range.
    final heightEntered = _imperial ? _feet.text.isNotEmpty : _height.text.isNotEmpty;
    final heightError = !heightEntered || _heightValid
        ? null
        : _imperial
            ? l.heightRangeFtIn(formatSteps(3), formatSteps(4), formatSteps(8), formatSteps(2))
            : l.heightRangeCm(formatSteps(100), formatSteps(250));
    final weightError = _weight.text.isEmpty || _weightValid
        ? null
        : _imperial
            ? l.weightRangeLb(formatSteps(55), formatSteps(660))
            : l.weightRangeKg(formatSteps(25), formatSteps(300));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l.metric)),
            ButtonSegment(value: true, label: Text(l.imperial)),
          ],
          selected: {_imperial},
          showSelectedIcon: false,
          onSelectionChanged: (s) => _setUnits(s.first),
        ),
        const SizedBox(height: 20),
        if (_imperial)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: _feet,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: l.height,
                    suffixText: l.unitFt,
                    border: const OutlineInputBorder(),
                    // Keeps "ft"/"in" visible while the fields are still empty.
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                    errorText: heightError,
                    errorMaxLines: 2,
                  ),
                  onChanged: (_) => _readHeight(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _inches,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    suffixText: l.unitIn,
                    border: const OutlineInputBorder(),
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  onChanged: (_) => _readHeight(),
                ),
              ),
            ],
          )
        else
          TextField(
            controller: _height,
            keyboardType: TextInputType.number,
            inputFormatters: digits,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l.height,
              suffixText: l.unitCm,
              border: const OutlineInputBorder(),
              floatingLabelBehavior: FloatingLabelBehavior.always,
              errorText: heightError,
            ),
            onChanged: (_) => _readHeight(),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _weight,
          keyboardType: TextInputType.number,
          inputFormatters: digits,
          decoration: InputDecoration(
            labelText: l.weight,
            suffixText: _imperial ? l.unitLb : l.unitKg,
            border: const OutlineInputBorder(),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            errorText: weightError,
          ),
          onChanged: (_) => _readWeight(),
          onSubmitted: (_) => widget.onSubmitted?.call(),
        ),
      ],
    );
  }
}

/// Keeps only digits, turning Devanagari ones (०-९) into 0-9 so Nepali keyboards work too.
class DigitsFormatter extends TextInputFormatter {
  const DigitsFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = StringBuffer();
    for (final c in newValue.text.runes) {
      if (c >= 0x30 && c <= 0x39) {
        digits.writeCharCode(c);
      } else if (c >= 0x966 && c <= 0x96F) {
        digits.writeCharCode(c - 0x966 + 0x30);
      }
    }
    final text = digits.toString();
    if (text == newValue.text) return newValue;
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }
}

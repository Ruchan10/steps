import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'format.dart';
import 'metrics.dart';
import 'profile_sheet.dart';

/// Returned by a unit sheet's "Edit" button to open the details sheet instead.
const _editDetails = #editDetails;

/// Lets the user pick km or miles. Returns the updated profile, or null if nothing changed.
Future<BodyProfile?> showDistanceSheet(BuildContext context, BodyProfile profile) async {
  HapticFeedback.selectionClick();
  final result = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final l = context.l10n;
      return _ChoiceSheet<DistanceUnit>(
        title: l.distance,
        body: l.distanceSheetBody,
        value: profile.distanceUnit,
        options: [(DistanceUnit.km, l.kilometres), (DistanceUnit.mi, l.miles)],
        footnote: l.estimatedFromHeight(l.formatHeight(profile)),
      );
    },
  );
  if (!context.mounted) return null;
  if (result == _editDetails) return showProfileSheet(context, profile);
  return result is DistanceUnit && result != profile.distanceUnit ? profile.copyWith(distanceUnit: result) : null;
}

/// Lets the user pick kcal or kJ. Returns the updated profile, or null if nothing changed.
Future<BodyProfile?> showEnergySheet(BuildContext context, BodyProfile profile) async {
  HapticFeedback.selectionClick();
  final result = await showModalBottomSheet<Object>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final l = context.l10n;
      return _ChoiceSheet<EnergyUnit>(
        title: l.calories,
        body: l.caloriesSheetBody,
        value: profile.energyUnit,
        options: [(EnergyUnit.kcal, l.kilocalories), (EnergyUnit.kj, l.kilojoules)],
        footnote: l.estimatedFromWeight(l.formatWeight(profile)),
      );
    },
  );
  if (!context.mounted) return null;
  if (result == _editDetails) return showProfileSheet(context, profile);
  return result is EnergyUnit && result != profile.energyUnit ? profile.copyWith(energyUnit: result) : null;
}

/// Lets the user pick the app language: "en", "ne", or null for the phone's language.
Future<void> showLanguageSheet(
  BuildContext context, {
  required String? current,
  required ValueChanged<String?> onChanged,
}) async {
  HapticFeedback.selectionClick();
  const system = 'system';
  final result = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      final l = context.l10n;
      return _ChoiceSheet<String>(
        title: l.language,
        value: current ?? system,
        // Language names are written in their own language so anyone can find theirs.
        options: [(system, l.languageSystem), ('en', 'English'), ('ne', 'नेपाली')],
      );
    },
  );
  if (result == null) return;
  final language = result == system ? null : result;
  if (language != current) onChanged(language);
}

/// A titled list of choices. Picking one closes the sheet with its value.
class _ChoiceSheet<T> extends StatelessWidget {
  const _ChoiceSheet({required this.title, this.body, required this.value, required this.options, this.footnote});

  final String title;
  final String? body;
  final T value;
  final List<(T, String)> options;

  /// How the values are estimated, with a button to edit the details behind them.
  final String? footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final footnote = this.footnote;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(title, style: theme.textTheme.titleLarge),
            ),
            if (body != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 0),
                child: Text(body!, style: muted),
              ),
            const SizedBox(height: 8),
            RadioGroup<T>(
              groupValue: value,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                Navigator.pop(context, v);
              },
              child: Column(
                children: [
                  for (final (option, label) in options)
                    RadioListTile<T>(
                      value: option,
                      title: Text(label),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                ],
              ),
            ),
            if (footnote != null) ...[
              const Divider(height: 24, indent: 24, endIndent: 24),
              Padding(
                padding: const EdgeInsets.only(left: 24, right: 12),
                child: Row(
                  children: [
                    Expanded(child: Text(footnote, style: muted)),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => Navigator.pop(context, _editDetails),
                      child: Text(context.l10n.edit),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:gains/core/preferences/body_units_preference.dart';
import 'package:gains/core/units/body_units.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:provider/provider.dart';

/// Height and weight inputs with metric/imperial toggle (stored as cm/kg on submit).
class ProfileBodyFields extends StatelessWidget {
  const ProfileBodyFields({
    super.key,
    required this.heightController,
    required this.weightController,
  });

  final TextEditingController heightController;
  final TextEditingController weightController;

  @override
  Widget build(BuildContext context) {
    final units = context.watch<BodyUnitsPreference>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Units', style: Theme.of(context).textTheme.labelLarge),
            const Spacer(),
            SegmentedButton<BodyUnitSystem>(
              segments: const [
                ButtonSegment(value: BodyUnitSystem.metric, label: Text('Metric')),
                ButtonSegment(value: BodyUnitSystem.imperial, label: Text('US')),
              ],
              selected: {units.units},
              onSelectionChanged: (s) => units.setUnits(s.first),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: GainsTextField(
                controller: heightController,
                label: units.isMetric ? 'Height (cm)' : 'Height',
                hint: units.isMetric ? null : "e.g. 5'10",
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                validator: (v) => BodyUnits.validateHeightInput(v, units.units),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GainsTextField(
                controller: weightController,
                label: units.isMetric ? 'Weight (kg)' : 'Weight (lb)',
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textInputAction: TextInputAction.next,
                validator: (v) => BodyUnits.validateWeightInput(v, units.units),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static void prefillFromProfile({
    required TextEditingController height,
    required TextEditingController weight,
    required BodyUnitSystem units,
    double? heightCm,
    double? weightKg,
  }) {
    if (heightCm != null && height.text.isEmpty) {
      height.text = BodyUnits.formatHeightCm(heightCm, units);
    }
    if (weightKg != null && weight.text.isEmpty) {
      weight.text = BodyUnits.formatWeightKg(weightKg, units);
    }
  }

  static ({double heightCm, double weightKg}) parse({
    required String heightRaw,
    required String weightRaw,
    required BodyUnitSystem units,
  }) {
    final h = BodyUnits.parseHeightToCm(heightRaw, units)!;
    final w = BodyUnits.parseWeightToKg(weightRaw, units)!;
    return (heightCm: h, weightKg: w);
  }
}

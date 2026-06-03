import 'package:flutter/material.dart';
import 'package:gains/core/preferences/body_units_preference.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/units/body_units.dart';
import 'package:provider/provider.dart';

/// Height and weight pickers (sliders). Values are kept as cm/kg; API always uses metric.
class ProfileBodyFields extends StatefulWidget {
  const ProfileBodyFields({
    super.key,
    this.initialHeightCm,
    this.initialWeightKg,
  });

  final double? initialHeightCm;
  final double? initialWeightKg;

  @override
  State<ProfileBodyFields> createState() => ProfileBodyFieldsState();
}

class ProfileBodyFieldsState extends State<ProfileBodyFields> {
  late double _heightCm;
  late double _weightKg;

  @override
  void initState() {
    super.initState();
    _heightCm = _clampHeight(widget.initialHeightCm ?? BodyUnits.defaultHeightCm);
    _weightKg = _clampWeight(widget.initialWeightKg ?? BodyUnits.defaultWeightKg);
  }

  double get heightCm => _heightCm;
  double get weightKg => _weightKg;

  /// Validates current slider values. Returns an error message or null if OK.
  String? validate() {
    return BodyUnits.validateHeightCm(_heightCm) ?? BodyUnits.validateWeightKg(_weightKg);
  }

  static double _clampHeight(double cm) =>
      cm.clamp(BodyUnits.minHeightCm.toDouble(), BodyUnits.maxHeightCm.toDouble());

  static double _clampWeight(double kg) =>
      kg.clamp(BodyUnits.minWeightKg.toDouble(), BodyUnits.maxWeightKg.toDouble());

  @override
  Widget build(BuildContext context) {
    final units = context.watch<BodyUnitsPreference>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Units', style: theme.textTheme.labelLarge),
            const Spacer(),
            SegmentedButton<BodyUnitSystem>(
              segments: const [
                ButtonSegment(value: BodyUnitSystem.metric, label: Text('Metric')),
                ButtonSegment(value: BodyUnitSystem.imperial, label: Text('Imperial')),
              ],
              selected: {units.units},
              onSelectionChanged: (s) => units.setUnits(s.first),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Metric (cm, kg) or imperial (ft/in, lb) — common in the US and UK.',
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        _BodySliderCard(
          label: 'Height',
          valueLabel: BodyUnits.formatHeightDisplay(_heightCm, units.units),
          child: units.isMetric ? _metricHeightSlider() : _imperialHeightSlider(),
        ),
        const SizedBox(height: 16),
        _BodySliderCard(
          label: 'Weight',
          valueLabel: BodyUnits.formatWeightDisplay(_weightKg, units.units),
          child: units.isMetric ? _metricWeightSlider() : _imperialWeightSlider(),
        ),
      ],
    );
  }

  Widget _metricHeightSlider() {
    return Slider(
      value: _heightCm.clamp(BodyUnits.minHeightCm.toDouble(), BodyUnits.maxHeightCm.toDouble()),
      min: BodyUnits.minHeightCm.toDouble(),
      max: BodyUnits.maxHeightCm.toDouble(),
      divisions: BodyUnits.maxHeightCm - BodyUnits.minHeightCm,
      label: '${_heightCm.round()} cm',
      onChanged: (v) => setState(() => _heightCm = v.roundToDouble()),
    );
  }

  Widget _imperialHeightSlider() {
    final totalIn = BodyUnits.cmToTotalInches(_heightCm);
    return Slider(
      value: totalIn.toDouble(),
      min: BodyUnits.minTotalInches.toDouble(),
      max: BodyUnits.maxTotalInches.toDouble(),
      divisions: BodyUnits.maxTotalInches - BodyUnits.minTotalInches,
      label: BodyUnits.formatHeightDisplay(_heightCm, BodyUnitSystem.imperial),
      onChanged: (v) => setState(() => _heightCm = BodyUnits.totalInchesToCm(v.round())),
    );
  }

  Widget _metricWeightSlider() {
    return Slider(
      value: _weightKg.clamp(BodyUnits.minWeightKg.toDouble(), BodyUnits.maxWeightKg.toDouble()),
      min: BodyUnits.minWeightKg.toDouble(),
      max: BodyUnits.maxWeightKg.toDouble(),
      divisions: BodyUnits.maxWeightKg - BodyUnits.minWeightKg,
      label: '${_weightKg.round()} kg',
      onChanged: (v) => setState(() => _weightKg = v.roundToDouble()),
    );
  }

  Widget _imperialWeightSlider() {
    final lb = BodyUnits.kgToLb(_weightKg);
    return Slider(
      value: lb.toDouble(),
      min: BodyUnits.minWeightLb.toDouble(),
      max: BodyUnits.maxWeightLb.toDouble(),
      divisions: BodyUnits.maxWeightLb - BodyUnits.minWeightLb,
      label: '$lb lb',
      onChanged: (v) => setState(() => _weightKg = BodyUnits.lbToKg(v.round())),
    );
  }
}

class _BodySliderCard extends StatelessWidget {
  const _BodySliderCard({
    required this.label,
    required this.valueLabel,
    required this.child,
  });

  final String label;
  final String valueLabel;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Text(
          valueLabel,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        child,
      ],
    );
  }
}

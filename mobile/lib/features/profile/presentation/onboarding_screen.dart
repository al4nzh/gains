import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/gains_scaffold.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:gains/core/widgets/option_chip_group.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:gains/features/profile/models/profile_options.dart';
import 'package:gains/features/profile/models/profile_update.dart';
import 'package:provider/provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _injuryNotes = TextEditingController();

  String? _goal;
  String? _experienceLevel;
  String? _activityLevel;
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    _injuryNotes.dispose();
    super.dispose();
  }

  void _prefillFromSession(AuthSession session) {
    if (_initialized) return;
    final p = session.profile;
    if (p == null) return;

    _goal = p.goal;
    _experienceLevel = p.experience;
    _activityLevel = p.activityLevel;
    if (p.heightCm != null) _height.text = _formatNum(p.heightCm!);
    if (p.weightKg != null) _weight.text = _formatNum(p.weightKg!);
    if (p.injuryNotes != null) _injuryNotes.text = p.injuryNotes!;
    _initialized = true;
  }

  String _formatNum(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toString();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_goal == null || _experienceLevel == null || _activityLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select goal, experience, and activity level')),
      );
      return;
    }

    final height = double.parse(_height.text.replaceAll(',', '.').trim());
    final weight = double.parse(_weight.text.replaceAll(',', '.').trim());
    final notes = _injuryNotes.text.trim();

    setState(() => _loading = true);
    final session = context.read<AuthSession>();

    try {
      await session.completeOnboarding(
        ProfileUpdate(
          goal: _goal,
          experience: _experienceLevel,
          heightCm: height,
          weightKg: weight,
          activityLevel: _activityLevel,
          injuryNotes: notes.isEmpty ? '' : notes,
        ),
      );
      if (!mounted) return;
      context.go('/home');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AuthSession>();
    _prefillFromSession(session);

    return GainsScaffold(
      appBar: AppBar(title: const Text('Profile setup')),
      padding: EdgeInsets.zero,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              'About your training',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Powers your home dashboard, targets, and coach.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 28),
            _sectionLabel(context, 'Goal'),
            const SizedBox(height: 8),
            OptionChipGroup(
              options: ProfileOptions.goals,
              selected: _goal,
              onSelected: (v) => setState(() => _goal = v),
            ),
            const SizedBox(height: 24),
            _sectionLabel(context, 'Experience'),
            const SizedBox(height: 8),
            OptionChipGroup(
              options: ProfileOptions.experience,
              selected: _experienceLevel,
              onSelected: (v) => setState(() => _experienceLevel = v),
            ),
            const SizedBox(height: 24),
            _sectionLabel(context, 'Activity outside the gym'),
            const SizedBox(height: 8),
            OptionChipGroup(
              options: ProfileOptions.activityLevels,
              selected: _activityLevel,
              onSelected: (v) => setState(() => _activityLevel = v),
            ),
            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: GainsTextField(
                    controller: _height,
                    label: 'Height (cm)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Required';
                      }
                      final n = double.tryParse(v.replaceAll(',', '.'));
                      if (n == null) return 'Enter a number';
                      if (n < 50 || n > 300) return '50–300 cm';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GainsTextField(
                    controller: _weight,
                    label: 'Weight (kg)',
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    textInputAction: TextInputAction.next,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Required';
                      }
                      final n = double.tryParse(v.replaceAll(',', '.'));
                      if (n == null) return 'Enter a number';
                      if (n < 20 || n > 400) return '20–400 kg';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            GainsTextField(
              controller: _injuryNotes,
              label: 'Injuries / limitations',
              hint: 'Optional — e.g. shoulder, lower back',
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              minLines: 2,
              maxLines: 4,
              validator: (v) {
                if (v != null && v.length > 2000) {
                  return 'Max 2000 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Continue'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(text, style: Theme.of(context).textTheme.labelLarge);
  }
}

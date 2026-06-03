import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/preferences/body_units_preference.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/widgets/gains_scaffold.dart';
import 'package:gains/core/widgets/gains_text_field.dart';
import 'package:gains/core/widgets/option_chip_group.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:gains/features/profile/models/profile_options.dart';
import 'package:gains/features/profile/models/profile_update.dart';
import 'package:gains/features/profile/widgets/onboarding_step_header.dart';
import 'package:gains/features/profile/widgets/profile_body_fields.dart';
import 'package:provider/provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _totalSteps = 3;

  final _formKey = GlobalKey<FormState>();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _injuryNotes = TextEditingController();

  int _step = 0;
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

  void _prefillFromSession(AuthSession session, BodyUnitsPreference units) {
    if (_initialized) return;
    final p = session.profile;
    if (p == null) return;

    _goal = p.goal;
    _experienceLevel = p.experience;
    _activityLevel = p.activityLevel;
    ProfileBodyFields.prefillFromProfile(
      height: _height,
      weight: _weight,
      units: units.units,
      heightCm: p.heightCm,
      weightKg: p.weightKg,
    );
    if (p.injuryNotes != null) _injuryNotes.text = p.injuryNotes!;
    _initialized = true;
  }

  bool _validateStep(int step) {
    switch (step) {
      case 0:
        if (_goal == null || _experienceLevel == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select your goal and experience level')),
          );
          return false;
        }
        return true;
      case 1:
        if (_activityLevel == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select your activity level')),
          );
          return false;
        }
        if (!_formKey.currentState!.validate()) return false;
        return true;
      case 2:
        final notes = _injuryNotes.text.trim();
        if (notes.length > 2000) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Injury notes must be under 2000 characters')),
          );
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateStep(_step)) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
      return;
    }
    _submit();
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _submit() async {
    if (!_validateStep(0) || !_validateStep(1) || !_validateStep(2)) return;

    final units = context.read<BodyUnitsPreference>().units;
    final parsed = ProfileBodyFields.parse(
      heightRaw: _height.text,
      weightRaw: _weight.text,
      units: units,
    );
    final notes = _injuryNotes.text.trim();

    setState(() => _loading = true);
    final session = context.read<AuthSession>();

    try {
      await session.completeOnboarding(
        ProfileUpdate(
          goal: _goal,
          experience: _experienceLevel,
          heightCm: parsed.heightCm,
          weightKg: parsed.weightKg,
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
    final units = context.watch<BodyUnitsPreference>();
    _prefillFromSession(session, units);

    return GainsScaffold(
      appBar: AppBar(
        title: const Text('Profile setup'),
        leading: _step > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _loading ? null : _back,
              )
            : null,
      ),
      padding: EdgeInsets.zero,
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                children: [
                  if (_step == 0) _buildStepGoals(context),
                  if (_step == 1) _buildStepBody(context),
                  if (_step == 2) _buildStepInjuries(context),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: ElevatedButton(
                onPressed: _loading ? null : _next,
                child: _loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_step == _totalSteps - 1 ? 'Finish' : 'Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepGoals(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingStepHeader(
          step: 0,
          totalSteps: _totalSteps,
          title: 'Your training focus',
          subtitle: 'We use this for home targets, progress scoring, and your coach.',
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
      ],
    );
  }

  Widget _buildStepBody(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingStepHeader(
          step: 1,
          totalSteps: _totalSteps,
          title: 'About you',
          subtitle: 'Height and weight power calorie and protein targets on your dashboard.',
        ),
        const SizedBox(height: 28),
        _sectionLabel(context, 'Activity outside the gym'),
        const SizedBox(height: 8),
        OptionChipGroup(
          options: ProfileOptions.activityLevels,
          selected: _activityLevel,
          onSelected: (v) => setState(() => _activityLevel = v),
        ),
        const SizedBox(height: 24),
        ProfileBodyFields(
          heightController: _height,
          weightController: _weight,
        ),
      ],
    );
  }

  Widget _buildStepInjuries(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const OnboardingStepHeader(
          step: 2,
          totalSteps: _totalSteps,
          title: 'Anything we should know?',
          subtitle: 'Optional — helps the coach and AI routines avoid aggravating injuries.',
        ),
        const SizedBox(height: 28),
        GainsTextField(
          controller: _injuryNotes,
          label: 'Injuries / limitations',
          hint: 'e.g. shoulder impingement, lower back',
          keyboardType: TextInputType.multiline,
          textInputAction: TextInputAction.newline,
          minLines: 3,
          maxLines: 5,
        ),
        const SizedBox(height: 12),
        Text(
          'You can skip this and add notes later in Profile.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
      ],
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(text, style: Theme.of(context).textTheme.labelLarge);
  }
}

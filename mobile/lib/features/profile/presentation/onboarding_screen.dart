import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/core/api/api_exception.dart';
import 'package:gains/core/theme/app_colors.dart';
import 'package:gains/core/units/body_units.dart';
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
  final _bodyFieldsKey = GlobalKey<ProfileBodyFieldsState>();
  final _injuryNotes = TextEditingController();
  double? _initialHeightCm;
  double? _initialWeightKg;

  int _step = 0;
  String? _goal;
  String? _experienceLevel;
  String? _daysPerWeek;
  String? _activityLevel;
  String? _gender;
  double? _heightCm;
  double? _weightKg;
  bool _loading = false;
  bool _initialized = false;

  @override
  void dispose() {
    _injuryNotes.dispose();
    super.dispose();
  }

  void _prefillFromSession(AuthSession session) {
    if (_initialized) return;
    final p = session.profile;
    if (p == null) return;

    _goal = p.goal;
    _experienceLevel = p.experience;
    _daysPerWeek = p.trainingDaysPerWeek?.toString();
    _activityLevel = p.activityLevel;
    _gender = p.gender;
    _initialHeightCm = p.heightCm;
    _initialWeightKg = p.weightKg;
    _heightCm = p.heightCm;
    _weightKg = p.weightKg;
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
        if (_daysPerWeek == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select how many days you can train')),
          );
          return false;
        }
        return true;
      case 1:
        if (_gender == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select your gender')),
          );
          return false;
        }
        if (_activityLevel == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Select your activity level')),
          );
          return false;
        }
        final body = _bodyFieldsKey.currentState;
        if (body == null) {
          if (_heightCm == null || _weightKg == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Set your height and weight')),
            );
            return false;
          }
          final bodyErr =
              BodyUnits.validateHeightCm(_heightCm!) ?? BodyUnits.validateWeightKg(_weightKg!);
          if (bodyErr != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bodyErr)));
            return false;
          }
        } else {
          final bodyErr = body.validate();
          if (bodyErr != null) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bodyErr)));
            return false;
          }
        }
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
    if (_step == 1) {
      final body = _bodyFieldsKey.currentState;
      if (body != null) {
        _heightCm = body.heightCm;
        _weightKg = body.weightKg;
      }
    }
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

    final heightCm = _heightCm;
    final weightKg = _weightKg;
    if (heightCm == null || weightKg == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Go back and set your height and weight')),
      );
      return;
    }
    final notes = _injuryNotes.text.trim();

    setState(() => _loading = true);
    final session = context.read<AuthSession>();

    try {
      await session.completeOnboarding(
        ProfileUpdate(
          goal: _goal,
          experience: _experienceLevel,
          trainingDaysPerWeek: int.parse(_daysPerWeek!),
          heightCm: heightCm,
          weightKg: weightKg,
          activityLevel: _activityLevel,
          gender: _gender,
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
        const SizedBox(height: 24),
        _sectionLabel(context, 'Days per week'),
        const SizedBox(height: 8),
        Text(
          'We\'ll suggest a starter program that fits your schedule.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        const SizedBox(height: 8),
        OptionChipGroup(
          options: ProfileOptions.daysPerWeek,
          selected: _daysPerWeek,
          onSelected: (v) => setState(() => _daysPerWeek = v),
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
        _sectionLabel(context, 'Gender'),
        const SizedBox(height: 8),
        Text(
          'Used for fair strength ranks and percentile vs your peer group.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        const SizedBox(height: 8),
        OptionChipGroup(
          options: ProfileOptions.genders,
          selected: _gender,
          onSelected: (v) => setState(() => _gender = v),
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
        ProfileBodyFields(
          key: _bodyFieldsKey,
          initialHeightCm: _initialHeightCm,
          initialWeightKg: _initialWeightKg,
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

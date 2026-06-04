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
import 'package:gains/features/profile/widgets/profile_body_fields.dart';
import 'package:gains/features/shell/shell_tab_refresh.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _bodyFieldsKey = GlobalKey<ProfileBodyFieldsState>();
  final _injuryNotes = TextEditingController();
  double? _initialHeightCm;
  double? _initialWeightKg;

  String? _goal;
  String? _experienceLevel;
  String? _activityLevel;
  String? _gender;
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
    _activityLevel = p.activityLevel;
    _gender = p.gender;
    _initialHeightCm = p.heightCm;
    _initialWeightKg = p.weightKg;
    if (p.injuryNotes != null) _injuryNotes.text = p.injuryNotes!;
    _initialized = true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final bodyErr = _bodyFieldsKey.currentState?.validate();
    if (bodyErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(bodyErr)));
      return;
    }

    if (_goal == null || _experienceLevel == null || _gender == null || _activityLevel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select goal, experience, gender, and activity level')),
      );
      return;
    }

    final body = _bodyFieldsKey.currentState!;
    final notes = _injuryNotes.text.trim();

    setState(() => _loading = true);
    final session = context.read<AuthSession>();

    try {
      await session.updateProfile(
        ProfileUpdate(
          goal: _goal,
          experience: _experienceLevel,
          heightCm: body.heightCm,
          weightKg: body.weightKg,
          activityLevel: _activityLevel,
          gender: _gender,
          injuryNotes: notes.isEmpty ? '' : notes,
        ),
      );
      if (!mounted) return;
      context.read<ShellTabRefresh>().bump(ShellTab.home);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      context.pop();
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
        title: const Text('Edit profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _loading ? null : () => context.pop(),
        ),
      ),
      padding: EdgeInsets.zero,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          children: [
            Text(
              'Training profile',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Used for home targets, AI coach, and routine generation.',
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
            _sectionLabel(context, 'Gender'),
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
                  : const Text('Save'),
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

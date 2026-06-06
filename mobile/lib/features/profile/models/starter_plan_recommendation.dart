import 'package:gains/features/profile/models/profile.dart';
import 'package:gains/features/profile/models/profile_options.dart';
import 'package:gains/features/profile/models/routine_template_ids.dart';
import 'package:gains/features/routines/models/routine_template.dart';

class StarterPlanRecommendation {
  const StarterPlanRecommendation({
    required this.title,
    required this.subtitle,
    required this.templateIds,
    required this.firstTemplateId,
  });

  final String title;
  final String subtitle;
  final List<String> templateIds;
  final String firstTemplateId;
}

StarterPlanRecommendation recommendStarterPlan(Profile profile) {
  final days = profile.trainingDaysPerWeek ?? 3;
  final goal = profile.goal ?? 'general_fitness';
  final experience = profile.experience ?? 'beginner';

  if (_prefersHomeEquipment(profile.injuryNotes)) {
    return _pack(
      title: 'Home-friendly starter',
      subtitle: 'Minimal equipment — repeat 2–3× per week as you recover.',
      templateIds: const [RoutineTemplateIds.homeMinimal],
      first: RoutineTemplateIds.homeMinimal,
    );
  }

  if (goal == 'strength') {
    if (days <= 3) {
      return _pack(
        title: 'Strength 5×5',
        subtitle: 'Heavy compounds — run the same session $days× per week.',
        templateIds: const [RoutineTemplateIds.strength5x5],
        first: RoutineTemplateIds.strength5x5,
      );
    }
    return _pack(
      title: 'Upper / lower strength',
      subtitle: 'Four-day split with squat and hinge emphasis.',
      templateIds: const [
        RoutineTemplateIds.upperBodyA,
        RoutineTemplateIds.lowerBodyA,
        RoutineTemplateIds.upperBodyB,
        RoutineTemplateIds.lowerBodyB,
      ],
      first: RoutineTemplateIds.upperBodyA,
    );
  }

  if (days == 2) {
    if (experience == 'beginner' ||
        goal == 'general_fitness' ||
        goal == 'fat_loss') {
      return _pack(
        title: 'Full-body starter',
        subtitle: 'Two full-body sessions per week — great for building consistency.',
        templateIds: const [RoutineTemplateIds.beginnerFullBody],
        first: RoutineTemplateIds.beginnerFullBody,
      );
    }
    return _pack(
      title: 'Upper / lower (2-day)',
      subtitle: 'One upper and one lower session each week.',
      templateIds: const [
        RoutineTemplateIds.upperBodyA,
        RoutineTemplateIds.lowerBodyA,
      ],
      first: RoutineTemplateIds.upperBodyA,
    );
  }

  if (days == 3) {
    if (experience == 'beginner' &&
        goal != 'muscle_gain') {
      return _pack(
        title: 'Beginner full body',
        subtitle: 'Same balanced session 3× per week while you learn the lifts.',
        templateIds: const [RoutineTemplateIds.beginnerFullBody],
        first: RoutineTemplateIds.beginnerFullBody,
      );
    }
    if (goal == 'fat_loss' || goal == 'general_fitness') {
      return _pack(
        title: 'Full-body hypertrophy',
        subtitle: 'Moderate volume — repeat this session 3× per week.',
        templateIds: const [RoutineTemplateIds.fullBodyHypertrophy],
        first: RoutineTemplateIds.fullBodyHypertrophy,
      );
    }
    return _pack(
      title: 'Push / pull / legs',
      subtitle: 'Classic 3-day split for balanced muscle development.',
      templateIds: const [
        RoutineTemplateIds.pushDay,
        RoutineTemplateIds.pullDay,
        RoutineTemplateIds.legs,
      ],
      first: RoutineTemplateIds.pushDay,
    );
  }

  if (days == 4) {
    return _pack(
      title: 'Upper / lower (4-day)',
      subtitle: 'Two upper and two lower sessions — solid volume without living in the gym.',
      templateIds: const [
        RoutineTemplateIds.upperBodyA,
        RoutineTemplateIds.lowerBodyA,
        RoutineTemplateIds.upperBodyB,
        RoutineTemplateIds.lowerBodyB,
      ],
      first: RoutineTemplateIds.upperBodyA,
    );
  }

  // 5+ days per week
  if (goal == 'muscle_gain') {
    return _pack(
      title: 'Push / pull / legs + arms',
      subtitle: 'Four training days — rotate PPL and add an arm & core session.',
      templateIds: const [
        RoutineTemplateIds.pushDay,
        RoutineTemplateIds.pullDay,
        RoutineTemplateIds.legs,
        RoutineTemplateIds.armsAndCore,
      ],
      first: RoutineTemplateIds.pushDay,
    );
  }

  return _pack(
    title: 'Upper / lower + accessories',
    subtitle: 'Four-day split plus arms & core for extra weekly volume.',
    templateIds: const [
      RoutineTemplateIds.upperBodyA,
      RoutineTemplateIds.lowerBodyA,
      RoutineTemplateIds.upperBodyB,
      RoutineTemplateIds.lowerBodyB,
      RoutineTemplateIds.armsAndCore,
    ],
    first: RoutineTemplateIds.upperBodyA,
  );
}

List<RoutineTemplateSummary> resolveStarterTemplates(
  List<RoutineTemplateSummary> allTemplates,
  StarterPlanRecommendation plan,
) {
  final byId = {for (final t in allTemplates) t.id: t};
  final resolved = <RoutineTemplateSummary>[];
  for (final id in plan.templateIds) {
    final template = byId[id];
    if (template != null) resolved.add(template);
  }
  if (resolved.isNotEmpty) return resolved;

  final fallback = byId[RoutineTemplateIds.beginnerFullBody];
  if (fallback != null) return [fallback];
  if (allTemplates.isNotEmpty) return [allTemplates.first];
  return const [];
}

String starterPlanContextLine(Profile profile) {
  final goalLabel = _labelFor(ProfileOptions.goals, profile.goal, 'Training');
  final expLabel = _labelFor(ProfileOptions.experience, profile.experience, 'Beginner');
  final days = profile.trainingDaysPerWeek ?? 3;
  final daysLabel = days >= 5 ? '5+ days/week' : '$days days/week';
  return '$goalLabel · $expLabel · $daysLabel';
}

String _labelFor(List<(String, String)> options, String? value, String fallback) {
  if (value == null) return fallback;
  for (final option in options) {
    if (option.$1 == value) return option.$2;
  }
  return fallback;
}

bool _prefersHomeEquipment(String? injuryNotes) {
  if (injuryNotes == null || injuryNotes.trim().isEmpty) return false;
  final notes = injuryNotes.toLowerCase();
  const hints = [
    'home gym',
    'at home',
    'home workout',
    'dumbbell',
    'dumbbells',
    'no gym',
    'apartment',
    'minimal equipment',
    'bodyweight only',
  ];
  return hints.any(notes.contains);
}

StarterPlanRecommendation _pack({
  required String title,
  required String subtitle,
  required List<String> templateIds,
  required String first,
}) {
  return StarterPlanRecommendation(
    title: title,
    subtitle: subtitle,
    templateIds: templateIds,
    firstTemplateId: first,
  );
}

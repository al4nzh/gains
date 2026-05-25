import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:gains/features/auth/presentation/login_screen.dart';
import 'package:gains/features/auth/presentation/register_screen.dart';
import 'package:gains/features/auth/presentation/splash_screen.dart';
import 'package:gains/features/auth/presentation/welcome_screen.dart';
import 'package:gains/features/auth/session/auth_session.dart';
import 'package:gains/features/home/presentation/home_screen.dart';
import 'package:gains/features/profile/presentation/onboarding_screen.dart';
import 'package:gains/features/profile/presentation/profile_menu_screen.dart';
import 'package:gains/features/routines/presentation/generate_routines_screen.dart';
import 'package:gains/features/routines/presentation/routine_detail_screen.dart';
import 'package:gains/features/routines/presentation/routines_list_screen.dart';
import 'package:gains/features/routines/presentation/template_detail_screen.dart';
import 'package:gains/features/routines/presentation/templates_list_screen.dart';
import 'package:gains/features/shell/presentation/app_shell.dart';
import 'package:gains/features/ai/presentation/coach_screen.dart';
import 'package:gains/features/analytics/presentation/exercise_detail_screen.dart';
import 'package:gains/features/analytics/presentation/progress_list_screen.dart';
import 'package:gains/features/workouts/models/finish_stats.dart';
import 'package:gains/features/workouts/presentation/active_workout_screen.dart';
import 'package:gains/features/workouts/presentation/start_workout_screen.dart';
import 'package:gains/features/workouts/presentation/train_screen.dart';
import 'package:gains/features/workouts/presentation/workout_summary_screen.dart';

class AppRouter {
  AppRouter(this._session) {
    router = GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/',
      refreshListenable: _session,
      redirect: _redirect,
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
        GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
        GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
        GoRoute(path: '/register', builder: (_, _) => const RegisterScreen()),
        GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
        GoRoute(
          path: '/profile',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, _) => const ProfileMenuScreen(),
        ),
        GoRoute(
          path: '/routine-templates',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, _) => const TemplatesListScreen(),
        ),
        GoRoute(
          path: '/routine-templates/:id',
          parentNavigatorKey: _rootNavigatorKey,
          builder: (_, state) => TemplateDetailScreen(
            templateId: state.pathParameters['id']!,
          ),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return AppShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/train',
                  builder: (_, _) => const TrainScreen(),
                  routes: [
                    GoRoute(
                      path: 'start',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (_, state) => StartWorkoutScreen(
                        routineId: state.uri.queryParameters['routineId'],
                      ),
                    ),
                    GoRoute(
                      path: 'workout/:id',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (_, state) => ActiveWorkoutScreen(
                        workoutId: state.pathParameters['id']!,
                      ),
                      routes: [
                        GoRoute(
                          path: 'summary',
                          parentNavigatorKey: _rootNavigatorKey,
                          builder: (_, state) => WorkoutSummaryScreen(
                            workoutId: state.pathParameters['id']!,
                            initialStats: state.extra as FinishStats?,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/routines',
                  builder: (_, _) => const RoutinesListScreen(),
                  routes: [
                    GoRoute(
                      path: 'generate',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (_, _) => const GenerateRoutinesScreen(),
                    ),
                    GoRoute(
                      path: ':id',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (_, state) => RoutineDetailScreen(
                        routineId: state.pathParameters['id']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/progress',
                  builder: (_, _) => const ProgressListScreen(),
                  routes: [
                    GoRoute(
                      path: ':exerciseId',
                      parentNavigatorKey: _rootNavigatorKey,
                      builder: (_, state) => ExerciseDetailScreen(
                        exerciseId: state.pathParameters['exerciseId']!,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/coach',
                  builder: (_, _) => const CoachScreen(),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  final AuthSession _session;
  late final GoRouter router;

  String? _redirect(BuildContext context, GoRouterState state) {
    final loc = state.uri.path;
    final loading = _session.isLoading;
    final authed = _session.isAuthenticated;
    final onboarding = _session.needsOnboarding;

    if (loading) {
      return loc == '/' ? null : '/';
    }

    const publicRoutes = {'/welcome', '/login', '/register'};

    if (!authed) {
      if (publicRoutes.contains(loc)) return null;
      return '/welcome';
    }

    if (onboarding) {
      if (loc == '/onboarding') return null;
      return '/onboarding';
    }

    if (publicRoutes.contains(loc) || loc == '/' || loc == '/onboarding') {
      return '/home';
    }

    return null;
  }
}

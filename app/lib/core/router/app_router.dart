import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/pages/splash_page.dart';
import '../../features/auth/pages/onboarding_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/auth/pages/real_name_page.dart';
import '../../features/task/pages/home_page.dart';
import '../../features/task/pages/task_square_page.dart';
import '../../features/task/pages/task_detail_page.dart';
import '../../features/collection/pages/my_tasks_page.dart';
import '../../features/collection/pages/collection_workbench_page.dart';
import '../../features/collection/pages/text_collection_page.dart';
import '../../features/task/pages/task_create_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/profile/pages/settings_page.dart';
import '../../features/profile/pages/about_page.dart';
import '../../features/profile/pages/account_security_page.dart';
import '../../features/team/pages/team_list_page.dart';
import '../../features/team/pages/team_detail_page.dart';
import '../../features/task/pages/admin_approval_page.dart';
import '../../features/collection/pages/submission_detail_page.dart';
import '../../features/collection/pages/text_carousel_page.dart';
import '../../shared/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Android-native slide-up page transition
Page _slidePage(Widget child, GoRouterState state) {
  return CustomTransitionPage(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.08),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', pageBuilder: (context, state) => _slidePage(const SplashPage(), state)),
      GoRoute(path: '/onboarding', builder: (context, state) => const OnboardingPage()),
      GoRoute(path: '/login', pageBuilder: (context, state) => _slidePage(const LoginPage(), state)),
      GoRoute(path: '/register', pageBuilder: (context, state) => _slidePage(const RegisterPage(), state)),
      GoRoute(path: '/real-name', pageBuilder: (context, state) => _slidePage(const RealNamePage(), state)),
      ShellRoute(
        builder: (context, state, child) {
          final path = state.uri.path;
          final index = path.startsWith('/tasks') ? 1 : path.startsWith('/teams') ? 2 : path.startsWith('/profile') ? 3 : 0;
          return MainShell(currentIndex: index, child: child);
        },
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const HomePage()),
          GoRoute(path: '/tasks', builder: (context, state) => const TaskSquarePage()),
          GoRoute(path: '/teams', builder: (context, state) => const TeamListPage()),
          GoRoute(path: '/profile', builder: (context, state) => const ProfilePage()),
        ],
      ),
      GoRoute(path: '/tasks/:id', pageBuilder: (context, state) => _slidePage(TaskDetailPage(taskId: state.pathParameters['id']!), state)),
      GoRoute(path: '/tasks/create', pageBuilder: (context, state) => _slidePage(TaskCreatePage(teamId: state.uri.queryParameters['teamId']), state)),
      GoRoute(path: '/my-tasks', pageBuilder: (context, state) => _slidePage(const MyTasksPage(), state)),
      GoRoute(path: '/teams/:id', pageBuilder: (context, state) => _slidePage(TeamDetailPage(teamId: state.pathParameters['id']!), state)),
      GoRoute(path: '/collection/:claimId', pageBuilder: (context, state) => _slidePage(CollectionWorkbenchPage(claimId: state.pathParameters['claimId']!), state)),
      GoRoute(path: '/text-collection/:taskId', pageBuilder: (context, state) => _slidePage(TextCollectionPage(taskId: state.pathParameters['taskId']!), state)),
      GoRoute(path: '/settings', pageBuilder: (context, state) => _slidePage(const SettingsPage(), state)),
      GoRoute(path: '/about', pageBuilder: (context, state) => _slidePage(const AboutPage(), state)),
      GoRoute(path: '/account-security', pageBuilder: (context, state) => _slidePage(const AccountSecurityPage(), state)),
      GoRoute(path: '/admin/approvals', pageBuilder: (context, state) => _slidePage(const AdminApprovalPage(), state)),
      GoRoute(path: '/submission/:id', pageBuilder: (context, state) => _slidePage(SubmissionDetailPage(submissionId: state.pathParameters['id']!), state)),
      GoRoute(path: '/text-carousel/:claimId', pageBuilder: (context, state) => _slidePage(TextCarouselPage(claimId: state.pathParameters['claimId']!), state)),
    ],
  );
});

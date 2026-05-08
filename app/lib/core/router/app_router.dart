import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/pages/splash_page.dart';
import '../../features/auth/pages/login_page.dart';
import '../../features/auth/pages/register_page.dart';
import '../../features/auth/pages/real_name_page.dart';
import '../../features/task/pages/home_page.dart';
import '../../features/task/pages/task_square_page.dart';
import '../../features/task/pages/task_detail_page.dart';
import '../../features/collection/pages/my_tasks_page.dart';
import '../../features/collection/pages/collection_workbench_page.dart';
import '../../features/collection/pages/text_collection_page.dart';
import '../../features/profile/pages/profile_page.dart';
import '../../features/profile/pages/api_settings_page.dart';
import '../../features/profile/pages/data_export_page.dart';
import '../../features/team/pages/team_list_page.dart';
import '../../shared/widgets/main_shell.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/real-name',
        builder: (context, state) => const RealNamePage(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          final path = state.uri.path;
          final index = path.startsWith('/tasks') ? 1 : path.startsWith('/teams') ? 2 : path.startsWith('/profile') ? 3 : 0;
          return MainShell(currentIndex: index, child: child);
        },
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/tasks',
            builder: (context, state) => const TaskSquarePage(),
          ),
          GoRoute(
            path: '/teams',
            builder: (context, state) => const TeamListPage(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
      GoRoute(
        path: '/tasks/:id',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TaskDetailPage(
          taskId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '/my-tasks',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const MyTasksPage(),
      ),
      GoRoute(
        path: '/collection/:claimId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => CollectionWorkbenchPage(
          claimId: state.pathParameters['claimId']!,
        ),
      ),
      GoRoute(
        path: '/api-settings',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const ApiSettingsPage(),
      ),
      GoRoute(
        path: '/data-export',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const DataExportPage(),
      ),
      GoRoute(
        path: '/text-collection/:taskId',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TextCollectionPage(
          taskId: state.pathParameters['taskId']!,
        ),
      ),
    ],
  );
});


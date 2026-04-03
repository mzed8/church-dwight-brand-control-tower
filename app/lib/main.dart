import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:go_router/go_router.dart';
import 'theme/brand_theme.dart';
import 'providers/theme_provider.dart';
import 'screens/portfolio_screen.dart';
import 'screens/brand_detail_screen.dart';
import 'screens/scenario_planner_screen.dart';
import 'screens/chat_drawer.dart';

void main() {
  runApp(const ProviderScope(child: BrandCommandCenter()));
}

class BrandCommandCenter extends ConsumerWidget {
  const BrandCommandCenter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = ref.watch(isDarkModeProvider);

    return ShadApp.router(
      title: 'Brand Control Tower',
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      theme: BrandTheme.light(),
      darkTheme: BrandTheme.dark(),
      routerConfig: _router,
    );
  }
}

final _router = GoRouter(
  initialLocation: '/',
  routes: [
    ShellRoute(
      builder: (context, state, child) {
        return Stack(
          children: [
            child,
            const ChatDrawer(),
          ],
        );
      },
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const PortfolioScreen(),
        ),
        GoRoute(
          path: '/brand/:id',
          builder: (context, state) {
            final brandId = state.pathParameters['id']!;
            return BrandDetailScreen(brandId: brandId);
          },
        ),
        GoRoute(
          path: '/brand/:id/scenario',
          builder: (context, state) {
            final brandId = state.pathParameters['id']!;
            return ScenarioPlannerScreen(brandId: brandId);
          },
        ),
      ],
    ),
  ],
);

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme.dart';
import 'core/auth_service.dart';
import 'features/game/game_screen.dart';
import 'features/shop/shop_screen.dart';
import 'features/deposit/deposit_screen.dart';
import 'features/tournament/tournament_screen.dart';
import 'features/leaderboard/leaderboard_screen.dart';
import 'features/vip/vip_screen.dart';
import 'features/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://hpfuoqejinckybhsqkub.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhwZnVvcWVqaW5ja3liaHNxa3ViIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ5MTk0MTcsImV4cCI6MjA5MDQ5NTQxN30.vR2JpOxxil0ciL2-Zz1rG5IdRR5GPOUzidC8CQdKEBY',
  );

  runApp(
    ChangeNotifierProvider(create: (_) => AuthService(), child: const MyApp()),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STACK USDT',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: const AppRouter(),
    );
  }
}

class AppRouter extends StatelessWidget {
  const AppRouter({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (authService.isAuthenticated) {
          return const MainNavigation();
        }
        return const LoginScreen();
      },
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() => _selectedIndex = index);
            },
            backgroundColor: AppColors.backgroundSecondary,
            indicatorColor: AppColors.cyan.withValues(alpha: 0.2),
            labelType: NavigationRailLabelType.all,
            destinations: const [
              NavigationRailDestination(
                icon: Icon(
                  Icons.games_outlined,
                  color: AppColors.textSecondary,
                ),
                selectedIcon: Icon(Icons.games, color: AppColors.cyan),
                label: Text(
                  'GAME',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(
                  Icons.emoji_events_outlined,
                  color: AppColors.textSecondary,
                ),
                selectedIcon: Icon(Icons.emoji_events, color: AppColors.amber),
                label: Text(
                  'TOURNAMENTS',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(
                  Icons.leaderboard_outlined,
                  color: AppColors.textSecondary,
                ),
                selectedIcon: Icon(
                  Icons.leaderboard,
                  color: AppColors.neonGreen,
                ),
                label: Text(
                  'LEADERBOARD',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.textSecondary,
                ),
                selectedIcon: Icon(
                  Icons.account_balance_wallet,
                  color: AppColors.neonGreen,
                ),
                label: Text(
                  'DEPOSIT',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(
                  Icons.shopping_bag_outlined,
                  color: AppColors.textSecondary,
                ),
                selectedIcon: Icon(Icons.shopping_bag, color: AppColors.amber),
                label: Text(
                  'SHOP',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              NavigationRailDestination(
                icon: Icon(
                  Icons.workspace_premium_outlined,
                  color: AppColors.textSecondary,
                ),
                selectedIcon: Icon(
                  Icons.workspace_premium,
                  color: AppColors.cyan,
                ),
                label: Text(
                  'VIP',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            ],
            leading: Consumer<AuthService>(
              builder: (context, authService, _) {
                return Column(
                  children: [
                    const SizedBox(height: 16),
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.cyan.withValues(alpha: 0.2),
                      child: Text(
                        (authService.userProfile?['username'] ?? 'U')
                            .substring(0, 1)
                            .toUpperCase(),
                        style: GoogleFonts.rajdhani(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cyan,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '\$${authService.balance.toStringAsFixed(2)}',
                      style: GoogleFonts.orbitron(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.amber,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
            trailing: Consumer<AuthService>(
              builder: (context, authService, _) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: IconButton(
                    icon: const Icon(Icons.logout, color: AppColors.neonRed),
                    onPressed: () => authService.logout(),
                    tooltip: 'Logout',
                  ),
                );
              },
            ),
          ),
          const VerticalDivider(
            thickness: 1,
            width: 1,
            color: AppColors.backgroundTertiary,
          ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: const [
                GameScreen(),
                TournamentScreen(),
                LeaderboardScreen(),
                DepositScreen(),
                ShopScreen(),
                VipScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

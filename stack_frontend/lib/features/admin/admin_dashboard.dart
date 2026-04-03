import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _isLoading = true;
  List<dynamic> _users = [];
  List<dynamic> _leaderboard = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final leaderboardRes = await apiService.get('/game/leaderboard');
      final usersRes = await apiService.get('/user/all');

      if (leaderboardRes['success'] == true) {
        _leaderboard = leaderboardRes['leaderboard'] ?? [];
      }
      if (usersRes['success'] == true) {
        _users = usersRes['users'] ?? [];
      }
    } catch (e) {
      _error = 'Failed to load data: $e';
    }

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 1200;
          if (isWide) {
            return _buildWideLayout();
          } else {
            return _buildCompactLayout();
          }
        },
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _MainContent(
            isLoading: _isLoading,
            error: _error,
            users: _users,
            leaderboard: _leaderboard,
            onRefresh: _loadData,
          ),
        ),
        Container(
          width: 320,
          color: AppColors.backgroundSecondary,
          child: _SystemOverridesPanel(),
        ),
      ],
    );
  }

  Widget _buildCompactLayout() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _MainContent(
                    isLoading: _isLoading,
                    error: _error,
                    users: _users,
                    leaderboard: _leaderboard,
                    onRefresh: _loadData,
                    boundedHeight: false,
                  ),
                  const SizedBox(height: 24),
                  _SystemOverridesPanel(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MainContent extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final List<dynamic> users;
  final List<dynamic> leaderboard;
  final VoidCallback onRefresh;
  final bool boundedHeight;

  const _MainContent({
    required this.isLoading,
    required this.error,
    required this.users,
    required this.leaderboard,
    required this.onRefresh,
    this.boundedHeight = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 32),
          _buildMetricsCards(),
          const SizedBox(height: 32),
          boundedHeight
              ? Expanded(child: _buildUsersTable())
              : _buildUsersTable(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.cyan.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
          ),
          child: const Icon(
            Icons.admin_panel_settings,
            color: AppColors.cyan,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ADMIN CONTROL CENTER',
              style: GoogleFonts.orbitron(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'House Edge Management System',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          icon: const Icon(Icons.refresh, color: AppColors.cyan),
          onPressed: onRefresh,
          tooltip: 'Refresh',
        ),
        _buildStatusIndicator(),
      ],
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.neonGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.neonGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: AppColors.neonGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.neonGreen,
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'SYSTEM ONLINE',
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.neonGreen,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsCards() {
    final totalLiquidity = users.fold<double>(
      0,
      (sum, u) => sum + double.tryParse(u['usdt_balance']?.toString() ?? '0')!,
    );
    final activePlayers = users.where((u) => !(u['is_banned'] ?? false)).length;

    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            title: 'TOTAL LIQUIDITY',
            value: '\$${totalLiquidity.toStringAsFixed(2)}',
            icon: Icons.account_balance,
            color: AppColors.cyan,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            title: 'HOUSE PROFIT (20%)',
            value: '\$${(totalLiquidity * 0.2).toStringAsFixed(2)}',
            icon: Icons.trending_up,
            color: AppColors.amber,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _MetricCard(
            title: 'REGISTERED PLAYERS',
            value: users.length.toString(),
            icon: Icons.people,
            color: AppColors.neonGreen,
            subtitle: '$activePlayers active',
          ),
        ),
      ],
    );
  }

  Widget _buildUsersTable() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Text(error!, style: GoogleFonts.inter(color: AppColors.neonRed)),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.backgroundTertiary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Text(
                  'PLAYER DATABASE',
                  style: GoogleFonts.rajdhani(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    letterSpacing: 1,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundTertiary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${users.length} users',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.backgroundTertiary),
          if (users.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text(
                  'No users found. Players will appear here once they register.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(
                    AppColors.backgroundTertiary.withValues(alpha: 0.3),
                  ),
                  columns: [
                    DataColumn(
                      label: Text(
                        'USERNAME',
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'EMAIL',
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'BALANCE',
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                      numeric: true,
                    ),
                    DataColumn(
                      label: Text(
                        'STATUS',
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                  rows: users.map((user) {
                    final isBanned = user['is_banned'] ?? false;
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            user['username'] ?? 'Unknown',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            user['email'] ?? '',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            '\$${double.tryParse(user['usdt_balance']?.toString() ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                            style: GoogleFonts.orbitron(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.amber,
                            ),
                          ),
                        ),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isBanned
                                  ? AppColors.neonRed.withValues(alpha: 0.1)
                                  : AppColors.neonGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isBanned ? 'BANNED' : 'ACTIVE',
                              style: GoogleFonts.rajdhani(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isBanned
                                    ? AppColors.neonRed
                                    : AppColors.neonGreen,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? subtitle;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 20,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              if (subtitle != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.neonGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    subtitle!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: AppColors.neonGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _SystemOverridesPanel extends StatelessWidget {
  const _SystemOverridesPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.neonRed.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: AppColors.neonRed,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'SYSTEM OVERRIDES',
                style: GoogleFonts.rajdhani(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Admin controls - Use with caution',
            style: GoogleFonts.inter(fontSize: 12, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CONFIGURATION',
                  style: GoogleFonts.rajdhani(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cyan,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                _configRow('House Edge', '20%'),
                _configRow('Min Withdrawal', '\$10.00'),
                _configRow('Max Withdrawal', '\$10,000.00'),
                _configRow('Withdrawal Fee', '\$1.00'),
              ],
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.backgroundTertiary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: AppColors.textSecondary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'All override actions are logged with timestamp and admin ID',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _configRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            key,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.orbitron(fontSize: 12, color: AppColors.amber),
          ),
        ],
      ),
    );
  }
}

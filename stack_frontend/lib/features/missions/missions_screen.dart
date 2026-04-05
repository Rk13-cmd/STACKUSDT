import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../core/auth_service.dart';

class MissionsScreen extends StatefulWidget {
  const MissionsScreen({super.key});

  @override
  State<MissionsScreen> createState() => _MissionsScreenState();
}

class _MissionsScreenState extends State<MissionsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, List<dynamic>> _missionsByPeriod = {};
  bool _loading = true;
  String _selectedPeriod = 'daily';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {
          _selectedPeriod = [
            'daily',
            'weekly',
            'monthly',
          ][_tabController.index];
        });
        _loadMissions();
      }
    });
    _loadMissions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadMissions() async {
    try {
      final res = await apiService.get(
        '/features/missions/my?period=$_selectedPeriod',
      );
      if (res['success'] == true && mounted) {
        setState(() {
          _missionsByPeriod[_selectedPeriod] = res['progress'] ?? [];
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _claimReward(String missionId) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final res = await apiService.post('/features/missions/$missionId/claim', {
      'user_id': authService.userId,
    });
    if (res['success'] == true) {
      await authService.refreshProfile();
      _loadMissions();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Reward claimed! +\$${res['reward']?['reward_usdt'] ?? 0} USDT',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.neonGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['error'] ?? 'Failed to claim reward',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.neonRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundSecondary,
        elevation: 0,
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: AppColors.amber,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.amber.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'MISSIONS',
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.amber,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.amber,
          labelColor: AppColors.amber,
          unselectedLabelColor: AppColors.textMuted,
          labelStyle: GoogleFonts.rajdhani(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
          tabs: const [
            Tab(text: 'DAILY'),
            Tab(text: 'WEEKLY'),
            Tab(text: 'MONTHLY'),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            )
          : TabBarView(
              controller: _tabController,
              children: ['daily', 'weekly', 'monthly'].map((period) {
                final missions = _missionsByPeriod[period] ?? [];
                if (missions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.flag_outlined,
                          size: 64,
                          color: AppColors.textMuted.withOpacity(0.3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No missions available',
                          style: GoogleFonts.inter(
                            color: AppColors.textMuted,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: missions.length,
                  itemBuilder: (ctx, i) {
                    final m = missions[i];
                    final progress = m['progress'] ?? 0;
                    final requirement = m['requirement_value'] ?? 1;
                    final isCompleted = m['is_completed'] ?? false;
                    final isClaimed = m['is_claimed'] ?? false;
                    final pct = requirement > 0 ? progress / requirement : 0.0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isCompleted && !isClaimed
                              ? AppColors.neonGreen.withOpacity(0.4)
                              : isClaimed
                              ? AppColors.cyan.withOpacity(0.2)
                              : AppColors.backgroundTertiary,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                isClaimed
                                    ? Icons.check_circle
                                    : isCompleted
                                    ? Icons.star
                                    : Icons.flag_outlined,
                                size: 20,
                                color: isClaimed
                                    ? AppColors.cyan
                                    : isCompleted
                                    ? AppColors.neonGreen
                                    : AppColors.amber,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  m['name'] ?? '',
                                  style: GoogleFonts.rajdhani(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              Text(
                                '\$${double.tryParse(m['reward_usdt']?.toString() ?? '0')?.toStringAsFixed(2)}',
                                style: GoogleFonts.orbitron(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.neonGreen,
                                ),
                              ),
                            ],
                          ),
                          if (m['description'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              m['description'],
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: pct.clamp(0.0, 1.0),
                                    backgroundColor:
                                        AppColors.backgroundTertiary,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isCompleted
                                          ? AppColors.neonGreen
                                          : AppColors.amber.withOpacity(0.7),
                                    ),
                                    minHeight: 6,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$progress/$requirement',
                                style: GoogleFonts.robotoMono(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          if (m['reward_xp'] != null && m['reward_xp'] > 0) ...[
                            const SizedBox(height: 4),
                            Text(
                              '+${m['reward_xp']} XP',
                              style: GoogleFonts.rajdhani(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.amber,
                              ),
                            ),
                          ],
                          if (isCompleted && !isClaimed) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: () => _claimReward(m['id']),
                                icon: const Icon(Icons.card_giftcard, size: 16),
                                label: Text(
                                  'CLAIM REWARD',
                                  style: GoogleFonts.rajdhani(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 2,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.neonGreen,
                                  foregroundColor: AppColors.backgroundPrimary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                ),
                              ),
                            ),
                          ] else if (isClaimed) ...[
                            const SizedBox(height: 6),
                            Center(
                              child: Text(
                                'CLAIMED',
                                style: GoogleFonts.rajdhani(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.cyan,
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              }).toList(),
            ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<dynamic> _leaderboard = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
  }

  Future<void> _loadLeaderboard() async {
    final res = await apiService.get('/tournament/leaderboard');
    if (res['success'] == true && mounted) {
      setState(() {
        _leaderboard = res['leaderboard'] ?? [];
        _loading = false;
      });
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
                boxShadow: [BoxShadow(color: AppColors.amber.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)],
              ),
            ),
            const SizedBox(width: 12),
            Text('LEADERBOARD', style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.amber, letterSpacing: 3)),
          ],
        ),
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: AppColors.cyan), onPressed: _loadLeaderboard),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.amber))
          : _leaderboard.isEmpty
              ? Center(child: Text('No leaderboard data yet', style: GoogleFonts.inter(color: AppColors.textMuted)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _leaderboard.length,
                  itemBuilder: (ctx, i) {
                    final entry = _leaderboard[i];
                    final isBot = entry['is_bot'] ?? false;
                    final rank = i + 1;
                    final rankColor = rank == 1 ? AppColors.amber : rank == 2 ? AppColors.textSecondary : rank == 3 ? const Color(0xFFCD7F32) : AppColors.textMuted;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: rank <= 3 ? rankColor.withValues(alpha: 0.3) : AppColors.backgroundTertiary,
                          width: rank <= 3 ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: rankColor.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: rankColor.withValues(alpha: 0.4)),
                            ),
                            child: Center(
                              child: Text(
                                '#$rank',
                                style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: rankColor),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      entry['display_name'] ?? 'Unknown',
                                      style: GoogleFonts.rajdhani(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                    if (isBot) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(color: AppColors.cyan.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
                                        child: Text('BOT', style: GoogleFonts.rajdhani(fontSize: 8, fontWeight: FontWeight.bold, color: AppColors.cyan, letterSpacing: 1)),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  'MMR: ${entry['mmr'] ?? 0} | Win Rate: ${entry['win_rate']?.toStringAsFixed(1) ?? 0}%',
                                  style: GoogleFonts.inter(fontSize: 10, color: AppColors.textMuted),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${double.tryParse(entry['total_won']?.toString() ?? '0')?.toStringAsFixed(2)}',
                            style: GoogleFonts.orbitron(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.amber),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

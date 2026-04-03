import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/auth_service.dart';
import '../../core/api_service.dart';
import 'tournament_game_screen.dart';

class TournamentScreen extends StatefulWidget {
  const TournamentScreen({super.key});

  @override
  State<TournamentScreen> createState() => _TournamentScreenState();
}

class _TournamentScreenState extends State<TournamentScreen> {
  List<dynamic> _tournaments = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTournaments();
  }

  Future<void> _loadTournaments() async {
    final res = await apiService.get('/tournament/list');
    if (res['success'] == true && mounted) {
      setState(() {
        _tournaments = res['tournaments'] ?? [];
        _loading = false;
      });
    }
  }

  Future<void> _joinTournament(Map<String, dynamic> tournament) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.userId == null) return;

    final res = await apiService.post('/tournament/join', {
      'user_id': authService.userId,
      'tournament_id': tournament['id'],
    });

    if (!mounted) return;

    if (res['success'] == true) {
      _loadTournaments();
      final entryFee =
          double.tryParse(tournament['entry_fee']?.toString() ?? '0') ?? 0;
      final maxPlayers = tournament['max_players'] ?? 2;
      final type = tournament['type'] ?? 'quick_duel';

      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TournamentGameScreen(
            tournamentId: tournament['id'],
            tournamentType: type,
            entryFee: entryFee,
            maxPlayers: maxPlayers,
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['error'] ?? 'Failed to join',
            style: GoogleFonts.inter(color: AppColors.neonRed),
          ),
          backgroundColor: AppColors.backgroundSecondary,
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
                    color: AppColors.amber.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'TOURNAMENTS',
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.amber,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.cyan),
            onPressed: _loadTournaments,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            )
          : _tournaments.isEmpty
          ? Center(
              child: Text(
                'No active tournaments',
                style: GoogleFonts.inter(color: AppColors.textMuted),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _tournaments.length,
              itemBuilder: (ctx, i) {
                final t = _tournaments[i];
                final typeLabels = {
                  'quick_duel': {
                    'label': 'QUICK DUEL',
                    'color': AppColors.cyan,
                    'icon': Icons.flash_on,
                  },
                  'standard': {
                    'label': 'STANDARD',
                    'color': AppColors.neonGreen,
                    'icon': Icons.emoji_events,
                  },
                  'premium': {
                    'label': 'PREMIUM',
                    'color': AppColors.amber,
                    'icon': Icons.diamond,
                  },
                  'elite': {
                    'label': 'ELITE',
                    'color': AppColors.neonRed,
                    'icon': Icons.workspace_premium,
                  },
                  'freeroll': {
                    'label': 'FREEROLL',
                    'color': AppColors.textSecondary,
                    'icon': Icons.card_giftcard,
                  },
                };
                final typeInfo =
                    typeLabels[t['type']] ?? typeLabels['standard']!;
                final entryFee =
                    double.tryParse(t['entry_fee']?.toString() ?? '0') ?? 0;
                final rake = double.tryParse(t['rake']?.toString() ?? '0') ?? 0;
                final maxPlayers = t['max_players'] ?? 0;
                final currentPlayers = t['current_players'] ?? 0;
                final prizePool =
                    double.tryParse(t['prize_pool']?.toString() ?? '0') ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: (typeInfo['color'] as Color).withValues(
                        alpha: 0.2,
                      ),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            typeInfo['icon'] as IconData,
                            color: typeInfo['color'] as Color,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            typeInfo['label'] as String,
                            style: GoogleFonts.rajdhani(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: typeInfo['color'] as Color,
                              letterSpacing: 2,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: (typeInfo['color'] as Color).withValues(
                                alpha: 0.1,
                              ),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$currentPlayers/$maxPlayers',
                              style: GoogleFonts.rajdhani(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: typeInfo['color'] as Color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _infoChip(
                            'Entry',
                            '\$${entryFee.toStringAsFixed(2)}',
                            AppColors.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          _infoChip(
                            'Rake',
                            '${rake.toStringAsFixed(0)}%',
                            AppColors.amber,
                          ),
                          if (prizePool > 0) ...[
                            const SizedBox(width: 8),
                            _infoChip(
                              'Pool',
                              '\$${prizePool.toStringAsFixed(2)}',
                              AppColors.neonGreen,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: ElevatedButton(
                          onPressed: currentPlayers >= maxPlayers
                              ? null
                              : () => _joinTournament(t),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: currentPlayers >= maxPlayers
                                ? AppColors.backgroundTertiary
                                : typeInfo['color'] as Color,
                            foregroundColor: currentPlayers >= maxPlayers
                                ? AppColors.textMuted
                                : AppColors.backgroundPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            currentPlayers >= maxPlayers
                                ? 'FULL'
                                : 'JOIN TOURNAMENT',
                            style: GoogleFonts.rajdhani(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _infoChip(String label, String value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: GoogleFonts.inter(fontSize: 11, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: GoogleFonts.rajdhani(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../core/auth_service.dart';

class ReferralsScreen extends StatefulWidget {
  const ReferralsScreen({super.key});

  @override
  State<ReferralsScreen> createState() => _ReferralsScreenState();
}

class _ReferralsScreenState extends State<ReferralsScreen> {
  Map<String, dynamic> _info = {};
  List<dynamic> _leaderboard = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final res = await apiService.get(
        '/features/referrals/info?user_id=${authService.userId}',
      );
      if (res['success'] == true && mounted) {
        setState(() {
          _info = res['info'] ?? {};
          _loading = false;
        });
      }
      final lbRes = await apiService.get('/features/referrals/leaderboard');
      if (lbRes['success'] == true && mounted) {
        setState(() => _leaderboard = lbRes['leaderboard'] ?? []);
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _copyReferralCode() {
    final code = _info['referral_code'] ?? '';
    if (code.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: code));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Referral code copied!', style: GoogleFonts.inter()),
          backgroundColor: AppColors.neonGreen,
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
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: AppColors.amber),
      );

    final code = _info['referral_code'] ?? '---';
    final directRefs = _info['direct_referrals'] ?? 0;
    final totalRefs = _info['total_referrals'] ?? 0;
    final totalEarned =
        double.tryParse(_info['total_earned']?.toString() ?? '0') ?? 0;
    final pendingEarned =
        double.tryParse(_info['pending_earned']?.toString() ?? '0') ?? 0;
    final l1Pct =
        double.tryParse(_info['level1_percent']?.toString() ?? '0') ?? 0;
    final l2Pct =
        double.tryParse(_info['level2_percent']?.toString() ?? '0') ?? 0;

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
              'REFERRALS',
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.amber,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.amber.withOpacity(0.15),
                    AppColors.backgroundSecondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.amber.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'YOUR REFERRAL CODE',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        code,
                        style: GoogleFonts.orbitron(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: AppColors.amber,
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _copyReferralCode,
                        icon: const Icon(Icons.copy, color: AppColors.amber),
                        tooltip: 'Copy',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Share this code to earn $l1Pct% on deposits',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    '+$l2Pct% on Level 2 referrals',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                _statCard('DIRECT', '$directRefs', AppColors.cyan),
                _statCard('TOTAL', '$totalRefs', AppColors.amber),
                _statCard(
                  'EARNED',
                  '\$${totalEarned.toStringAsFixed(2)}',
                  AppColors.neonGreen,
                ),
              ],
            ),
            if (pendingEarned > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.pending, size: 16, color: AppColors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Pending: \$${pendingEarned.toStringAsFixed(2)}',
                      style: GoogleFonts.rajdhani(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Text(
              'LEADERBOARD',
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.amber,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            if (_leaderboard.isEmpty)
              Center(
                child: Text(
                  'No referrals yet',
                  style: GoogleFonts.inter(color: AppColors.textMuted),
                ),
              )
            else
              ..._leaderboard.take(15).map((entry) {
                final rank = _leaderboard.indexOf(entry) + 1;
                final refs = entry['total_referrals'] ?? 0;
                final earned =
                    double.tryParse(entry['total_earned']?.toString() ?? '0') ??
                    0;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.backgroundTertiary),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: rank <= 3
                              ? AppColors.amber.withOpacity(0.2)
                              : AppColors.backgroundTertiary,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            '#$rank',
                            style: GoogleFonts.rajdhani(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: rank <= 3
                                  ? AppColors.amber
                                  : AppColors.textMuted,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          entry['username'] ?? 'Unknown',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '$refs refs',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '\$${earned.toStringAsFixed(2)}',
                        style: GoogleFonts.robotoMono(
                          fontSize: 12,
                          color: AppColors.neonGreen,
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.rajdhani(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

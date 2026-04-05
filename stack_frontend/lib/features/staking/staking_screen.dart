import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../core/auth_service.dart';

class StakingScreen extends StatefulWidget {
  const StakingScreen({super.key});

  @override
  State<StakingScreen> createState() => _StakingScreenState();
}

class _StakingScreenState extends State<StakingScreen> {
  Map<String, dynamic> _stakingInfo = {};
  bool _loading = true;
  final _stakeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _stakeController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final res = await apiService.get(
        '/features/staking/info?user_id=${authService.userId}',
      );
      if (res['success'] == true && mounted) {
        setState(() => _stakingInfo = res['info'] ?? {});
      }
      final gRes = await apiService.get('/features/staking/global-stats');
      if (gRes['success'] == true && mounted) {
        setState(() {});
      }
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _stake() async {
    final amount = double.tryParse(_stakeController.text);
    if (amount == null || amount < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Minimum stake is \$10 USDT',
            style: GoogleFonts.inter(),
          ),
          backgroundColor: AppColors.neonRed,
        ),
      );
      return;
    }
    final authService = Provider.of<AuthService>(context, listen: false);
    final res = await apiService.post('/features/staking/stake', {
      'user_id': authService.userId,
      'amount': amount,
    });
    if (res['success'] == true) {
      await authService.refreshProfile();
      _stakeController.clear();
      _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            res['message'] ?? 'Staked successfully!',
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
          content: Text(res['error'] ?? 'Failed', style: GoogleFonts.inter()),
          backgroundColor: AppColors.neonRed,
        ),
      );
    }
  }

  Future<void> _unstake() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final res = await apiService.post('/features/staking/unstake', {
      'user_id': authService.userId,
    });
    if (res['success'] == true) {
      await authService.refreshProfile();
      _loadData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unstaked! Returned: \$${res['total_returned']?.toStringAsFixed(2) ?? '0'}',
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
          content: Text(res['error'] ?? 'Failed', style: GoogleFonts.inter()),
          backgroundColor: AppColors.neonRed,
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

    final hasStake = _stakingInfo['has_active_stake'] ?? false;
    final amount =
        double.tryParse(_stakingInfo['amount']?.toString() ?? '0') ?? 0;
    final annualRate =
        double.tryParse(_stakingInfo['annual_rate']?.toString() ?? '0') ?? 0;
    final totalEarned =
        double.tryParse(_stakingInfo['total_earned']?.toString() ?? '0') ?? 0;
    final dailyReward =
        double.tryParse(_stakingInfo['daily_reward']?.toString() ?? '0') ?? 0;
    final monthlyReward =
        double.tryParse(_stakingInfo['monthly_reward']?.toString() ?? '0') ?? 0;
    final canUnstake = _stakingInfo['can_unstake'] ?? true;
    final minStake =
        double.tryParse(_stakingInfo['min_stake']?.toString() ?? '10') ?? 10;
    final authService = Provider.of<AuthService>(context, listen: false);

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
              'STAKING',
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.amber,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        actions: [
          Consumer<AuthService>(
            builder: (ctx, auth, _) => Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                '\$${auth.balance.toStringAsFixed(2)}',
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neonGreen,
                ),
              ),
            ),
          ),
        ],
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
                    AppColors.neonGreen.withOpacity(0.1),
                    AppColors.backgroundSecondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.neonGreen.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    'ANNUAL RATE',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${annualRate.toStringAsFixed(1)}% APR',
                    style: GoogleFonts.orbitron(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: AppColors.neonGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Min stake: \$${minStake.toStringAsFixed(0)} USDT',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (hasStake) ...[
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: [
                  _statCard(
                    'STAKED',
                    '\$${amount.toStringAsFixed(2)}',
                    AppColors.cyan,
                  ),
                  _statCard(
                    'EARNED',
                    '\$${totalEarned.toStringAsFixed(2)}',
                    AppColors.neonGreen,
                  ),
                  _statCard(
                    'DAILY',
                    '\$${dailyReward.toStringAsFixed(4)}',
                    AppColors.amber,
                  ),
                  _statCard(
                    'MONTHLY',
                    '\$${monthlyReward.toStringAsFixed(2)}',
                    AppColors.amber,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: canUnstake ? _unstake : null,
                  icon: const Icon(Icons.lock_open, size: 18),
                  label: Text(
                    canUnstake ? 'UNSTAKE ALL' : 'COOLDOWN ACTIVE',
                    style: GoogleFonts.rajdhani(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canUnstake
                        ? AppColors.neonRed
                        : AppColors.backgroundTertiary,
                    foregroundColor: AppColors.backgroundPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ] else ...[
              Text(
                'STAKE USDT',
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.amber,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _stakeController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                style: GoogleFonts.orbitron(
                  fontSize: 20,
                  color: AppColors.neonGreen,
                ),
                decoration: InputDecoration(
                  hintText: 'Amount in USDT',
                  hintStyle: GoogleFonts.inter(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  suffixIcon: TextButton(
                    onPressed: () => _stakeController.text = authService.balance
                        .toStringAsFixed(2),
                    child: Text(
                      'MAX',
                      style: GoogleFonts.rajdhani(
                        color: AppColors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _stake,
                  icon: const Icon(Icons.savings, size: 18),
                  label: Text(
                    'STAKE NOW',
                    style: GoogleFonts.rajdhani(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.neonGreen,
                    foregroundColor: AppColors.backgroundPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.backgroundTertiary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOW IT WORKS',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.amber,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _infoItem('Earn passive income on your USDT balance'),
                  _infoItem(
                    'Rewards distributed daily at ${(annualRate / 365).toStringAsFixed(3)}%/day',
                  ),
                  _infoItem('Unstake anytime with 24h cooldown'),
                  _infoItem('Staked funds cannot be used for games'),
                ],
              ),
            ),
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

  Widget _infoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 6, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

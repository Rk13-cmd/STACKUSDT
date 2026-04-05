import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/api_service.dart';
import '../../core/theme.dart';
import '../../core/auth_service.dart';

class BonusesScreen extends StatefulWidget {
  const BonusesScreen({super.key});

  @override
  State<BonusesScreen> createState() => _BonusesScreenState();
}

class _BonusesScreenState extends State<BonusesScreen> {
  List<dynamic> _activeBonuses = [];
  List<dynamic> _myBonuses = [];
  double _pendingValue = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final bonusesRes = await apiService.get('/features/bonuses/active');
      final myRes = await apiService.get(
        '/features/bonuses/my?user_id=${authService.userId}',
      );

      if (mounted) {
        setState(() {
          _activeBonuses = bonusesRes['success'] == true
              ? bonusesRes['bonuses'] ?? []
              : [];
          if (myRes['success'] == true) {
            _myBonuses = myRes['bonuses'] ?? [];
            _pendingValue =
                double.tryParse(myRes['pending_value']?.toString() ?? '0') ?? 0;
          }
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return const Center(
        child: CircularProgressIndicator(color: AppColors.amber),
      );

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
              'BONUSES',
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
            if (_pendingValue > 0) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.neonGreen.withOpacity(0.15),
                      AppColors.backgroundSecondary,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.neonGreen.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      'PENDING BONUSES',
                      style: GoogleFonts.rajdhani(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textMuted,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '\$${_pendingValue.toStringAsFixed(2)} USDT',
                      style: GoogleFonts.orbitron(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              'MY BONUSES',
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.amber,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            if (_myBonuses.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.backgroundTertiary),
                ),
                child: Center(
                  child: Text(
                    'No bonuses yet. Make a deposit to earn bonuses!',
                    style: GoogleFonts.inter(color: AppColors.textMuted),
                  ),
                ),
              )
            else
              ..._myBonuses.map((b) => _myBonusCard(b)),
            const SizedBox(height: 24),
            Text(
              'AVAILABLE BONUSES',
              style: GoogleFonts.rajdhani(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.amber,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 12),
            if (_activeBonuses.isEmpty)
              Center(
                child: Text(
                  'No active bonuses',
                  style: GoogleFonts.inter(color: AppColors.textMuted),
                ),
              )
            else
              ..._activeBonuses.map((b) => _availableBonusCard(b)),
          ],
        ),
      ),
    );
  }

  Widget _myBonusCard(dynamic b) {
    final status = b['status'] ?? 'pending';
    final statusColor = status == 'claimed'
        ? AppColors.cyan
        : status == 'expired'
        ? AppColors.neonRed
        : AppColors.amber;
    final bonusData = b['bonuses'] ?? {};

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.backgroundTertiary),
      ),
      child: Row(
        children: [
          Icon(
            status == 'claimed'
                ? Icons.check_circle
                : status == 'pending'
                ? Icons.card_giftcard
                : Icons.error_outline,
            size: 20,
            color: statusColor,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bonusData['name'] ?? b['bonus_id'] ?? 'Bonus',
                  style: GoogleFonts.rajdhani(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  '\$${double.tryParse(b['amount_usdt']?.toString() ?? '0')?.toStringAsFixed(2)}',
                  style: GoogleFonts.robotoMono(
                    fontSize: 13,
                    color: AppColors.neonGreen,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              status.toUpperCase(),
              style: GoogleFonts.rajdhani(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: statusColor,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _availableBonusCard(dynamic b) {
    final isPercent = (b['amount_percent'] ?? 0) > 0;
    final value = isPercent
        ? '${b['amount_percent']}%'
        : '\$${double.tryParse(b['amount_usdt']?.toString() ?? '0')?.toStringAsFixed(2)}';
    final minDeposit =
        double.tryParse(b['min_deposit']?.toString() ?? '0') ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.amber.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.card_giftcard, size: 20, color: AppColors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  b['name'] ?? '',
                  style: GoogleFonts.rajdhani(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Text(
                value,
                style: GoogleFonts.orbitron(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.neonGreen,
                ),
              ),
            ],
          ),
          if (b['description'] != null) ...[
            const SizedBox(height: 4),
            Text(
              b['description'],
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textMuted,
              ),
            ),
          ],
          if (minDeposit > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Min deposit: \$${minDeposit.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

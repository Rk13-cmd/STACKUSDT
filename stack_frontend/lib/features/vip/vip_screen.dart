import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';

class VipScreen extends StatefulWidget {
  const VipScreen({super.key});

  @override
  State<VipScreen> createState() => _VipScreenState();
}

class _VipScreenState extends State<VipScreen> {
  Map<String, dynamic> _config = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final res = await apiService.get('/economy/config');
    if (res['success'] == true && mounted) {
      setState(() {
        _config = res['config'] ?? {};
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
              'VIP MEMBERSHIP',
              style: GoogleFonts.orbitron(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.amber,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.amber.withValues(alpha: 0.15),
                          AppColors.backgroundSecondary,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppColors.amber.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        const Icon(
                          Icons.workspace_premium,
                          size: 48,
                          color: AppColors.amber,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'UPGRADE YOUR EXPERIENCE',
                          style: GoogleFonts.rajdhani(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.amber,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Get reduced rake, exclusive freerolls, and premium benefits',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  ..._buildVipTiers(),
                ],
              ),
            ),
    );
  }

  List<Widget> _buildVipTiers() {
    final vipConfig = _config['vip_config'] ?? {};
    final tiers = [
      {
        'key': 'bronze',
        'name': 'VIP BRONZE',
        'price': vipConfig['bronze']?['price'] ?? 9.99,
        'discount': vipConfig['bronze']?['rake_discount'] ?? 3,
        'freerolls': vipConfig['bronze']?['freerolls_per_week'] ?? 1,
        'color': const Color(0xFFCD7F32),
        'icon': Icons.star,
      },
      {
        'key': 'gold',
        'name': 'VIP GOLD',
        'price': vipConfig['gold']?['price'] ?? 24.99,
        'discount': vipConfig['gold']?['rake_discount'] ?? 5,
        'freerolls': vipConfig['gold']?['freerolls_per_week'] ?? 3,
        'color': AppColors.amber,
        'icon': Icons.workspace_premium,
      },
      {
        'key': 'diamond',
        'name': 'VIP DIAMOND',
        'price': vipConfig['diamond']?['price'] ?? 49.99,
        'discount': vipConfig['diamond']?['rake_discount'] ?? 7,
        'freerolls': vipConfig['diamond']?['freerolls_per_week'] ?? 999,
        'color': AppColors.cyan,
        'icon': Icons.diamond,
      },
    ];

    return tiers.map((tier) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (tier['color'] as Color).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  tier['icon'] as IconData,
                  color: tier['color'] as Color,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  tier['name'] as String,
                  style: GoogleFonts.orbitron(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: tier['color'] as Color,
                    letterSpacing: 2,
                  ),
                ),
                const Spacer(),
                Text(
                  '\$${(tier['price'] as num).toStringAsFixed(2)}/mo',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _benefitRow(
              'Rake Discount',
              '-${tier['discount']}% on all tournaments',
              AppColors.neonGreen,
            ),
            _benefitRow(
              'Freerolls',
              '${tier['freerolls'] == 999 ? 'Unlimited' : tier['freerolls']} per week',
              AppColors.cyan,
            ),
            _benefitRow(
              'Priority Support',
              'Faster withdrawal processing',
              AppColors.textSecondary,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: tier['color'] as Color,
                  foregroundColor: AppColors.backgroundPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'SUBSCRIBE NOW',
                  style: GoogleFonts.rajdhani(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  Widget _benefitRow(String title, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.rajdhani(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          Text(
            desc,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

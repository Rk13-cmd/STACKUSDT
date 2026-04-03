import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/auth_service.dart';
import '../../core/shop_controller.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  List<dynamic> _skins = [];
  List<dynamic> _ownedSkinIds = [];
  String? _activeSkinId;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    setState(() => _isLoading = true);

    try {
      final skins = await shopController.getSkins();

      if (!mounted) return;
      final authService = Provider.of<AuthService>(context, listen: false);
      if (authService.userId != null) {
        final inventory = await shopController.getInventory(
          authService.userId!,
        );
        _ownedSkinIds = (inventory['inventory'] as List)
            .map((item) => item['skin_id'] as String)
            .toList();
        _activeSkinId = inventory['active_skin']?['id'];
      }

      setState(() {
        _skins = skins;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load shop';
        _isLoading = false;
      });
    }
  }

  Future<void> _buySkin(String skinId) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.userId == null) return;

    final response = await shopController.buySkin(authService.userId!, skinId);

    if (!mounted) return;

    if (response['success'] == true) {
      await authService.refreshProfile();
      await _loadShop();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: AppColors.neonGreen),
              const SizedBox(width: 12),
              Text(
                response['message'] ?? 'Purchase successful!',
                style: GoogleFonts.rajdhani(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.backgroundSecondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.neonGreen.withValues(alpha: 0.3)),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
    } else if (response['error'] == 'INSUFFICIENT_LIQUIDITY') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: AppColors.neonRed),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INSUFFICIENT LIQUIDITY',
                      style: GoogleFonts.orbitron(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: AppColors.neonRed,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      response['message'] ?? '',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.neonRed.withValues(alpha: 0.15),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.neonRed.withValues(alpha: 0.4)),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['error'] ?? 'Purchase failed',
            style: GoogleFonts.inter(color: AppColors.neonRed),
          ),
          backgroundColor: AppColors.backgroundSecondary,
        ),
      );
    }
  }

  Future<void> _equipSkin(String skinId) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.userId == null) return;

    final response = await shopController.equipSkin(
      authService.userId!,
      skinId,
    );

    if (!mounted) return;

    if (response['success'] == true) {
      setState(() => _activeSkinId = skinId);
      await authService.refreshProfile();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.palette_outlined, color: AppColors.cyan),
              const SizedBox(width: 12),
              Text(
                response['message'] ?? 'Skin equipped!',
                style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          backgroundColor: AppColors.backgroundSecondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.cyan.withValues(alpha: 0.3)),
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
              'SKIN SHOP',
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
          Consumer<AuthService>(
            builder: (context, auth, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 16,
                      color: AppColors.neonGreen,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '\$${auth.balance.toStringAsFixed(2)}',
                      style: GoogleFonts.orbitron(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.neonGreen,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            )
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _error!,
                    style: GoogleFonts.inter(color: AppColors.neonRed),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _loadShop,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          : _buildGrid(),
    );
  }

  Widget _buildGrid() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.75,
      ),
      itemCount: _skins.length,
      itemBuilder: (context, index) {
        final skin = _skins[index];
        final isOwned = _ownedSkinIds.contains(skin['id']);
        final isActive = _activeSkinId == skin['id'];
        final isFree = (skin['price_usdt'] ?? 0) == 0;
        final isPremium = skin['is_premium'] == true;

        return _SkinCard(
          skin: skin,
          isOwned: isOwned,
          isActive: isActive,
          isFree: isFree,
          isPremium: isPremium,
          onBuy: () => _buySkin(skin['id']),
          onEquip: () => _equipSkin(skin['id']),
        );
      },
    );
  }
}

class _SkinCard extends StatelessWidget {
  final dynamic skin;
  final bool isOwned;
  final bool isActive;
  final bool isFree;
  final bool isPremium;
  final VoidCallback onBuy;
  final VoidCallback onEquip;

  const _SkinCard({
    required this.skin,
    required this.isOwned,
    required this.isActive,
    required this.isFree,
    required this.isPremium,
    required this.onBuy,
    required this.onEquip,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(
      int.parse(skin['block_color_hex'].replaceFirst('#', '0xFF')),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive
              ? AppColors.amber.withValues(alpha: 0.6)
              : isPremium
              ? AppColors.amber.withValues(alpha: 0.2)
              : AppColors.backgroundTertiary.withValues(alpha: 0.5),
          width: isActive ? 2 : 1,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: AppColors.amber.withValues(alpha: 0.2),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Center(child: _buildPreview(color)),
                if (isActive)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.amber,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        size: 12,
                        color: AppColors.backgroundPrimary,
                      ),
                    ),
                  ),
                if (isPremium && !isOwned)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.amber.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'PREMIUM',
                        style: GoogleFonts.rajdhani(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: AppColors.amber,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: Column(
              children: [
                Text(
                  skin['name'] ?? 'Unknown',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.rajdhani(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isActive ? AppColors.amber : AppColors.textPrimary,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                if (isOwned && !isActive)
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: OutlinedButton(
                      onPressed: onEquip,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.cyan,
                        side: BorderSide(
                          color: AppColors.cyan.withValues(alpha: 0.4),
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        'EQUIP',
                        style: GoogleFonts.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  )
                else if (!isOwned)
                  SizedBox(
                    width: double.infinity,
                    height: 28,
                    child: ElevatedButton(
                      onPressed: onBuy,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isFree
                            ? AppColors.neonGreen.withValues(alpha: 0.2)
                            : AppColors.amber.withValues(alpha: 0.2),
                        foregroundColor: isFree
                            ? AppColors.neonGreen
                            : AppColors.amber,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                          side: BorderSide(
                            color: isFree
                                ? AppColors.neonGreen.withValues(alpha: 0.3)
                                : AppColors.amber.withValues(alpha: 0.3),
                            width: 1,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                      child: Text(
                        isFree ? 'FREE' : '\$${skin['price_usdt']}',
                        style: GoogleFonts.rajdhani(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.amber.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'EQUIPPED',
                      style: GoogleFonts.rajdhani(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppColors.amber,
                        letterSpacing: 2,
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

  Widget _buildPreview(Color color) {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(10),
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
        physics: const NeverScrollableScrollPhysics(),
        children: List.generate(9, (i) {
          final row = i ~/ 3;
          final col = i % 3;
          final isActive = _getPreviewPattern(row, col);
          return Container(
            decoration: BoxDecoration(
              color: isActive ? color : color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(2),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 4,
                      ),
                    ]
                  : null,
            ),
          );
        }),
      ),
    );
  }

  bool _getPreviewPattern(int row, int col) {
    final patterns = [
      [true, false, true, false, true, false, true, false, true],
      [false, true, false, true, false, true, false, true, false],
      [true, true, true, true, false, true, true, true, true],
      [true, false, true, true, true, true, true, false, true],
      [false, false, true, false, true, false, true, false, false],
    ];
    final idx = (row * 3 + col) % patterns.length;
    return patterns[idx][row * 3 + col];
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/auth_service.dart';
import '../../core/api_service.dart';
import 'game_engine.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late GameEngine _engine;
  Timer? _earningsTimer;
  double _sessionEarnings = 0;
  int _sessionStartTime = 0;
  String? _sessionId;
  bool _isGameActive = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _engine = GameEngine();
    _engine.initGame();
    _engine.addListener(_onEngineChange);
  }

  void _onEngineChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _engine.removeListener(_onEngineChange);
    _engine.dispose();
    _earningsTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _startGameSession() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.userId == null) return;

    final response = await apiService.post('/game/start-game', {
      'user_id': authService.userId!,
      'device_fingerprint': 'web_${DateTime.now().millisecondsSinceEpoch}',
    });

    if (response['success'] == true) {
      setState(() {
        _sessionId = response['session_id'];
        _sessionStartTime = DateTime.now().millisecondsSinceEpoch;
        _sessionEarnings = 0;
        _isGameActive = true;
      });

      final activeSkin = authService.userProfile?['active_skin'];
      if (activeSkin != null && activeSkin['block_color_hex'] != null) {
        try {
          final skinColor = Color(
            int.parse(activeSkin['block_color_hex'].replaceFirst('#', '0xFF')),
          );
          _engine.setSkinColor(skinColor);
        } catch (_) {
          _engine.setSkinColor(null);
        }
      } else {
        _engine.setSkinColor(null);
      }

      _engine.startGame();
      _focusNode.requestFocus();

      _earningsTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        if (_engine.isPlaying) {
          final elapsed =
              (DateTime.now().millisecondsSinceEpoch - _sessionStartTime) /
              1000;
          final baseRate = 0.005;
          final scoreBonus = _engine.score * 0.00001;
          final linesBonus = _engine.linesCleared * 0.002;
          final levelMultiplier = 1 + (_engine.level - 1) * 0.15;
          final earnings =
              (baseRate + scoreBonus + linesBonus) *
              levelMultiplier *
              (elapsed / 60);
          setState(() {
            _sessionEarnings = earnings;
          });
        }
      });
    }
  }

  Future<void> _endGameSession() async {
    _earningsTimer?.cancel();
    _engine.endGame();

    if (_sessionId != null) {
      final elapsed =
          (DateTime.now().millisecondsSinceEpoch - _sessionStartTime) / 1000;

      await apiService.post('/game/end-game', {
        'session_id': _sessionId,
        'lines_cleared': _engine.linesCleared,
        'play_time_seconds': elapsed.toInt(),
        'score': _engine.score,
      });

      if (!mounted) return;

      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.refreshProfile();
    }

    if (!mounted) return;

    setState(() {
      _isGameActive = false;
      _sessionId = null;
    });
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
          _engine.moveLeft();
          break;
        case LogicalKeyboardKey.arrowRight:
          _engine.moveRight();
          break;
        case LogicalKeyboardKey.arrowDown:
          _engine.moveDown();
          break;
        case LogicalKeyboardKey.arrowUp:
          _engine.rotate();
          break;
        case LogicalKeyboardKey.space:
          _engine.hardDrop();
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isDesktop = constraints.maxWidth > 900;
          if (isDesktop) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Column(
        children: [
          _buildXPBar(),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Stack(
                    children: [
                      _GameBoardWidget(engine: _engine),
                      if (_engine.isGameOver)
                        _GameOverOverlay(
                          score: _engine.score,
                          lines: _engine.linesCleared,
                          level: _engine.level,
                          onRestart: _restartGame,
                        ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: _EarningsPanel(
                    engine: _engine,
                    sessionEarnings: _sessionEarnings,
                    isGameActive: _isGameActive,
                    onStartGame: _startGameSession,
                    onEndGame: _endGameSession,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildXPBar() {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final xp = authService.userProfile?['mining_xp'] ?? 0;
        final level = authService.userProfile?['mining_level'] ?? 1;
        final xpInCurrentLevel = xp - ((level - 1) * 1000);
        final xpNeeded = 1000;
        final progress = (xpInCurrentLevel / xpNeeded).clamp(0.0, 1.0);

        return Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
          color: AppColors.backgroundSecondary,
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppColors.amber.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 14,
                      color: AppColors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'LVL $level',
                      style: GoogleFonts.orbitron(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.amber,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.backgroundTertiary,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      progress >= 1.0 ? AppColors.neonGreen : AppColors.cyan,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$xpInCurrentLevel / $xpNeeded XP',
                style: GoogleFonts.rajdhani(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _restartGame() {
    _earningsTimer?.cancel();
    _engine.initGame();
    _startGameSession();
  }

  Widget _buildMobileLayout() {
    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            _GameBoardWidget(engine: _engine),
            const SizedBox(height: 16),
            _EarningsPanel(
              engine: _engine,
              sessionEarnings: _sessionEarnings,
              isGameActive: _isGameActive,
              onStartGame: _startGameSession,
              onEndGame: _endGameSession,
            ),
            const SizedBox(height: 16),
            _buildMobileControls(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _mobileControlBtn(Icons.rotate_left, () => _engine.rotate()),
              const SizedBox(width: 16),
              _mobileControlBtn(
                Icons.keyboard_arrow_up,
                () => _engine.rotate(),
              ),
              const SizedBox(width: 16),
              _mobileControlBtn(
                Icons.keyboard_arrow_down,
                () => _engine.moveDown(),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _mobileControlBtn(
                Icons.keyboard_arrow_left,
                () => _engine.moveLeft(),
              ),
              const SizedBox(width: 16),
              _mobileControlBtn(
                Icons.play_arrow,
                () => _engine.hardDrop(),
                large: true,
              ),
              const SizedBox(width: 16),
              _mobileControlBtn(
                Icons.keyboard_arrow_right,
                () => _engine.moveRight(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mobileControlBtn(
    IconData icon,
    VoidCallback onTap, {
    bool large = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: large ? 80 : 64,
        height: large ? 80 : 64,
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: AppColors.cyan, size: large ? 36 : 28),
      ),
    );
  }
}

class _GameBoardWidget extends StatelessWidget {
  final GameEngine engine;
  const _GameBoardWidget({required this.engine});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth * 0.8;
        final maxHeight = constraints.maxHeight * 0.9;
        final cellSize = (maxWidth / gridCols).clamp(
          16.0,
          maxHeight / gridRows,
        );

        return Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cyan, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.cyan.withValues(alpha: 0.2),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: CustomPaint(
                size: Size(cellSize * gridCols, cellSize * gridRows),
                painter: _MiningGridPainter(
                  grid: engine.grid,
                  gridColors: engine.gridColors,
                  currentPiece: engine.currentPiece,
                  currentColor: engine.currentColor,
                  currentRow: engine.currentRow,
                  currentCol: engine.currentCol,
                  ghostRow: engine.getGhostRow(),
                  cellSize: cellSize,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MiningGridPainter extends CustomPainter {
  final List<List<int>> grid;
  final List<List<Color>> gridColors;
  final List<List<int>>? currentPiece;
  final Color currentColor;
  final int currentRow;
  final int currentCol;
  final int ghostRow;
  final double cellSize;

  _MiningGridPainter({
    required this.grid,
    required this.gridColors,
    required this.currentPiece,
    required this.currentColor,
    required this.currentRow,
    required this.currentCol,
    required this.ghostRow,
    required this.cellSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final borderPaint = Paint()
      ..color = AppColors.backgroundPrimary.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int r = 0; r < gridRows; r++) {
      for (int c = 0; c < gridCols; c++) {
        final rect = Rect.fromLTWH(
          c * cellSize,
          r * cellSize,
          cellSize,
          cellSize,
        );

        if (grid[r][c] == 1) {
          paint.color = gridColors[r][c];
          canvas.drawRect(rect, paint);
          paint.color = Colors.white.withValues(alpha: 0.2);
          canvas.drawCircle(
            Offset(c * cellSize + cellSize / 2, r * cellSize + cellSize / 2),
            cellSize * 0.15,
            paint,
          );
        } else {
          paint.color = AppColors.backgroundTertiary.withValues(alpha: 0.3);
          canvas.drawRect(rect, paint);
        }
        canvas.drawRect(rect, borderPaint);
      }
    }

    if (currentPiece != null) {
      paint.color = currentColor.withValues(alpha: 0.2);
      for (int r = 0; r < currentPiece!.length; r++) {
        for (int c = 0; c < currentPiece![r].length; c++) {
          if (currentPiece![r][c] == 1) {
            final rect = Rect.fromLTWH(
              (currentCol + c) * cellSize,
              (ghostRow + r) * cellSize,
              cellSize,
              cellSize,
            );
            canvas.drawRect(rect, paint);
          }
        }
      }
    }

    if (currentPiece != null) {
      for (int r = 0; r < currentPiece!.length; r++) {
        for (int c = 0; c < currentPiece![r].length; c++) {
          if (currentPiece![r][c] == 1) {
            final rect = Rect.fromLTWH(
              (currentCol + c) * cellSize,
              (currentRow + r) * cellSize,
              cellSize,
              cellSize,
            );
            paint.color = currentColor;
            canvas.drawRect(rect, paint);
            paint.color = Colors.white.withValues(alpha: 0.3);
            canvas.drawCircle(
              Offset(
                (currentCol + c) * cellSize + cellSize / 2,
                (currentRow + r) * cellSize + cellSize / 2,
              ),
              cellSize * 0.15,
              paint,
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiningGridPainter oldDelegate) => true;
}

class _EarningsPanel extends StatelessWidget {
  final GameEngine engine;
  final double sessionEarnings;
  final bool isGameActive;
  final VoidCallback onStartGame;
  final VoidCallback onEndGame;

  const _EarningsPanel({
    required this.engine,
    required this.sessionEarnings,
    required this.isGameActive,
    required this.onStartGame,
    required this.onEndGame,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildEarningsCard(),
          const SizedBox(height: 16),
          _buildLiveMetrics(),
          const SizedBox(height: 16),
          _buildNextPiecePreview(),
          const SizedBox(height: 16),
          _buildPlayButton(),
          const SizedBox(height: 12),
          _buildWithdrawButton(),
          const Spacer(),
          _buildMiniStats(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 500),
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isGameActive ? AppColors.neonGreen : AppColors.textMuted,
            shape: BoxShape.circle,
            boxShadow: isGameActive
                ? [
                    BoxShadow(
                      color: AppColors.neonGreen.withValues(alpha: 0.6),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          isGameActive ? 'MINING' : 'STANDBY',
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isGameActive ? AppColors.neonGreen : AppColors.textMuted,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildEarningsCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.amber.withValues(alpha: 0.12),
            AppColors.backgroundTertiary.withValues(alpha: 0.3),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.monetization_on_rounded,
                size: 16,
                color: AppColors.amber.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 4),
              Text(
                'SESSION EARNINGS',
                style: GoogleFonts.rajdhani(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.goldGradientStart, AppColors.goldGradientEnd],
            ).createShader(bounds),
            child: Text(
              '\$${sessionEarnings.toStringAsFixed(4)}',
              style: GoogleFonts.orbitron(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'USDT',
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.amber.withValues(alpha: 0.7),
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMetrics() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundTertiary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          _metricRow(
            Icons.emoji_events_outlined,
            'SCORE',
            engine.score.toString(),
            AppColors.cyan,
          ),
          const SizedBox(height: 8),
          _metricRow(
            Icons.layers_outlined,
            'LINES',
            engine.linesCleared.toString(),
            AppColors.neonGreen,
          ),
          const SizedBox(height: 8),
          _metricRow(
            Icons.speed_outlined,
            'LEVEL',
            engine.level.toString(),
            AppColors.amber,
          ),
          if (engine.combo > 0) ...[
            const SizedBox(height: 8),
            _metricRow(
              Icons.whatshot_outlined,
              'COMBO',
              'x${engine.combo}',
              AppColors.neonRed,
            ),
          ],
        ],
      ),
    );
  }

  Widget _metricRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
            letterSpacing: 1.5,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildNextPiecePreview() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.backgroundTertiary.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'NEXT ASSET',
            style: GoogleFonts.rajdhani(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: SizedBox(
              height: 48,
              child: engine.nextPiece != null
                  ? CustomPaint(
                      size: const Size(48, 48),
                      painter: _NextPiecePainter(
                        piece: engine.nextPiece!,
                        color: engine.nextColor,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton() {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: OutlinedButton(
        onPressed: isGameActive ? onEndGame : onStartGame,
        style: OutlinedButton.styleFrom(
          foregroundColor: isGameActive ? AppColors.neonRed : AppColors.amber,
          side: BorderSide(
            color: isGameActive ? AppColors.neonRed : AppColors.amber,
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isGameActive ? Icons.stop_rounded : Icons.play_arrow_rounded,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              isGameActive ? 'STOP' : 'START MINING',
              style: GoogleFonts.rajdhani(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawButton() {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        return SizedBox(
          width: double.infinity,
          height: 36,
          child: ElevatedButton(
            onPressed: authService.balance >= 10
                ? () => _showWithdrawDialog(context, authService)
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.amber.withValues(alpha: 0.15),
              disabledBackgroundColor: AppColors.backgroundTertiary.withValues(
                alpha: 0.2,
              ),
              foregroundColor: authService.balance >= 10
                  ? AppColors.amber
                  : AppColors.textMuted,
              disabledForegroundColor: AppColors.textMuted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(
                  color: AppColors.amber.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance_wallet_outlined, size: 14),
                const SizedBox(width: 6),
                Text(
                  'WITHDRAW',
                  style: GoogleFonts.rajdhani(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMiniStats() {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.backgroundTertiary.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              _miniRow(
                'BALANCE',
                '\$${authService.balance.toStringAsFixed(2)}',
                AppColors.neonGreen,
              ),
              const SizedBox(height: 6),
              _miniRow(
                'EARNED',
                '\$${(authService.userProfile?['total_earned'] ?? 0).toString()}',
                AppColors.amber,
              ),
              const SizedBox(height: 6),
              _miniRow(
                'USER',
                authService.userProfile?['username'] ?? 'Guest',
                AppColors.cyan,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _miniRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: GoogleFonts.orbitron(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }

  void _showWithdrawDialog(BuildContext context, AuthService authService) {
    final amountController = TextEditingController();
    final walletController = TextEditingController(
      text: authService.userProfile?['wallet_address'] ?? '',
    );
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: AppColors.backgroundSecondary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'WITHDRAW USDT',
            style: GoogleFonts.orbitron(fontSize: 18, color: AppColors.amber),
          ),
          content: SizedBox(
            width: 350,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Available: \$${authService.balance.toStringAsFixed(2)}',
                  style: GoogleFonts.inter(color: AppColors.neonGreen),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.inter(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Amount (USDT)',
                    labelStyle: GoogleFonts.inter(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.backgroundTertiary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: walletController,
                  style: GoogleFonts.inter(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Wallet Address (TRC20)',
                    labelStyle: GoogleFonts.inter(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.backgroundTertiary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      error!,
                      style: GoogleFonts.inter(color: AppColors.neonRed),
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: AppColors.textMuted),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                final amount = double.tryParse(amountController.text);
                if (amount == null || amount < 10) {
                  setDialogState(() => error = 'Minimum withdrawal is 10 USDT');
                  return;
                }
                if (amount > authService.balance) {
                  setDialogState(() => error = 'Insufficient balance');
                  return;
                }
                if (walletController.text.length < 20) {
                  setDialogState(() => error = 'Invalid wallet address');
                  return;
                }

                final response = await apiService.post('/withdraw', {
                  'user_id': authService.userId,
                  'amount': amount,
                  'wallet_address': walletController.text,
                  'network': 'TRC20',
                });

                if (response['success'] == true) {
                  await authService.refreshProfile();
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Withdrawal of \$${amount.toStringAsFixed(2)} submitted!',
                      ),
                      backgroundColor: AppColors.neonGreen,
                    ),
                  );
                } else {
                  setDialogState(() => error = response['error'] ?? 'Failed');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.backgroundPrimary,
              ),
              child: Text(
                'WITHDRAW',
                style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatefulWidget {
  final int score;
  final int lines;
  final int level;
  final VoidCallback onRestart;

  const _GameOverOverlay({
    required this.score,
    required this.lines,
    required this.level,
    required this.onRestart,
  });

  @override
  State<_GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<_GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.elasticOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 60.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.6, curve: Curves.easeOutCubic),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeInOut),
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary.withValues(
              alpha: 0.92 * _fadeAnimation.value,
            ),
          ),
          child: Center(
            child: Transform.translate(
              offset: Offset(0, _slideAnimation.value),
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: _buildGameOverCard(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameOverCard() {
    return Container(
      width: 420,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 32),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: AppColors.neonRed.withValues(alpha: _glowAnimation.value),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.neonRed.withValues(
              alpha: _glowAnimation.value * 0.4,
            ),
            blurRadius: 40,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.neonRed.withValues(
              alpha: _glowAnimation.value * 0.2,
            ),
            blurRadius: 80,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.neonRed.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.neonRed.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.power_settings_new_rounded,
              size: 40,
              color: AppColors.neonRed,
            ),
          ),
          const SizedBox(height: 24),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AppColors.neonRed, Color(0xFFFF4444)],
            ).createShader(bounds),
            child: Text(
              'GAME OVER',
              style: GoogleFonts.orbitron(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 6,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Casi lo logras!',
            style: GoogleFonts.rajdhani(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.backgroundTertiary.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _goStat('SCORE', widget.score.toString(), AppColors.cyan),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _goStat(
                      'LINES',
                      widget.lines.toString(),
                      AppColors.neonGreen,
                    ),
                    Container(
                      width: 1,
                      height: 30,
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      color: AppColors.backgroundTertiary,
                    ),
                    _goStat('LEVEL', widget.level.toString(), AppColors.amber),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: 220,
            height: 50,
            child: ElevatedButton(
              onPressed: widget.onRestart,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.backgroundPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.refresh_rounded, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'INTENTE DE NUEVO',
                    style: GoogleFonts.rajdhani(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _goStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: AppColors.textMuted,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _NextPiecePainter extends CustomPainter {
  final List<List<int>> piece;
  final Color color;

  _NextPiecePainter({required this.piece, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final cellSize = 14.0;
    final offsetX = (size.width - piece[0].length * cellSize) / 2;
    final offsetY = (size.height - piece.length * cellSize) / 2;

    for (int r = 0; r < piece.length; r++) {
      for (int c = 0; c < piece[r].length; c++) {
        if (piece[r][c] == 1) {
          canvas.drawRect(
            Rect.fromLTWH(
              offsetX + c * cellSize,
              offsetY + r * cellSize,
              cellSize,
              cellSize,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NextPiecePainter oldDelegate) => true;
}

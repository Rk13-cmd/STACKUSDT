import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme.dart';
import '../../core/api_service.dart';
import 'game_controller.dart';
import 'models.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController _gameController;
  final ApiService _apiService = ApiService();

  final String _userId = 'user_demo_123';
  double _usdtBalance = 14.50;
  bool _isSyncing = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _gameController = GameController(apiService: _apiService, userId: _userId);
    _gameController.addListener(_onGameStateChanged);
  }

  void _onGameStateChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _gameController.removeListener(_onGameStateChanged);
    _gameController.dispose();
    _apiService.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (_gameController.state.status != GameStatus.playing) {
      return KeyEventResult.ignored;
    }

    if (event is KeyDownEvent) {
      switch (event.logicalKey) {
        case LogicalKeyboardKey.arrowLeft:
          _gameController.moveLeft();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowRight:
          _gameController.moveRight();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowDown:
          _gameController.softDrop();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.arrowUp:
          _gameController.rotatePiece();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyC:
          _gameController.holdPiece();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.space:
          _gameController.hardDrop();
          return KeyEventResult.handled;
        case LogicalKeyboardKey.keyP:
          _gameController.pauseGame();
          return KeyEventResult.handled;
        default:
          return KeyEventResult.ignored;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _handlePlayNow() async {
    setState(() => _isSyncing = true);
    await _gameController.startGame();
    setState(() => _isSyncing = false);
    _focusNode.requestFocus();
  }

  Future<void> _handleWithdraw() async {
    if (_usdtBalance <= 0) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _WithdrawDialog(amount: _usdtBalance),
    );

    if (confirmed != true) return;

    setState(() => _isSyncing = true);
    try {
      final response = await _apiService.requestUsdtWithdrawal(
        userId: _userId,
        amount: _usdtBalance,
        walletAddress: '0xDemoWallet123',
      );
      setState(() {
        _isSyncing = false;
        if (response.success) _usdtBalance = 0;
      });
    } catch (e) {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = _gameController.state;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKey,
      autofocus: true,
      child: Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth > 1100;
                return isDesktop ? _buildDesktop(state) : _buildMobile(state);
              },
            ),
            if (_isSyncing)
              Container(
                color: Colors.black54,
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(AppColors.cyan),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktop(GameState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildSidePanel(state, isLeft: true),
          const SizedBox(width: 16),
          Expanded(child: _buildGameGrid(state)),
          const SizedBox(width: 16),
          _buildSidePanel(state, isLeft: false),
        ],
      ),
    );
  }

  Widget _buildMobile(GameState state) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          children: [
            _buildGameGrid(state, compact: true),
            const SizedBox(height: 8),
            _buildMobileStatsPanel(state),
            const SizedBox(height: 8),
            _buildMobileControlPanel(state),
          ],
        ),
      ),
    );
  }

  Widget _buildSidePanel(GameState state, {required bool isLeft}) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.backgroundTertiary),
      ),
      child: Column(
        children: [
          if (isLeft) ...[
            _buildHoldPanel(state),
            const Spacer(),
            _buildStatsPanel(state),
          ] else ...[
            _buildNextPanel(state),
            const Spacer(),
            _buildControlsInfo(),
          ],
        ],
      ),
    );
  }

  Widget _buildHoldPanel(GameState state) {
    return Column(
      children: [
        Text(
          'HOLD',
          style: GoogleFonts.rajdhani(
            fontSize: 12,
            color: AppColors.textMuted,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: state.canHold
                  ? AppColors.cyan.withAlpha(128)
                  : AppColors.textMuted,
              width: 2,
            ),
          ),
          child: state.holdPiece != null
              ? _buildMiniPiece(state.holdPiece!)
              : Center(
                  child: Icon(
                    Icons.pause,
                    color: AppColors.textMuted,
                    size: 24,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildNextPanel(GameState state) {
    return Column(
      children: [
        Text(
          'NEXT',
          style: GoogleFonts.rajdhani(
            fontSize: 12,
            color: AppColors.textMuted,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: AppColors.backgroundPrimary,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.cyan.withAlpha(128), width: 2),
          ),
          child: state.nextPiece != null
              ? _buildMiniPiece(state.nextPiece!)
              : const SizedBox(),
        ),
      ],
    );
  }

  Widget _buildMiniPiece(AssetPiece piece) {
    final cellSize = 16.0;
    return Center(
      child: SizedBox(
        width: piece.width * cellSize,
        height: piece.height * cellSize,
        child: Stack(
          children: [
            for (int row = 0; row < piece.matrix.length; row++)
              for (int col = 0; col < piece.matrix[row].length; col++)
                if (piece.matrix[row][col] == 1)
                  Positioned(
                    left: col * cellSize,
                    top: row * cellSize,
                    child: Container(
                      width: cellSize - 2,
                      height: cellSize - 2,
                      decoration: BoxDecoration(
                        color: piece.neonColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: [
                          BoxShadow(color: piece.glowColor, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsPanel(GameState state) {
    return Column(
      children: [
        _buildStatRow('SCORE', '${state.score}', AppColors.cyan),
        const SizedBox(height: 8),
        _buildStatRow('LINES', '${state.linesCleared}', AppColors.amber),
        const SizedBox(height: 8),
        _buildStatRow('LEVEL', '${state.level}', AppColors.neonGreen),
        const SizedBox(height: 8),
        if (state.combo > 0)
          _buildStatRow('COMBO', 'x${state.combo}', Colors.pinkAccent),
      ],
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(fontSize: 10, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildControlsInfo() {
    return Column(
      children: [
        Text(
          'CONTROLS',
          style: GoogleFonts.rajdhani(
            fontSize: 10,
            color: AppColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        _buildControlRow('←→', 'Move'),
        _buildControlRow('↑', 'Rotate'),
        _buildControlRow('↓', 'Soft Drop'),
        _buildControlRow('SPACE', 'Hard Drop'),
        _buildControlRow('C', 'Hold'),
      ],
    );
  }

  Widget _buildControlRow(String key, String action) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            key,
            style: GoogleFonts.rajdhani(fontSize: 10, color: AppColors.cyan),
          ),
          Text(
            action,
            style: GoogleFonts.rajdhani(
              fontSize: 9,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameGrid(GameState state, {bool compact = false}) {
    final isPlaying = state.status == GameStatus.playing;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: NeonBorder(
        color: isPlaying ? AppColors.neonGreen : AppColors.cyan,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.backgroundSecondary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: AspectRatio(
            aspectRatio: gridWidth / gridHeight,
            child: state.status == GameStatus.gameOver
                ? _buildGameOver(state)
                : _buildGridContent(state),
          ),
        ),
      ),
    );
  }

  Widget _buildGridContent(GameState state) {
    return Container(
      margin: const EdgeInsets.all(1),
      child: Column(
        children: List.generate(gridHeight, (y) {
          return Expanded(
            child: Row(
              children: List.generate(gridWidth, (x) {
                return Expanded(child: _buildCell(x, y, state));
              }),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildCell(int x, int y, GameState state) {
    Color? color;
    Color? glowColor;
    bool isGhost = false;

    if (state.currentPiece != null && state.ghostY > 0) {
      final piece = state.currentPiece!;
      final px = x - state.currentX;
      final py = y - state.ghostY;

      if (px >= 0 && px < piece.width && py >= 0 && py < piece.height) {
        if (piece.matrix[py][px] == 1) {
          color = piece.neonColor.withAlpha(77);
          isGhost = true;
        }
      }
    }

    if (color == null && state.currentPiece != null) {
      final piece = state.currentPiece!;
      final px = x - state.currentX;
      final py = y - state.currentY;

      if (px >= 0 && px < piece.width && py >= 0 && py < piece.height) {
        if (piece.matrix[py][px] == 1) {
          color = piece.neonColor;
          glowColor = piece.glowColor;
        }
      }
    }

    if (color == null &&
        y < state.grid.cells.length &&
        x < state.grid.cells[y].length) {
      final cellValue = state.grid.cells[y][x];
      if (cellValue != null) {
        color = Color(cellValue);
      }
    }

    return Container(
      margin: const EdgeInsets.all(0.5),
      decoration: BoxDecoration(
        color: color ?? AppColors.backgroundPrimary,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: isGhost
              ? color?.withAlpha(51) ?? Colors.transparent
              : color != null
              ? Colors.white24
              : AppColors.backgroundTertiary,
          width: 1,
        ),
        boxShadow: glowColor != null || (color != null && !isGhost)
            ? [
                BoxShadow(
                  color: glowColor ?? color!.withAlpha(128),
                  blurRadius: 4,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
    );
  }

  Widget _buildGameOver(GameState state) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.backgroundPrimary.withAlpha(230),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sentiment_very_dissatisfied,
              size: 64,
              color: AppColors.neonRed,
            ),
            const SizedBox(height: 16),
            Text(
              'GAME OVER',
              style: GoogleFonts.orbitron(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.neonRed,
              ),
            ),
            const SizedBox(height: 16),
            _buildFinalStats(state),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _handlePlayNow,
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.cyan),
              child: Text(
                'PLAY AGAIN',
                style: GoogleFonts.rajdhani(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalStats(GameState state) {
    return Column(
      children: [
        _buildStatRow('FINAL SCORE', '${state.score}', AppColors.amber),
        const SizedBox(height: 8),
        _buildStatRow('LEVEL REACHED', '${state.level}', AppColors.cyan),
        const SizedBox(height: 8),
        _buildStatRow(
          'LINES CLEARED',
          '${state.linesCleared}',
          AppColors.neonGreen,
        ),
      ],
    );
  }

  Widget _buildMobileStatsPanel(GameState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [
                    AppColors.goldGradientStart,
                    AppColors.goldGradientEnd,
                  ],
                ).createShader(bounds),
                child: Text(
                  '\$${_usdtBalance.toStringAsFixed(2)}',
                  style: GoogleFonts.orbitron(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'USDT',
                style: GoogleFonts.rajdhani(
                  fontSize: 14,
                  color: AppColors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMobileStat('SCORE', '${state.score}', AppColors.cyan),
              _buildMobileStat(
                'LINES',
                '${state.linesCleared}',
                AppColors.amber,
              ),
              _buildMobileStat('LEVEL', '${state.level}', AppColors.neonGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMobileStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.rajdhani(fontSize: 9, color: AppColors.textMuted),
        ),
        Text(
          value,
          style: GoogleFonts.orbitron(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileControlPanel(GameState state) {
    final isPlaying = state.status == GameStatus.playing;
    final isIdle = state.status == GameStatus.idle;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _usdtBalance > 0 ? _handleWithdraw : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    'WITHDRAW',
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: isIdle ? _handlePlayNow : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.cyan,
                    side: BorderSide(
                      color: isIdle ? AppColors.cyan : AppColors.textMuted,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    isPlaying ? 'PLAYING' : 'PLAY',
                    style: GoogleFonts.rajdhani(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (isPlaying) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMobileBtn(
                  Icons.rotate_left,
                  _gameController.rotatePiece,
                  'Rotate',
                ),
                _buildMobileBtn(
                  Icons.keyboard_arrow_left,
                  _gameController.moveLeft,
                  'Left',
                ),
                _buildMobileBtn(
                  Icons.keyboard_arrow_down,
                  _gameController.softDrop,
                  'Down',
                ),
                _buildMobileBtn(
                  Icons.keyboard_arrow_right,
                  _gameController.moveRight,
                  'Right',
                ),
                _buildMobileBtn(
                  Icons.vertical_align_bottom,
                  _gameController.hardDrop,
                  'Drop',
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileBtn(
    IconData icon,
    VoidCallback onPressed,
    String tooltip,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.backgroundTertiary,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppColors.cyan, size: 24),
        ),
      ),
    );
  }
}

class _WithdrawDialog extends StatefulWidget {
  final double amount;
  const _WithdrawDialog({required this.amount});
  @override
  State<_WithdrawDialog> createState() => _WithdrawDialogState();
}

class _WithdrawDialogState extends State<_WithdrawDialog> {
  final _walletController = TextEditingController();
  @override
  void dispose() {
    _walletController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.backgroundSecondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        'Withdraw USDT',
        style: GoogleFonts.orbitron(fontSize: 20, color: AppColors.amber),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Amount: \$${widget.amount.toStringAsFixed(2)} USDT',
            style: GoogleFonts.rajdhani(fontSize: 16),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _walletController,
            style: GoogleFonts.inter(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Wallet Address (TRC20)',
              labelStyle: TextStyle(color: AppColors.textSecondary),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme.dart';
import '../../core/auth_service.dart';
import '../../core/socket_service.dart';
import '../game/game_engine.dart';

class TournamentGameScreen extends StatefulWidget {
  final String tournamentId;
  final String tournamentType;
  final double entryFee;
  final int maxPlayers;

  const TournamentGameScreen({
    super.key,
    required this.tournamentId,
    required this.tournamentType,
    required this.entryFee,
    required this.maxPlayers,
  });

  @override
  State<TournamentGameScreen> createState() => _TournamentGameScreenState();
}

class _TournamentGameScreenState extends State<TournamentGameScreen> {
  String _roomId = '';
  String _gameState = 'waiting';
  int _countdown = 5;
  List<dynamic> _players = [];
  Map<String, dynamic> _opponentData = {};
  late GameEngine _engine;
  Timer? _gameTimer;
  int _playTimeSeconds = 0;
  Map<String, dynamic>? _result;
  bool _isDesktop = false;

  @override
  void initState() {
    super.initState();
    _engine = GameEngine();
    _engine.initGame();
    _setupSocketListeners();
    _joinTournament();
  }

  @override
  void dispose() {
    _engine.dispose();
    _gameTimer?.cancel();
    super.dispose();
  }

  void _setupSocketListeners() {
    socketService.on('player_joined', (data) {
      if (mounted) {
        setState(() {
          _players = data['players'] ?? [];
          _roomId = data['roomId'] ?? '';
        });
      }
    });

    socketService.on('countdown', (data) {
      if (mounted) {
        setState(() {
          _countdown = data['seconds'] ?? 0;
          _gameState = 'countdown';
        });
      }
    });

    socketService.on('game_start', (data) {
      if (mounted) {
        setState(() {
          _gameState = 'playing';
          _players = data['players'] ?? [];
        });
        _engine.startGame();
        _startGameTimer();
      }
    });

    socketService.on('opponent_update', (data) {
      if (mounted) {
        setState(() {
          _opponentData = data;
        });
      }
    });

    socketService.on('player_finished', (data) {
      if (mounted) {
        setState(() {
          _opponentData = {
            ..._opponentData,
            'finished': true,
            'username': data['username'],
            'score': data['score'],
          };
        });
      }
    });

    socketService.on('game_result', (data) {
      if (mounted) {
        setState(() {
          _gameState = 'finished';
          _result = data;
        });
        _gameTimer?.cancel();
      }
    });

    socketService.on('error', (data) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Error')));
      }
    });
  }

  Future<void> _joinTournament() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    if (authService.userId == null) return;

    socketService.connect(authService.userId!);

    socketService.emit('join_tournament', {
      'userId': authService.userId,
      'tournamentId': widget.tournamentId,
      'tournamentType': widget.tournamentType,
      'entryFee': widget.entryFee,
      'maxPlayers': widget.maxPlayers,
    });
  }

  void _startGameTimer() {
    _gameTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _playTimeSeconds++;

      socketService.emit('game_update', {
        'userId': Provider.of<AuthService>(context, listen: false).userId,
        'roomId': _roomId,
        'score': _engine.score,
        'linesCleared': _engine.linesCleared,
        'level': _engine.level,
      });

      if (_engine.isGameOver) {
        _finishGame();
      }
    });
  }

  void _finishGame() {
    final authService = Provider.of<AuthService>(context, listen: false);
    socketService.emit('game_finished', {
      'userId': authService.userId,
      'roomId': _roomId,
      'score': _engine.score,
      'linesCleared': _engine.linesCleared,
      'level': _engine.level,
      'playTimeSeconds': _playTimeSeconds,
    });

    _engine.endGame();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _isDesktop = constraints.maxWidth > 900;
        return Scaffold(
          backgroundColor: AppColors.backgroundPrimary,
          body: _buildContent(),
        );
      },
    );
  }

  Widget _buildContent() {
    switch (_gameState) {
      case 'waiting':
        return _buildWaitingScreen();
      case 'countdown':
        return _buildCountdownScreen();
      case 'playing':
        return _buildGameScreen();
      case 'finished':
        return _buildResultScreen();
      default:
        return _buildWaitingScreen();
    }
  }

  Widget _buildWaitingScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.people_outline,
              size: 40,
              color: AppColors.amber,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'WAITING FOR PLAYERS',
            style: GoogleFonts.orbitron(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.amber,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_players.length} / ${widget.maxPlayers} players',
            style: GoogleFonts.rajdhani(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          ..._players.map(
            (p) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.neonGreen,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    p['username'] ?? 'Player',
                    style: GoogleFonts.inter(color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          const CircularProgressIndicator(color: AppColors.amber),
        ],
      ),
    );
  }

  Widget _buildCountdownScreen() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _countdown > 0 ? '$_countdown' : 'GO!',
            style: GoogleFonts.orbitron(
              fontSize: 120,
              fontWeight: FontWeight.bold,
              color: _countdown > 0 ? AppColors.amber : AppColors.neonGreen,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _countdown > 0 ? 'GET READY' : 'START MINING!',
            style: GoogleFonts.rajdhani(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.textSecondary,
              letterSpacing: 3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameScreen() {
    if (_isDesktop) {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  color: AppColors.backgroundSecondary,
                  child: Row(
                    children: [
                      Text(
                        'YOU',
                        style: GoogleFonts.rajdhani(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.cyan,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Score: ${_engine.score}',
                        style: GoogleFonts.orbitron(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.amber,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: _GameBoardWidget(engine: _engine)),
              ],
            ),
          ),
          Expanded(flex: 1, child: _buildOpponentPanel()),
        ],
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AppColors.backgroundSecondary,
          child: Row(
            children: [
              Text(
                'YOU',
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.cyan,
                ),
              ),
              const Spacer(),
              Text(
                '${_engine.score}',
                style: GoogleFonts.orbitron(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.amber,
                ),
              ),
            ],
          ),
        ),
        Expanded(flex: 2, child: _GameBoardWidget(engine: _engine)),
        Container(
          padding: const EdgeInsets.all(12),
          color: AppColors.backgroundSecondary,
          child: _buildOpponentPanel(),
        ),
      ],
    );
  }

  Widget _buildOpponentPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        border: Border(left: BorderSide(color: AppColors.backgroundTertiary)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OPPONENT',
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.textMuted,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 12),
          if (_opponentData.isNotEmpty) ...[
            Text(
              _opponentData['username'] ?? 'Waiting...',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Score: ${_opponentData['score'] ?? 0}',
              style: GoogleFonts.orbitron(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Lines: ${_opponentData['linesCleared'] ?? 0}',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            if (_opponentData['finished'] == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.neonGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'FINISHED',
                  style: GoogleFonts.rajdhani(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: AppColors.neonGreen,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ] else ...[
            Text(
              'Waiting...',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: AppColors.textMuted,
              ),
            ),
          ],
          const Spacer(),
          Text(
            'Time: ${_playTimeSeconds}s',
            style: GoogleFonts.rajdhani(
              fontSize: 12,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultScreen() {
    final placement = _result?['placement'] ?? 0;
    final prize = _result?['prize'] ?? 0.0;
    final score = _result?['score'] ?? 0;
    final leaderboard = _result?['leaderboard'] as List<dynamic>? ?? [];

    return Center(
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.backgroundSecondary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: AppColors.amber.withValues(alpha: 0.1),
              blurRadius: 40,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: placement == 1
                    ? AppColors.amber.withValues(alpha: 0.2)
                    : AppColors.backgroundTertiary,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '#$placement',
                  style: GoogleFonts.orbitron(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: placement == 1
                        ? AppColors.amber
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              placement == 1 ? 'VICTORY!' : 'GAME OVER',
              style: GoogleFonts.orbitron(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: placement == 1
                    ? AppColors.amber
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Score: $score',
              style: GoogleFonts.inter(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.neonGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.neonGreen.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Text(
                    'PRIZE',
                    style: GoogleFonts.rajdhani(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textMuted,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        AppColors.goldGradientStart,
                        AppColors.goldGradientEnd,
                      ],
                    ).createShader(bounds),
                    child: Text(
                      '\$${prize.toStringAsFixed(4)}',
                      style: GoogleFonts.orbitron(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Text(
                    'USDT',
                    style: GoogleFonts.rajdhani(
                      fontSize: 14,
                      color: AppColors.amber,
                    ),
                  ),
                ],
              ),
            ),
            if (leaderboard.isNotEmpty) ...[
              const SizedBox(height: 24),
              Text(
                'LEADERBOARD',
                style: GoogleFonts.rajdhani(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textMuted,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              ...leaderboard.map(
                (entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        '#${entry['placement']}',
                        style: GoogleFonts.rajdhani(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textMuted,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          entry['username'] ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Text(
                        '${entry['score']}',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.amber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '\$${double.tryParse(entry['prize']?.toString() ?? '0')?.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: AppColors.neonGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.backgroundPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'BACK TO TOURNAMENTS',
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
        final cellSize = (constraints.maxWidth / gridCols).clamp(
          12.0,
          constraints.maxHeight / gridRows,
        );
        return Center(
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.cyan, width: 2),
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

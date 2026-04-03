import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'models.dart';
import '../../core/api_service.dart';

enum GameStatus { idle, playing, paused, gameOver }

class GameState {
  final MiningGrid grid;
  final AssetPiece? currentPiece;
  final AssetPiece? nextPiece;
  final AssetPiece? holdPiece;
  final int currentX;
  final int currentY;
  final int ghostY;
  final int score;
  final int linesCleared;
  final int level;
  final GameStatus status;
  final String? sessionId;
  final int playTimeSeconds;
  final int combo;
  final int totalScore;
  final bool canHold;
  final bool isPerfectClear;
  final List<AssetPiece> pieceQueue;

  const GameState({
    required this.grid,
    this.currentPiece,
    this.nextPiece,
    this.holdPiece,
    this.currentX = 0,
    this.currentY = 0,
    this.ghostY = 0,
    this.score = 0,
    this.linesCleared = 0,
    this.level = 1,
    this.status = GameStatus.idle,
    this.sessionId,
    this.playTimeSeconds = 0,
    this.combo = 0,
    this.totalScore = 0,
    this.canHold = true,
    this.isPerfectClear = false,
    this.pieceQueue = const [],
  });

  GameState copyWith({
    MiningGrid? grid,
    AssetPiece? currentPiece,
    AssetPiece? nextPiece,
    AssetPiece? holdPiece,
    int? currentX,
    int? currentY,
    int? ghostY,
    int? score,
    int? linesCleared,
    int? level,
    GameStatus? status,
    String? sessionId,
    int? playTimeSeconds,
    int? combo,
    int? totalScore,
    bool? canHold,
    bool? isPerfectClear,
    List<AssetPiece>? pieceQueue,
  }) {
    return GameState(
      grid: grid ?? this.grid,
      currentPiece: currentPiece ?? this.currentPiece,
      nextPiece: nextPiece ?? this.nextPiece,
      holdPiece: holdPiece ?? this.holdPiece,
      currentX: currentX ?? this.currentX,
      currentY: currentY ?? this.currentY,
      ghostY: ghostY ?? this.ghostY,
      score: score ?? this.score,
      linesCleared: linesCleared ?? this.linesCleared,
      level: level ?? this.level,
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      playTimeSeconds: playTimeSeconds ?? this.playTimeSeconds,
      combo: combo ?? this.combo,
      totalScore: totalScore ?? this.totalScore,
      canHold: canHold ?? this.canHold,
      isPerfectClear: isPerfectClear ?? this.isPerfectClear,
      pieceQueue: pieceQueue ?? this.pieceQueue,
    );
  }
}

class GameController extends ChangeNotifier {
  final ApiService? _apiService;
  final String _userId;
  final Random _random = Random();

  GameState _state = GameState(grid: MiningGrid());
  Timer? _dropTimer;
  Timer? _playTimeTimer;
  int _dropInterval = dropIntervalMs;

  GameController({ApiService? apiService, required String userId})
    : _apiService = apiService,
      _userId = userId;

  GameState get state => _state;
  bool get isPlaying => _state.status == GameStatus.playing;
  bool get isGameOver => _state.status == GameStatus.gameOver;

  Future<void> startGame() async {
    debugPrint('Starting mining session...');

    final queue = _generatePieceQueue(5);
    debugPrint('Generated queue with ${queue.length} asset blocks');

    _state = GameState(
      grid: MiningGrid(),
      status: GameStatus.playing,
      pieceQueue: queue,
    );
    notifyListeners();

    try {
      if (_apiService != null) {
        debugPrint('Calling API to init session...');
        final response = await _apiService.initGameSession(_userId);
        debugPrint('API response: ${response.sessionId}');
        _state = _state.copyWith(sessionId: response.sessionId);
      }
    } catch (e) {
      debugPrint('API call failed (expected in mock mode): $e');
    }

    _spawnPiece();
    _startTimers();
    notifyListeners();
    debugPrint('Mining session started');
  }

  List<AssetPiece> _generatePieceQueue(int count) {
    return List.generate(
      count,
      (_) => AssetPool.random(_random.nextInt(AssetPool.pieces.length)),
    );
  }

  void _startTimers() {
    _playTimeTimer?.cancel();
    _playTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_state.status == GameStatus.playing) {
        _state = _state.copyWith(playTimeSeconds: _state.playTimeSeconds + 1);
        notifyListeners();
      }
    });

    _dropTimer?.cancel();
    _dropInterval = LevelConfig.fromLevel(_state.level).dropInterval;
    _dropTimer = Timer.periodic(Duration(milliseconds: _dropInterval), (_) {
      if (_state.status == GameStatus.playing) {
        _tick();
      }
    });
  }

  void _tick() {
    if (_moveDown()) {
      _updateGhostPosition();
      notifyListeners();
    }
  }

  void pauseGame() {
    if (_state.status == GameStatus.playing) {
      _state = _state.copyWith(status: GameStatus.paused);
      _dropTimer?.cancel();
      notifyListeners();
    }
  }

  void resumeGame() {
    if (_state.status == GameStatus.paused) {
      _state = _state.copyWith(status: GameStatus.playing);
      _startTimers();
      notifyListeners();
    }
  }

  void _spawnPiece() {
    if (_state.pieceQueue.isEmpty) {
      debugPrint('Queue is empty, generating new asset blocks');
    }

    final queue = List<AssetPiece>.from(_state.pieceQueue);
    if (queue.isEmpty) {
      queue.addAll(_generatePieceQueue(5));
    }

    final currentPiece = queue.removeAt(0);
    debugPrint(
      'Got asset: ${currentPiece.name}, shape: ${currentPiece.matrix}',
    );

    while (queue.length < 5) {
      queue.add(AssetPool.random(_random.nextInt(AssetPool.pieces.length)));
    }

    final nextPiece = queue.isNotEmpty ? queue.first : null;
    final startX = (gridWidth - currentPiece.width) ~/ 2;
    debugPrint('StartX: $startX, checking collision...');

    if (_checkCollision(currentPiece, startX, 0)) {
      debugPrint('Collision detected on spawn - game over');
      _gameOver();
      return;
    }

    _state = _state.copyWith(
      currentPiece: currentPiece,
      nextPiece: nextPiece,
      pieceQueue: queue,
      currentX: startX,
      currentY: 0,
      canHold: true,
    );
    debugPrint('Asset spawned at X=$startX, Y=0');

    _updateGhostPosition();
  }

  void _updateGhostPosition() {
    if (_state.currentPiece == null) return;

    int ghostY = _state.currentY;
    while (!_checkCollision(
      _state.currentPiece!,
      _state.currentX,
      ghostY + 1,
    )) {
      ghostY++;
      if (ghostY > gridHeight) break;
    }

    _state = _state.copyWith(ghostY: ghostY);
  }

  void _gameOver() {
    _dropTimer?.cancel();
    _playTimeTimer?.cancel();
    _state = _state.copyWith(status: GameStatus.gameOver);
    _syncGameOver();
    notifyListeners();
  }

  void resetGame() {
    _dropTimer?.cancel();
    _playTimeTimer?.cancel();
    _state = GameState(grid: MiningGrid(), status: GameStatus.idle);
    notifyListeners();
  }

  bool moveLeft() {
    if (_state.currentPiece == null) return false;
    if (!_checkCollision(
      _state.currentPiece!,
      _state.currentX - 1,
      _state.currentY,
    )) {
      _state = _state.copyWith(currentX: _state.currentX - 1);
      _updateGhostPosition();
      notifyListeners();
      return true;
    }
    return false;
  }

  bool moveRight() {
    if (_state.currentPiece == null) return false;
    if (!_checkCollision(
      _state.currentPiece!,
      _state.currentX + 1,
      _state.currentY,
    )) {
      _state = _state.copyWith(currentX: _state.currentX + 1);
      _updateGhostPosition();
      notifyListeners();
      return true;
    }
    return false;
  }

  bool _moveDown() {
    if (_state.currentPiece == null) return false;
    if (!_checkCollision(
      _state.currentPiece!,
      _state.currentX,
      _state.currentY + 1,
    )) {
      _state = _state.copyWith(currentY: _state.currentY + 1);
      return true;
    }
    _lockPiece();
    return false;
  }

  bool moveDown() => _moveDown();

  void hardDrop() {
    if (_state.currentPiece == null) return;
    int dropDistance = 0;
    while (!_checkCollision(
      _state.currentPiece!,
      _state.currentX,
      _state.currentY + 1,
    )) {
      _state = _state.copyWith(currentY: _state.currentY + 1);
      dropDistance++;
    }
    _state = _state.copyWith(score: _state.score + dropDistance * 2);
    _lockPiece();
    notifyListeners();
  }

  void softDrop() {
    if (_moveDown()) {
      _state = _state.copyWith(score: _state.score + 1);
      _updateGhostPosition();
      notifyListeners();
    }
  }

  void rotatePiece() {
    if (_state.currentPiece == null) return;

    final rotated = _state.currentPiece!.rotated();

    if (!_checkCollision(rotated, _state.currentX, _state.currentY)) {
      _state = _state.copyWith(currentPiece: rotated);
      _updateGhostPosition();
      notifyListeners();
      return;
    }

    final kickOffsets = [-1, 1, -2, 2];
    for (final offset in kickOffsets) {
      if (!_checkCollision(
        rotated,
        _state.currentX + offset,
        _state.currentY,
      )) {
        _state = _state.copyWith(
          currentPiece: rotated,
          currentX: _state.currentX + offset,
        );
        _updateGhostPosition();
        notifyListeners();
        return;
      }
    }
  }

  void holdPiece() {
    if (!_state.canHold || _state.currentPiece == null) return;

    final currentPiece = _state.currentPiece!;
    final holdPiece = _state.holdPiece;

    if (holdPiece == null) {
      _state = _state.copyWith(holdPiece: currentPiece, canHold: false);
      _spawnPieceFromQueue();
    } else {
      final startX = (gridWidth - holdPiece.width) ~/ 2;
      if (_checkCollision(holdPiece, startX, 0)) {
        return;
      }
      _state = _state.copyWith(
        currentPiece: holdPiece,
        holdPiece: currentPiece,
        currentX: startX,
        currentY: 0,
        canHold: false,
      );
      _updateGhostPosition();
    }
    notifyListeners();
  }

  void _spawnPieceFromQueue() {
    final queue = List<AssetPiece>.from(_state.pieceQueue);
    if (queue.isEmpty) {
      queue.addAll(_generatePieceQueue(5));
    }

    final currentPiece = queue.removeAt(0);
    while (queue.length < 5) {
      queue.add(AssetPool.random(_random.nextInt(AssetPool.pieces.length)));
    }

    final startX = (gridWidth - currentPiece.width) ~/ 2;
    if (_checkCollision(currentPiece, startX, 0)) {
      _gameOver();
      return;
    }

    _state = _state.copyWith(
      currentPiece: currentPiece,
      pieceQueue: queue,
      currentX: startX,
      currentY: 0,
    );
    _updateGhostPosition();
  }

  bool _checkCollision(AssetPiece piece, int newX, int newY) {
    final shape = piece.matrix;

    for (int row = 0; row < shape.length; row++) {
      for (int col = 0; col < shape[row].length; col++) {
        if (shape[row][col] == 1) {
          final boardX = newX + col;
          final boardY = newY + row;

          if (boardX < 0 || boardX >= gridWidth || boardY >= gridHeight) {
            return true;
          }

          if (boardY >= 0 && _state.grid.cells[boardY][boardX] != null) {
            return true;
          }
        }
      }
    }
    return false;
  }

  void _lockPiece() {
    if (_state.currentPiece == null) return;

    final newGrid = _state.grid.setPiece(
      _state.currentPiece!,
      _state.currentX,
      _state.currentY,
    );

    _state = _state.copyWith(grid: newGrid);
    _clearLines();

    if (_state.status == GameStatus.playing) {
      _spawnPieceFromQueue();
    }

    notifyListeners();
  }

  void _clearLines() {
    final fullLines = _state.grid.checkFullLines();

    if (fullLines.isEmpty) {
      _state = _state.copyWith(combo: 0);
      return;
    }

    final isPerfectClear = fullLines.length == gridHeight;
    final baseScores = [0, 100, 300, 500, 800, 1200, 1800, 2500];
    final linesBonus = fullLines.length <= 7
        ? baseScores[fullLines.length]
        : fullLines.length * 400;

    final newCombo = _state.combo + fullLines.length;
    final comboBonus = (newCombo * 50);
    final levelMultiplier = LevelConfig.fromLevel(_state.level).scoreMultiplier;

    final linesScore = ((linesBonus + comboBonus) * levelMultiplier).toInt();
    final newScore = _state.score + linesScore;
    final newTotalScore = _state.totalScore + linesScore;
    final newLines = _state.linesCleared + fullLines.length;
    final newLevel = (newLines ~/ 10) + 1;

    if (newLevel != _state.level) {
      _dropInterval = LevelConfig.fromLevel(newLevel).dropInterval;
      _dropTimer?.cancel();
      _dropTimer = Timer.periodic(Duration(milliseconds: _dropInterval), (_) {
        if (_state.status == GameStatus.playing) _tick();
      });
    }

    final clearedGrid = _state.grid.clearLines(fullLines);

    _state = _state.copyWith(
      grid: clearedGrid,
      score: newScore,
      totalScore: newTotalScore,
      linesCleared: newLines,
      level: newLevel,
      combo: newCombo,
      isPerfectClear: isPerfectClear,
    );

    _syncWithBackend(fullLines.length, linesScore);
  }

  Future<void> _syncWithBackend(int linesCleared, int score) async {
    if (_apiService == null || _state.sessionId == null) return;

    try {
      final response = await _apiService.submitGameResults(
        sessionId: _state.sessionId!,
        linesCleared: linesCleared,
        playTimeSeconds: _state.playTimeSeconds,
      );

      debugPrint(
        'Game synced: ${response.payout} USDT, valid: ${response.isValid}',
      );
    } catch (e) {
      debugPrint('Failed to sync game results: $e');
    }
  }

  Future<void> _syncGameOver() async {
    if (_apiService == null || _state.sessionId == null) return;

    try {
      await _apiService.submitGameResults(
        sessionId: _state.sessionId!,
        linesCleared: _state.linesCleared,
        playTimeSeconds: _state.playTimeSeconds,
      );
    } catch (e) {
      debugPrint('Failed to sync game over: $e');
    }
  }

  @override
  void dispose() {
    _dropTimer?.cancel();
    _playTimeTimer?.cancel();
    super.dispose();
  }
}

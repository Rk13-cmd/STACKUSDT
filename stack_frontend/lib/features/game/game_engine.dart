import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

const int gridRows = 30;
const int gridCols = 40;

enum BlockType {
  beam,
  cube,
  core,
  surge,
  fuse,
  hook,
  anchor,
  node,
  spike,
  whale,
  link,
  arch,
}

class AssetPiece {
  final BlockType type;
  final List<List<int>> matrix;
  final Color neonColor;
  final String name;

  const AssetPiece({
    required this.type,
    required this.matrix,
    required this.neonColor,
    required this.name,
  });
}

const List<AssetPiece> assetPool = [
  AssetPiece(
    type: BlockType.beam,
    name: 'THE BEAM',
    matrix: [
      [0, 0, 0, 0],
      [1, 1, 1, 1],
      [0, 0, 0, 0],
      [0, 0, 0, 0],
    ],
    neonColor: Color(0xFF00E5FF),
  ),
  AssetPiece(
    type: BlockType.cube,
    name: 'THE CUBE',
    matrix: [
      [1, 1],
      [1, 1],
    ],
    neonColor: Color(0xFFFFB800),
  ),
  AssetPiece(
    type: BlockType.core,
    name: 'THE CORE',
    matrix: [
      [0, 1, 0],
      [1, 1, 1],
      [0, 0, 0],
    ],
    neonColor: Color(0xFF9D00FF),
  ),
  AssetPiece(
    type: BlockType.surge,
    name: 'THE SURGE',
    matrix: [
      [0, 1, 1],
      [1, 1, 0],
      [0, 0, 0],
    ],
    neonColor: Color(0xFF39FF14),
  ),
  AssetPiece(
    type: BlockType.fuse,
    name: 'THE FUSE',
    matrix: [
      [1, 1, 0],
      [0, 1, 1],
      [0, 0, 0],
    ],
    neonColor: Color(0xFFFF073A),
  ),
  AssetPiece(
    type: BlockType.hook,
    name: 'THE HOOK',
    matrix: [
      [1, 0, 0],
      [1, 1, 1],
      [0, 0, 0],
    ],
    neonColor: Color(0xFF2196F3),
  ),
  AssetPiece(
    type: BlockType.anchor,
    name: 'THE ANCHOR',
    matrix: [
      [0, 0, 1],
      [1, 1, 1],
      [0, 0, 0],
    ],
    neonColor: Color(0xFFFF5722),
  ),
  AssetPiece(
    type: BlockType.node,
    name: 'THE NODE',
    matrix: [
      [0, 1, 0],
      [1, 1, 1],
      [0, 1, 0],
    ],
    neonColor: Color(0xFF00FFD4),
  ),
  AssetPiece(
    type: BlockType.spike,
    name: 'THE SPIKE',
    matrix: [
      [1, 0, 1],
      [0, 1, 0],
    ],
    neonColor: Color(0xFFFF1493),
  ),
  AssetPiece(
    type: BlockType.whale,
    name: 'THE WHALE',
    matrix: [
      [1, 1, 1],
      [1, 1, 1],
      [1, 1, 1],
    ],
    neonColor: Color(0xFFFFD700),
  ),
  AssetPiece(
    type: BlockType.link,
    name: 'THE LINK',
    matrix: [
      [1, 1],
    ],
    neonColor: Color(0xFF00FF88),
  ),
  AssetPiece(
    type: BlockType.arch,
    name: 'THE ARCH',
    matrix: [
      [1, 0, 1],
      [1, 1, 1],
    ],
    neonColor: Color(0xFFAA00FF),
  ),
];

class GameEngine extends ChangeNotifier {
  List<List<int>> _grid = [];
  List<List<Color>> _gridColors = [];
  List<List<int>>? _currentPiece;
  Color _currentColor = Colors.white;
  String _currentPieceName = '';
  int _currentRow = 0;
  int _currentCol = 0;
  int _score = 0;
  int _linesCleared = 0;
  int _level = 1;
  bool _isPlaying = false;
  bool _isGameOver = false;
  Timer? _dropTimer;
  int _combo = 0;
  List<List<int>>? _nextPiece;
  Color _nextColor = Colors.white;
  String _nextPieceName = '';
  final Random _random = Random();
  Ticker? _ticker;
  Color? _skinColor;

  List<List<int>> get grid => _grid;
  List<List<Color>> get gridColors => _gridColors;
  List<List<int>>? get currentPiece => _currentPiece;
  Color get currentColor => _currentColor;
  String get currentPieceName => _currentPieceName;
  int get currentRow => _currentRow;
  int get currentCol => _currentCol;
  int get score => _score;
  int get linesCleared => _linesCleared;
  int get level => _level;
  bool get isPlaying => _isPlaying;
  bool get isGameOver => _isGameOver;
  List<List<int>>? get nextPiece => _nextPiece;
  Color get nextColor => _nextColor;
  String get nextPieceName => _nextPieceName;
  int get combo => _combo;
  Color? get skinColor => _skinColor;

  void setSkinColor(Color? color) {
    _skinColor = color;
  }

  void initGame() {
    _grid = List.generate(gridRows, (_) => List.filled(gridCols, 0));
    _gridColors = List.generate(
      gridRows,
      (_) => List.filled(gridCols, Colors.transparent),
    );
    _score = 0;
    _linesCleared = 0;
    _level = 1;
    _isGameOver = false;
    _isPlaying = false;
    _combo = 0;
    _currentPiece = null;
    _nextPiece = null;
    _dropTimer?.cancel();
    _ticker?.stop();
    notifyListeners();
  }

  void startGame() {
    initGame();
    _isPlaying = true;
    _spawnPiece();
    _spawnNextPiece();
    _startDropTimer();
    notifyListeners();
  }

  void pauseGame() {
    _isPlaying = false;
    _dropTimer?.cancel();
    notifyListeners();
  }

  void resumeGame() {
    _isPlaying = true;
    _startDropTimer();
    notifyListeners();
  }

  void endGame() {
    _isPlaying = false;
    _isGameOver = true;
    _dropTimer?.cancel();
    notifyListeners();
  }

  void _startDropTimer() {
    _dropTimer?.cancel();
    final interval = Duration(milliseconds: max(100, 800 - (_level - 1) * 70));
    _dropTimer = Timer.periodic(interval, (_) {
      if (_isPlaying) {
        moveDown();
      }
    });
  }

  void _spawnPiece() {
    if (_nextPiece != null) {
      _currentPiece = _nextPiece;
      _currentColor = _nextColor;
      _currentPieceName = _nextPieceName;
      _spawnNextPiece();
    } else {
      final asset = assetPool[_random.nextInt(assetPool.length)];
      _currentPiece = asset.matrix.map((row) => List<int>.from(row)).toList();
      _currentColor = _skinColor ?? asset.neonColor;
      _currentPieceName = asset.name;
      _spawnNextPiece();
    }
    _currentRow = 0;
    _currentCol = (gridCols - _currentPiece![0].length) ~/ 2;

    if (!_isValidPosition(_currentPiece!, _currentRow, _currentCol)) {
      endGame();
    }
  }

  void _spawnNextPiece() {
    final asset = assetPool[_random.nextInt(assetPool.length)];
    _nextPiece = asset.matrix.map((row) => List<int>.from(row)).toList();
    _nextColor = _skinColor ?? asset.neonColor;
    _nextPieceName = asset.name;
  }

  bool _isValidPosition(List<List<int>> piece, int row, int col) {
    for (int r = 0; r < piece.length; r++) {
      for (int c = 0; c < piece[r].length; c++) {
        if (piece[r][c] == 1) {
          final newRow = row + r;
          final newCol = col + c;
          if (newRow < 0 ||
              newRow >= gridRows ||
              newCol < 0 ||
              newCol >= gridCols) {
            return false;
          }
          if (_grid[newRow][newCol] == 1) {
            return false;
          }
        }
      }
    }
    return true;
  }

  List<List<int>> _rotatePiece(List<List<int>> piece) {
    final rows = piece.length;
    final cols = piece[0].length;
    final rotated = List.generate(cols, (_) => List.filled(rows, 0));
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        rotated[c][rows - 1 - r] = piece[r][c];
      }
    }
    return rotated;
  }

  void moveLeft() {
    if (!_isPlaying || _currentPiece == null) return;
    if (_isValidPosition(_currentPiece!, _currentRow, _currentCol - 1)) {
      _currentCol--;
      notifyListeners();
    }
  }

  void moveRight() {
    if (!_isPlaying || _currentPiece == null) return;
    if (_isValidPosition(_currentPiece!, _currentRow, _currentCol + 1)) {
      _currentCol++;
      notifyListeners();
    }
  }

  void moveDown() {
    if (!_isPlaying || _currentPiece == null) return;
    if (_isValidPosition(_currentPiece!, _currentRow + 1, _currentCol)) {
      _currentRow++;
      notifyListeners();
    } else {
      _lockPiece();
    }
  }

  void rotate() {
    if (!_isPlaying || _currentPiece == null) return;
    final rotated = _rotatePiece(_currentPiece!);

    if (_isValidPosition(rotated, _currentRow, _currentCol)) {
      _currentPiece = rotated;
      notifyListeners();
      return;
    }

    final kicks = [-1, 1, -2, 2];
    for (final kick in kicks) {
      if (_isValidPosition(rotated, _currentRow, _currentCol + kick)) {
        _currentPiece = rotated;
        _currentCol += kick;
        notifyListeners();
        return;
      }
    }
  }

  void hardDrop() {
    if (!_isPlaying || _currentPiece == null) return;
    int dropDistance = 0;
    while (_isValidPosition(_currentPiece!, _currentRow + 1, _currentCol)) {
      _currentRow++;
      dropDistance++;
    }
    _score += dropDistance * 2;
    _lockPiece();
  }

  int getGhostRow() {
    if (_currentPiece == null) return _currentRow;
    int ghostRow = _currentRow;
    while (_isValidPosition(_currentPiece!, ghostRow + 1, _currentCol)) {
      ghostRow++;
    }
    return ghostRow;
  }

  void _lockPiece() {
    if (_currentPiece == null) return;

    for (int r = 0; r < _currentPiece!.length; r++) {
      for (int c = 0; c < _currentPiece![r].length; c++) {
        if (_currentPiece![r][c] == 1) {
          final boardRow = _currentRow + r;
          final boardCol = _currentCol + c;
          if (boardRow >= 0 &&
              boardRow < gridRows &&
              boardCol >= 0 &&
              boardCol < gridCols) {
            _grid[boardRow][boardCol] = 1;
            _gridColors[boardRow][boardCol] = _currentColor;
          }
        }
      }
    }

    int linesCleared = 0;
    for (int r = gridRows - 1; r >= 0; r--) {
      if (_grid[r].every((cell) => cell == 1)) {
        _grid.removeAt(r);
        _gridColors.removeAt(r);
        _grid.insert(0, List.filled(gridCols, 0));
        _gridColors.insert(0, List.filled(gridCols, Colors.transparent));
        linesCleared++;
        r++;
      }
    }

    if (linesCleared > 0) {
      _combo++;
      final lineScores = [0, 100, 300, 500, 800];
      int baseScore = linesCleared <= 4
          ? lineScores[linesCleared]
          : linesCleared * 200;
      _score += baseScore * _level + (_combo > 1 ? _combo * 50 : 0);
      _linesCleared += linesCleared;
      _level = (_linesCleared ~/ 10) + 1;
      _startDropTimer();
    } else {
      _combo = 0;
    }

    _spawnPiece();
    notifyListeners();
  }

  @override
  void dispose() {
    _dropTimer?.cancel();
    _ticker?.stop();
    super.dispose();
  }
}

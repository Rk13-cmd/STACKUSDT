import 'dart:math';
import 'package:flutter/material.dart';

const int gridWidth = 40;
const int gridHeight = 30;
const int dropIntervalMs = 800;
const int softDropIntervalMs = 50;
const int ghostDropIntervalMs = 16;

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
  final Color glowColor;
  final String name;

  const AssetPiece({
    required this.type,
    required this.matrix,
    required this.neonColor,
    required this.glowColor,
    required this.name,
  });

  AssetPiece rotated() {
    final rows = matrix.length;
    final cols = matrix[0].length;
    final rotated = List.generate(
      cols,
      (i) => List.generate(rows, (j) => matrix[rows - 1 - j][i]),
    );
    return AssetPiece(
      type: type,
      matrix: rotated,
      neonColor: neonColor,
      glowColor: glowColor,
      name: name,
    );
  }

  AssetPiece copyWith({List<List<int>>? matrix}) {
    return AssetPiece(
      type: type,
      matrix: matrix ?? this.matrix,
      neonColor: neonColor,
      glowColor: glowColor,
      name: name,
    );
  }

  int get width => matrix[0].length;
  int get height => matrix.length;
}

class AssetPool {
  static const List<AssetPiece> pieces = [
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
      glowColor: Color(0x6000E5FF),
    ),
    AssetPiece(
      type: BlockType.cube,
      name: 'THE CUBE',
      matrix: [
        [1, 1],
        [1, 1],
      ],
      neonColor: Color(0xFFFFB800),
      glowColor: Color(0x60FFB800),
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
      glowColor: Color(0x609D00FF),
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
      glowColor: Color(0x6039FF14),
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
      glowColor: Color(0x60FF073A),
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
      glowColor: Color(0x602196F3),
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
      glowColor: Color(0x60FF5722),
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
      glowColor: Color(0x6000FFD4),
    ),
    AssetPiece(
      type: BlockType.spike,
      name: 'THE SPIKE',
      matrix: [
        [1, 0, 1],
        [0, 1, 0],
      ],
      neonColor: Color(0xFFFF1493),
      glowColor: Color(0x60FF1493),
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
      glowColor: Color(0x60FFD700),
    ),
    AssetPiece(
      type: BlockType.link,
      name: 'THE LINK',
      matrix: [
        [1, 1],
      ],
      neonColor: Color(0xFF00FF88),
      glowColor: Color(0x6000FF88),
    ),
    AssetPiece(
      type: BlockType.arch,
      name: 'THE ARCH',
      matrix: [
        [1, 0, 1],
        [1, 1, 1],
      ],
      neonColor: Color(0xFFAA00FF),
      glowColor: Color(0x60AA00FF),
    ),
  ];

  static final Random _random = Random();

  static AssetPiece random([int? seed]) {
    final index = seed ?? _random.nextInt(pieces.length);
    return pieces[index % pieces.length];
  }
}

class MiningGrid {
  final List<List<int?>> cells;

  MiningGrid({List<List<int?>>? cells}) : cells = cells ?? _createEmpty();

  static List<List<int?>> _createEmpty() {
    return List.generate(
      gridHeight,
      (_) => List.generate(gridWidth, (_) => null),
    );
  }

  MiningGrid copyWith({List<List<int?>>? cells}) {
    return MiningGrid(cells: cells ?? _copyCells(this.cells));
  }

  static List<List<int?>> _copyCells(List<List<int?>> original) {
    return original.map((row) => List<int?>.from(row)).toList();
  }

  bool isCellOccupied(int x, int y) {
    if (x < 0 || x >= gridWidth || y < 0 || y >= gridHeight) {
      return true;
    }
    return cells[y][x] != null;
  }

  MiningGrid setPiece(AssetPiece piece, int offsetX, int offsetY) {
    final newCells = _copyCells(cells);
    final shape = piece.matrix;

    for (int row = 0; row < shape.length; row++) {
      for (int col = 0; col < shape[row].length; col++) {
        if (shape[row][col] == 1) {
          final x = offsetX + col;
          final y = offsetY + row;
          if (y >= 0 && y < gridHeight && x >= 0 && x < gridWidth) {
            newCells[y][x] = piece.neonColor.toARGB32();
          }
        }
      }
    }
    return MiningGrid(cells: newCells);
  }

  List<int> checkFullLines() {
    final fullLines = <int>[];
    for (int y = 0; y < gridHeight; y++) {
      if (cells[y].every((cell) => cell != null)) {
        fullLines.add(y);
      }
    }
    return fullLines;
  }

  MiningGrid clearLines(List<int> lines) {
    if (lines.isEmpty) return this;

    final newCells = <List<int?>>[];
    for (int y = 0; y < gridHeight; y++) {
      if (!lines.contains(y)) {
        newCells.add(List<int?>.from(cells[y]));
      }
    }

    while (newCells.length < gridHeight) {
      newCells.insert(0, List.generate(gridWidth, (_) => null));
    }

    return MiningGrid(cells: newCells);
  }
}

extension ColorExtension on Color {
  int toARGB32() {
    return (a.toInt() << 24) | (r.toInt() << 16) | (g.toInt() << 8) | b.toInt();
  }
}

class ComboSystem {
  final int consecutiveClears;
  final int comboMultiplier;
  final bool isPerfectClear;

  const ComboSystem({
    this.consecutiveClears = 0,
    this.comboMultiplier = 1,
    this.isPerfectClear = false,
  });

  int calculateScore(int baseScore, int linesCleared) {
    int score = baseScore * comboMultiplier;
    if (isPerfectClear) {
      score += 1000 * linesCleared;
    }
    return score;
  }

  ComboSystem addClear(int lines) {
    return ComboSystem(
      consecutiveClears: consecutiveClears + 1,
      comboMultiplier: (comboMultiplier + (lines > 1 ? lines : 0)).clamp(1, 12),
      isPerfectClear: false,
    );
  }

  ComboSystem reset() {
    return const ComboSystem();
  }
}

class LevelConfig {
  final int level;
  final int dropInterval;
  final int linesPerLevel;
  final double scoreMultiplier;

  const LevelConfig({
    required this.level,
    required this.dropInterval,
    required this.linesPerLevel,
    required this.scoreMultiplier,
  });

  static LevelConfig fromLevel(int level) {
    final dropInterval = (800 * (1 - (level - 1) * 0.07))
        .clamp(100, 800)
        .toInt();
    return LevelConfig(
      level: level,
      dropInterval: dropInterval,
      linesPerLevel: level * 10,
      scoreMultiplier: 1 + (level - 1) * 0.1,
    );
  }
}

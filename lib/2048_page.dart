import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Game2048Page extends StatefulWidget {
  const Game2048Page({super.key});

  @override
  State<Game2048Page> createState() => _Game2048PageState();
}

class MoveResult {
  final List<int> line;
  final bool moved;
  final int score;

  MoveResult(this.line, this.moved, this.score);
}

class _Game2048PageState extends State<Game2048Page> {
  static const int gridSize = 4;
  List<List<int>> grid = [];
  List<List<int>> prevGrid = [];
  int score = 0;
  int prevScore = 0;
  int highScore = 0;
  bool gameOver = false;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _initGrid();
    spawn();
  }

  void _initGrid() {
    grid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
    prevGrid = List.generate(gridSize, (_) => List.filled(gridSize, 0));
  }

  List<List<int>> _copyGrid(List<List<int>> source) {
    return source.map((row) => List<int>.from(row)).toList();
  }

  void restart() {
    setState(() {
      _initGrid();
      score = 0;
      prevScore = 0;
      gameOver = false;
      spawn();
    });
  }

  void undo() {
    setState(() {
      grid = _copyGrid(prevGrid);
      score = prevScore;
      gameOver = false;
    });
  }

  void spawn() {
    List<Point<int>> emptySpots = [];
    for (int y = 0; y < gridSize; y++) {
      for (int x = 0; x < gridSize; x++) {
        if (grid[y][x] == 0) {
          emptySpots.add(Point(x, y));
        }
      }
    }
    if (emptySpots.isNotEmpty) {
      Point<int> spot = emptySpots[_random.nextInt(emptySpots.length)];
      grid[spot.y][spot.x] = _random.nextDouble() < 0.9 ? 2 : 4;
    }
  }

  void move(int dy, int dx) {
    if (gameOver) return;

    List<List<int>> newGrid = _copyGrid(grid);
    bool moved = false;
    int moveScore = 0;

    if (dx != 0) {
      for (int r = 0; r < gridSize; r++) {
        var result = _processLine(newGrid[r], dx > 0);
        newGrid[r] = result.line;
        if (result.moved) moved = true;
        moveScore += result.score;
      }
    } else if (dy != 0) {
      for (int c = 0; c < gridSize; c++) {
        List<int> col = [
          newGrid[0][c],
          newGrid[1][c],
          newGrid[2][c],
          newGrid[3][c]
        ];
        var result = _processLine(col, dy > 0);
        if (result.moved) moved = true;
        moveScore += result.score;
        for (int r = 0; r < gridSize; r++) {
          newGrid[r][c] = result.line[r];
        }
      }
    }

    if (moved) {
      setState(() {
        prevGrid = _copyGrid(grid);
        prevScore = score;
        grid = newGrid;
        score += moveScore;
        if (score > highScore) highScore = score;
        spawn();
        checkGameOver();
      });
    }
  }

  MoveResult _processLine(List<int> line, bool reverse) {
    List<int> working = List.from(line);
    if (reverse) working = List.from(working.reversed);

    List<int> nonZeros = working.where((e) => e != 0).toList();
    List<int> merged = [];
    int score = 0;

    int i = 0;
    while (i < nonZeros.length) {
      if (i + 1 < nonZeros.length && nonZeros[i] == nonZeros[i + 1]) {
        merged.add(nonZeros[i] * 2);
        score += nonZeros[i] * 2;
        i += 2;
      } else {
        merged.add(nonZeros[i]);
        i++;
      }
    }

    while (merged.length < 4) {
      merged.add(0);
    }

    if (reverse) merged = List.from(merged.reversed);

    bool moved = false;
    for (int k = 0; k < 4; k++) {
      if (merged[k] != line[k]) {
        moved = true;
        break;
      }
    }

    return MoveResult(merged, moved, score);
  }

  void checkGameOver() {
    if (canMove(0, 1) || canMove(0, -1) || canMove(1, 0) || canMove(-1, 0)) {
      return;
    }
    setState(() {
      gameOver = true;
    });
  }

  bool canMove(int dy, int dx) {
    List<List<int>> tempGrid = _copyGrid(grid);
    if (dx != 0) {
      for (int r = 0; r < gridSize; r++) {
        if (_processLine(tempGrid[r], dx > 0).moved) return true;
      }
    } else if (dy != 0) {
      for (int c = 0; c < gridSize; c++) {
        List<int> col = [
          tempGrid[0][c],
          tempGrid[1][c],
          tempGrid[2][c],
          tempGrid[3][c]
        ];
        if (_processLine(col, dy > 0).moved) return true;
      }
    }
    return false;
  }

  Color getTileColor(int value) {
    switch (value) {
      case 2: return const Color(0xFFEEE4DA);
      case 4: return const Color(0xFFEDE0C8);
      case 8: return const Color(0xFFF2B179);
      case 16: return const Color(0xFFF59563);
      case 32: return const Color(0xFFF67C5F);
      case 64: return const Color(0xFFF65E3B);
      case 128: return const Color(0xFFEDCF72);
      case 256: return const Color(0xFFEDCC61);
      case 512: return const Color(0xFFEDC850);
      case 1024: return const Color(0xFFEDC53F);
      case 2048: return const Color(0xFFEDC22E);
      default: return const Color(0xFFCDC1B4);
    }
  }

  Color getTextColor(int value) {
    return (value == 2 || value == 4) ? const Color(0xFF776E65) : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF8EF),
      body: Center(
        child: FittedBox(
          child: Container(
          width: 600,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '2048',
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF776E65),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Score: $score',
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'High Score: $highScore',
                        style: const TextStyle(
                            fontSize: 16, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: undo,
                    child: const Text('Undo'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: restart,
                    child: const Text('Restart'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              FocusableActionDetector(
                autofocus: true,
                actions: {
                  MoveIntent: CallbackAction<MoveIntent>(
                    onInvoke: (MoveIntent intent) {
                      move(intent.dy, intent.dx);
                      return null;
                    },
                  ),
                },
                shortcuts: {
                  LogicalKeySet(LogicalKeyboardKey.arrowUp): MoveIntent(-1, 0),
                  LogicalKeySet(LogicalKeyboardKey.arrowDown): MoveIntent(1, 0),
                  LogicalKeySet(LogicalKeyboardKey.arrowLeft): MoveIntent(0, -1),
                  LogicalKeySet(LogicalKeyboardKey.arrowRight): MoveIntent(0, 1),
                },
                child:
              GestureDetector(
                onVerticalDragEnd: (details) {
                  if (details.primaryVelocity! < 0) {
                    move(-1, 0); // Up
                  } else if (details.primaryVelocity! > 0) {
                    move(1, 0); // Down
                  }
                },
                onHorizontalDragEnd: (details) {
                  if (details.primaryVelocity! < 0) {
                    move(0, -1); // Left
                  } else if (details.primaryVelocity! > 0) {
                    move(0, 1); // Right
                  }
                },
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Container(
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: const Color(0xFFBBADA0),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: Stack(
                      children: [
                        GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            mainAxisSpacing: 8.0,
                            crossAxisSpacing: 8.0,
                          ),
                          itemCount: 16,
                          itemBuilder: (context, index) {
                            int x = index % 4;
                            int y = index ~/ 4;
                            int value = grid[y][x];
                            return Container(
                              decoration: BoxDecoration(
                                color: value == 0
                                    ? const Color(0x88CDC1B4)
                                    : getTileColor(value),
                                borderRadius: BorderRadius.circular(4.0),
                              ),
                              child: Center(
                                child: value == 0
                                    ? null
                                    : Text(
                                        '$value',
                                        style: TextStyle(
                                          fontSize: value > 1000 ? 24 : 32,
                                          fontWeight: FontWeight.bold,
                                          color: getTextColor(value),
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                        if (gameOver)
                          Container(
                            color: Colors.white54,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Game Over',
                                    style: TextStyle(
                                      fontSize: 40,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF776E65),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: restart,
                                    child: const Text('Try Again'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}

class MoveIntent extends Intent {
  const MoveIntent(this.dy, this.dx);

  final int dy;
  final int dx;
}
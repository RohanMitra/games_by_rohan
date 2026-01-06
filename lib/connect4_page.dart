import 'dart:math';
import 'package:flutter/material.dart';

class Connect4Page extends StatefulWidget {
  const Connect4Page({super.key});

  @override
  State<Connect4Page> createState() => _Connect4PageState();
}

class _Connect4PageState extends State<Connect4Page> {
  static const int rows = 6;
  static const int cols = 7;
  late List<List<int>> board;
  int player = 1; // 1 = Red, 2 = Green
  bool gameOver = false;
  int winner = 0; // 0 = none, 1 = Red, 2 = Green, -1 = Draw
  bool isAI = false;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    board = List.generate(rows, (_) => List.filled(cols, 0));
    player = 1;
    gameOver = false;
    winner = 0;
    setState(() {});
  }

  void _dropPiece(int col) {
    if (gameOver) return;
    if (isAI && player == 2) return;

    int r = _getNextOpenRow(col);

    if (r != -1) {
      _makeMoveAndCheck(r, col);
    }
  }

  int _getNextOpenRow(int col) {
    for (int i = rows - 1; i >= 0; i--) {
      if (board[i][col] == 0) return i;
    }
    return -1;
  }

  void _makeMoveAndCheck(int r, int c) {
    setState(() {
      board[r][c] = player;
      if (_checkWin()) {
        gameOver = true;
        winner = player;
      } else if (_isFull()) {
        gameOver = true;
        winner = -1;
      } else {
        player = player == 1 ? 2 : 1;
      }
    });

    if (isAI && player == 2 && !gameOver) {
      _aiMove();
    }
  }

  void _aiMove() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted || gameOver) return;

    int bestScore = -1000000;
    int bestCol = -1;

    List<int> validCols = [];
    for (int c = 0; c < cols; c++) {
      if (board[0][c] == 0) validCols.add(c);
    }
    validCols.shuffle();

    for (int col in validCols) {
      int row = _getNextOpenRow(col);
      board[row][col] = 2;
      int score = _minimax(4, -1000000, 1000000, false);
      board[row][col] = 0;

      if (score > bestScore) {
        bestScore = score;
        bestCol = col;
      }
    }

    if (bestCol != -1) {
      int r = _getNextOpenRow(bestCol);
      _makeMoveAndCheck(r, bestCol);
    }
  }

  int _minimax(int depth, int alpha, int beta, bool maximizingPlayer) {
    if (_checkWin()) {
      return maximizingPlayer ? -1000000 : 1000000;
    }
    if (_isFull()) return 0;
    if (depth == 0) return _evaluateBoard(2);

    if (maximizingPlayer) {
      int maxEval = -1000000;
      for (int c = 0; c < cols; c++) {
        int r = _getNextOpenRow(c);
        if (r != -1) {
          board[r][c] = 2;
          int eval = _minimax(depth - 1, alpha, beta, false);
          board[r][c] = 0;
          maxEval = max(maxEval, eval);
          alpha = max(alpha, eval);
          if (beta <= alpha) break;
        }
      }
      return maxEval;
    } else {
      int minEval = 1000000;
      for (int c = 0; c < cols; c++) {
        int r = _getNextOpenRow(c);
        if (r != -1) {
          board[r][c] = 1;
          int eval = _minimax(depth - 1, alpha, beta, true);
          board[r][c] = 0;
          minEval = min(minEval, eval);
          beta = min(beta, eval);
          if (beta <= alpha) break;
        }
      }
      return minEval;
    }
  }

  int _evaluateBoard(int piece) {
    int score = 0;
    // Center column preference
    for (int r = 0; r < rows; r++) {
      if (board[r][cols ~/ 2] == piece) score += 3;
    }

    // Horizontal
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols - 3; c++) {
        score += _evaluateWindow([board[r][c], board[r][c + 1], board[r][c + 2], board[r][c + 3]], piece);
      }
    }
    // Vertical
    for (int c = 0; c < cols; c++) {
      for (int r = 0; r < rows - 3; r++) {
        score += _evaluateWindow([board[r][c], board[r + 1][c], board[r + 2][c], board[r + 3][c]], piece);
      }
    }
    // Diagonals
    for (int r = 0; r < rows - 3; r++) {
      for (int c = 0; c < cols - 3; c++) {
        score += _evaluateWindow([board[r][c], board[r + 1][c + 1], board[r + 2][c + 2], board[r + 3][c + 3]], piece);
      }
    }
    for (int r = 0; r < rows - 3; r++) {
      for (int c = 0; c < cols - 3; c++) {
        score += _evaluateWindow([board[r + 3][c], board[r + 2][c + 1], board[r + 1][c + 2], board[r][c + 3]], piece);
      }
    }
    return score;
  }

  int _evaluateWindow(List<int> window, int piece) {
    int score = 0;
    int oppPiece = piece == 1 ? 2 : 1;
    int countPiece = window.where((p) => p == piece).length;
    int countEmpty = window.where((p) => p == 0).length;
    int countOpp = window.where((p) => p == oppPiece).length;

    if (countPiece == 4) {
      score += 100;
    } else if (countPiece == 3 && countEmpty == 1) {
      score += 5;
    } else if (countPiece == 2 && countEmpty == 2) {
      score += 2;
    }

    if (countOpp == 3 && countEmpty == 1) score -= 4;

    return score;
  }

  bool _isFull() {
    for (int c = 0; c < cols; c++) {
      if (board[0][c] == 0) return false;
    }
    return true;
  }

  // Logic ported from connect4.java getWinner()
  bool _checkWin() {
    // Horizontal
    for (int y = 0; y < rows; y++) {
      for (int x = 0; x <= cols - 4; x++) {
        int p = board[y][x];
        if (p != 0 && p == board[y][x+1] && p == board[y][x+2] && p == board[y][x+3]) return true;
      }
    }
    // Vertical
    for (int y = 0; y <= rows - 4; y++) {
      for (int x = 0; x < cols; x++) {
        int p = board[y][x];
        if (p != 0 && p == board[y+1][x] && p == board[y+2][x] && p == board[y+3][x]) return true;
      }
    }
    // Diagonal (Down-Right)
    for (int y = 0; y <= rows - 4; y++) {
      for (int x = 0; x <= cols - 4; x++) {
        int p = board[y][x];
        if (p != 0 && p == board[y+1][x+1] && p == board[y+2][x+2] && p == board[y+3][x+3]) return true;
      }
    }
    // Diagonal (Up-Right)
    for (int y = 3; y < rows; y++) {
      for (int x = 0; x <= cols - 4; x++) {
        int p = board[y][x];
        if (p != 0 && p == board[y-1][x+1] && p == board[y-2][x+2] && p == board[y-3][x+3]) return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    String status = gameOver 
      ? (winner == -1 ? "Draw!" : "Player ${winner == 1 ? "Red" : "Green"} Wins!") 
      : "Player ${player == 1 ? "Red" : "Green"}'s Turn";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect 4'),
        backgroundColor: colorScheme.inversePrimary,
        actions: [
          Row(children: [
            const Text("AI"),
            Switch(value: isAI, onChanged: (v) => setState(() {
              isAI = v;
              _resetGame();
            })),
          ]),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _resetGame),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(status, style: Theme.of(context).textTheme.headlineSmall),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 7 / 6,
                child: Container(
                  color: Colors.blue[800],
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: List.generate(cols, (c) {
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => _dropPiece(c),
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            children: List.generate(rows, (r) {
                              return Expanded(
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: board[r][c] == 0 
                                      ? Colors.white 
                                      : (board[r][c] == 1 ? Colors.red : Colors.green),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
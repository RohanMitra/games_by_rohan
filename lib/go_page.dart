import 'dart:math';
import 'package:flutter/material.dart';

class GoPage extends StatefulWidget {
  const GoPage({super.key});

  @override
  State<GoPage> createState() => GoPageState();
}

class GoPageState extends State<GoPage> {
  static const int boardSize = 19;
  static const int empty = 0;
  static const int black = 1;
  static const int white = 2;

  late List<List<int>> boardState;
  // History states for Ko checks
  late List<List<int>> kb; // State after Black's turn
  late List<List<int>> kw; // State after White's turn

  // Helper for recursion
  late List<List<bool>> libsChecked;

  int turn = 0; // Even = Black, Odd = White
  int blackCaptures = 0;
  int whiteCaptures = 0;
  bool gameOver = false;
  bool passed = false;
  bool isAI = false;
  int? lastMoveRow;
  int? lastMoveCol;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    boardState = List.generate(boardSize, (_) => List.filled(boardSize, empty));
    kb = List.generate(boardSize, (_) => List.filled(boardSize, empty));
    kw = List.generate(boardSize, (_) => List.filled(boardSize, empty));
    libsChecked = List.generate(boardSize, (_) => List.filled(boardSize, false));
    
    turn = 0;
    blackCaptures = 0;
    whiteCaptures = 0;
    gameOver = false;
    passed = false;
    lastMoveRow = null;
    lastMoveCol = null;
    setState(() {});
  }

  void _passTurn() {
    if (gameOver) {
      _resetGame();
      return;
    }
    
    if (passed) {
      setState(() {
        gameOver = true;
      });
    } else {
      setState(() {
        passed = true;
        turn++;
      });
    }
  }

  void _onIntersectionTap(int r, int c) {
    if (gameOver) return;
    if (isAI && turn % 2 != 0) return; // AI's turn (White)

    int player = (turn % 2 == 0) ? black : white;
    _executeMove(player, r, c);
  }

  void _executeMove(int player, int r, int c) {
    int captures = _makeMove(boardState, player, r, c, checkKo: true);
    if (captures != -1) {
      setState(() {
        if (player == black) {
          blackCaptures += captures;
          _copyBoard(boardState, kb);
        } else {
          whiteCaptures += captures;
          _copyBoard(boardState, kw);
        }
        turn++;
        passed = false;
        lastMoveRow = r;
        lastMoveCol = c;

        if (!gameOver && isAI && turn % 2 != 0) {
          _aiMove();
        }
      });
    }
  }

  // Logic ported from baduk.java
  // Refactored to take board as argument for AI simulations
  int _makeMove(List<List<int>> board, int p, int x, int y, {bool checkKo = false}) {
    if (board[x][y] != empty) return -1;

    int p2 = (p == black) ? white : black;

    // Place stone
    board[x][y] = p;

    int captures = 0;

    // Check suicide
    if (_countLiberties(board, p, x, y) == 0) {
      // Save state before potential captures for Ko/Revert
      // In baduk.java, koBoard is used to restore state if move is invalid.
      // koBoard is essentially the board BEFORE the move (stone placed then removed).
      // But here we need to capture the state WITH the opponents to restore if needed.
      var backupBoard = List.generate(boardSize, (i) => List<int>.from(board[i]));
      backupBoard[x][y] = empty; // The state before we placed the stone

      // Check neighbors for captures
      if (x > 0 && _countLiberties(board, p2, x - 1, y) == 0) captures += _clearGroup(board, p2, x - 1, y);
      if (x < boardSize - 1 && _countLiberties(board, p2, x + 1, y) == 0) captures += _clearGroup(board, p2, x + 1, y);
      if (y > 0 && _countLiberties(board, p2, x, y - 1) == 0) captures += _clearGroup(board, p2, x, y - 1);
      if (y < boardSize - 1 && _countLiberties(board, p2, x, y + 1) == 0) captures += _clearGroup(board, p2, x, y + 1);

      // Ko check
      if (checkKo && (!_different(board, kb) || !_different(board, kw))) {
        // Illegal Ko - Restore board
        for(int i=0; i<boardSize; i++) {
          for(int j=0; j<boardSize; j++) {
            boardState[i][j] = backupBoard[i][j];
          }
        }
        return -1;
      }

      if (captures > 0) {
        return captures;
      } else {
        // Suicide - Illegal
        board[x][y] = empty;
        return -1;
      }
    } else {
      // Not suicide, check for normal captures
      if (x > 0 && _countLiberties(board, p2, x - 1, y) == 0) captures += _clearGroup(board, p2, x - 1, y);
      if (x < boardSize - 1 && _countLiberties(board, p2, x + 1, y) == 0) captures += _clearGroup(board, p2, x + 1, y);
      if (y > 0 && _countLiberties(board, p2, x, y - 1) == 0) captures += _clearGroup(board, p2, x, y - 1);
      if (y < boardSize - 1 && _countLiberties(board, p2, x, y + 1) == 0) captures += _clearGroup(board, p2, x, y + 1);
      
      return captures;
    }
  }

  int _countLiberties(List<List<int>> board, int p, int x, int y) {
    var visited = List.generate(boardSize, (_) => List.filled(boardSize, false));
    return _countLibertiesInternally(board, visited, p, x, y);
  }

  int _countLibertiesInternally(List<List<int>> board, List<List<bool>> visited, int p, int x, int y) {
    if (x < 0 || x >= boardSize || y < 0 || y >= boardSize) return 0;
    if (visited[x][y]) return 0;
    
    visited[x][y] = true;
    
    if (board[x][y] == empty) {
      return 1;
    } else if (board[x][y] == p) {
      return _countLibertiesInternally(board, visited, p, x + 1, y) +
             _countLibertiesInternally(board, visited, p, x - 1, y) +
             _countLibertiesInternally(board, visited, p, x, y + 1) +
             _countLibertiesInternally(board, visited, p, x, y - 1);
    }
    return 0;
  }

  int _clearGroup(List<List<int>> board, int p, int x, int y) {
    var visited = List.generate(boardSize, (_) => List.filled(boardSize, false));
    return _clearGroupInternally(board, visited, p, x, y);
  }

  int _clearGroupInternally(List<List<int>> board, List<List<bool>> visited, int p, int x, int y) {
    if (x < 0 || x >= boardSize || y < 0 || y >= boardSize) return 0;
    if (board[x][y] != p) return 0;
    if (visited[x][y]) return 0;

    board[x][y] = empty;
    visited[x][y] = true;

    int captures = 1;
    captures += _clearGroupInternally(board, visited, p, x + 1, y);
    captures += _clearGroupInternally(board, visited, p, x - 1, y);
    captures += _clearGroupInternally(board, visited, p, x, y + 1);
    captures += _clearGroupInternally(board, visited, p, x, y - 1);
    return captures;
  }

  // --- AI Logic (MCTS) ---

  void _aiMove() async {
    // Yield to UI
    await Future.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;

    // Root Node
    MctsNode root = MctsNode(
      board: List.generate(boardSize, (i) => List.from(boardState[i])),
      playerToMove: white,
      move: null,
      parent: null,
    );

    int iterations = 100; // Keep low for responsiveness
    int maxDepth = 20; // Limit rollout depth

    while (iterations > 0) {
      // 1. Selection
      MctsNode node = root;
      while (node.untriedMoves.isEmpty && node.children.isNotEmpty) {
        node = node.selectChild();
      }

      // 2. Expansion
      if (node.untriedMoves.isNotEmpty) {
        node = node.expand(this);
      }

      // 3. Simulation
      int winner = node.simulate(this, maxDepth);

      // 4. Backpropagation
      node.backpropagate(winner);

      iterations--;
    }

    MctsNode? best = root.bestChild();
    if (best != null && best.move != null) {
      _executeMove(white, best.move!.x, best.move!.y);
    } else {
      _passTurn();
    }
  }

  bool _different(List<List<int>> b, List<List<int>> k) {
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        if (b[i][j] != k[i][j]) return true;
      }
    }
    return false;
  }

  void _copyBoard(List<List<int>> src, List<List<int>> dest) {
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        dest[i][j] = src[i][j];
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.inversePrimary,
        title: Text('Go (Baduk) - ${turn % 2 == 0 ? "Black" : "White"}\'s Turn'),
        actions: [
          Row(children: [Text("AI"), Switch(value: isAI, onChanged: (v) => setState(() => isAI = v))]),
          TextButton(
            onPressed: _passTurn,
            child: Text(gameOver ? "RESTART" : "PASS", style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(children: [
                  Text("Black Captures", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("$blackCaptures", style: TextStyle(fontSize: 24)),
                ]),
                if (gameOver) 
                  Text("GAME OVER", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20)),
                Column(children: [
                  Text("White Captures", style: TextStyle(fontWeight: FontWeight.bold)),
                  Text("$whiteCaptures", style: TextStyle(fontSize: 24)),
                ]),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  color: colorScheme.surfaceContainer,
                  padding: EdgeInsets.all(10),
                  child: GridView.builder(
                    physics: NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: boardSize,
                    ),
                    itemCount: boardSize * boardSize,
                    itemBuilder: (context, index) {
                      int row = index ~/ boardSize;
                      int col = index % boardSize;
                      
                      return GestureDetector(
                        onTap: () => _onIntersectionTap(row, col),
                        child: CustomPaint(
                          painter: GoCellPainter(
                            row: row,
                            col: col,
                            boardSize: boardSize,
                            stone: boardState[row][col],
                            lineColor: colorScheme.onSurface,
                            isLastMove: row == lastMoveRow && col == lastMoveCol,
                          ),
                        ),
                      );
                    },
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

class GoCellPainter extends CustomPainter {
  final int row;
  final int col;
  final int boardSize;
  final int stone;
  final Color lineColor;
  final bool isLastMove;

  GoCellPainter({
    required this.row,
    required this.col,
    required this.boardSize,
    required this.stone,
    required this.lineColor,
    this.isLastMove = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = 1.0;

    double cx = size.width / 2;
    double cy = size.height / 2;

    // Draw Grid Lines
    // Horizontal line
    if (col == 0) {
      canvas.drawLine(Offset(cx, cy), Offset(size.width, cy), paint);
    } else if (col == boardSize - 1) {
      canvas.drawLine(Offset(0, cy), Offset(cx, cy), paint);
    } else {
      canvas.drawLine(Offset(0, cy), Offset(size.width, cy), paint);
    }

    // Vertical line
    if (row == 0) {
      canvas.drawLine(Offset(cx, cy), Offset(cx, size.height), paint);
    } else if (row == boardSize - 1) {
      canvas.drawLine(Offset(cx, 0), Offset(cx, cy), paint);
    } else {
      canvas.drawLine(Offset(cx, 0), Offset(cx, size.height), paint);
    }

    // Draw Star Points (Hoshi)
    // Standard 19x19 star points are at 3, 9, 15 (0-indexed)
    List<int> stars = [3, 9, 15];
    if (stars.contains(row) && stars.contains(col)) {
      canvas.drawCircle(Offset(cx, cy), 3.0, Paint()..color = lineColor..style = PaintingStyle.fill);
    }

    // Draw Stone
    if (stone != 0) {
      double radius = size.width * 0.45;
      Paint stonePaint = Paint()
        ..color = (stone == 1) ? Colors.black : Colors.white
        ..style = PaintingStyle.fill;
      
      // Shadow
      canvas.drawCircle(Offset(cx + 1, cy + 1), radius, Paint()..color = Colors.black26..maskFilter = MaskFilter.blur(BlurStyle.normal, 1));
      
      canvas.drawCircle(Offset(cx, cy), radius, stonePaint);
      
      // Outline for white stones to see against light background if needed, 
      // though background is wood color so white is visible.
      if (stone == 2) {
        canvas.drawCircle(Offset(cx, cy), radius, Paint()..color = Colors.grey..style = PaintingStyle.stroke..strokeWidth = 0.5);
      }

      // Highlight last move
      if (isLastMove) {
        Paint markerPaint = Paint()
          ..color = (stone == 1) ? Colors.white : Colors.black
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0;
        canvas.drawCircle(Offset(cx, cy), radius * 0.5, markerPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant GoCellPainter oldDelegate) {
    return oldDelegate.stone != stone || oldDelegate.lineColor != lineColor || oldDelegate.isLastMove != isLastMove;
  }
}

class MctsNode {
  List<List<int>> board;
  int playerToMove;
  MctsNode? parent;
  List<MctsNode> children = [];
  List<Point<int>> untriedMoves = [];
  Point<int>? move;
  int visits = 0;
  double wins = 0;

  MctsNode({required this.board, required this.playerToMove, this.parent, this.move}) {
    // Initialize untried moves
    // For simplicity, pick 50 random empty spots to reduce branching factor
    List<Point<int>> allEmpty = [];
    for (int r = 0; r < 19; r++) {
      for (int c = 0; c < 19; c++) {
        if (board[r][c] == 0) allEmpty.add(Point(r, c));
      }
    }
    allEmpty.shuffle();
    untriedMoves = allEmpty.take(50).toList();
  }

  MctsNode selectChild() {
    // UCT
    return children.reduce((a, b) => a.uctValue(visits) > b.uctValue(visits) ? a : b);
  }

  double uctValue(int parentVisits) {
    if (visits == 0) return double.infinity;
    return (wins / visits) + 1.41 * sqrt(log(parentVisits) / visits);
  }

  MctsNode expand(GoPageState game) {
    Point<int> m = untriedMoves.removeLast();
    
    // Create new board state
    List<List<int>> nextBoard = List.generate(19, (i) => List.from(board[i]));
    int result = game._makeMove(nextBoard, playerToMove, m.x, m.y, checkKo: false);
    
    // If move was invalid (e.g. suicide), just return self (skip this move)
    // Ideally we shouldn't add invalid nodes.
    if (result == -1) {
      return this; 
    }

    int nextPlayer = (playerToMove == 1) ? 2 : 1;
    MctsNode child = MctsNode(board: nextBoard, playerToMove: nextPlayer, parent: this, move: m);
    children.add(child);
    return child;
  }

  int simulate(GoPageState game, int depth) {
    List<List<int>> simBoard = List.generate(19, (i) => List.from(board[i]));
    int currentPlayer = playerToMove;
    
    for (int d = 0; d < depth; d++) {
      // Random move
      List<Point<int>> emptySpots = [];
      for(int r=0; r<19; r++) {
        for(int c=0; c<19; c++) {
          if (simBoard[r][c] == 0) emptySpots.add(Point(r, c));
        }
      }
      if (emptySpots.isEmpty) break;
      
      Point<int> m = emptySpots[Random().nextInt(emptySpots.length)];
      game._makeMove(simBoard, currentPlayer, m.x, m.y, checkKo: false);
      currentPlayer = (currentPlayer == 1) ? 2 : 1;
    }

    // Heuristic evaluation: Count stones
    int blackStones = 0;
    int whiteStones = 0;
    for(var row in simBoard) {
      for(var cell in row) {
        if (cell == 1) blackStones++;
        if (cell == 2) whiteStones++;
      }
    }
    // Return winner: 1 for Black, 2 for White
    return blackStones > whiteStones ? 1 : 2;
  }

  void backpropagate(int winner) {
    visits++;
    // If the player who just moved (parent's playerToMove) won, increment wins?
    // Usually wins are stored relative to the player who moved to get here.
    // Here, 'playerToMove' is the player who WILL move from this state.
    // So the player who moved to create this state is the opponent of playerToMove.
    int justMoved = (playerToMove == 1) ? 2 : 1;
    if (winner == justMoved) {
      wins++;
    }
    if (parent != null) parent!.backpropagate(winner);
  }

  MctsNode? bestChild() {
    if (children.isEmpty) return null;
    return children.reduce((a, b) => a.visits > b.visits ? a : b);
  }
}
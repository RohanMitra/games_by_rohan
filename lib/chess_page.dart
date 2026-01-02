import 'dart:math' as math;
import 'package:flutter/material.dart';

class ChessPage extends StatefulWidget {
  const ChessPage({super.key});

  @override
  State<ChessPage> createState() => _ChessPageState();
}

class _ChessPageState extends State<ChessPage> {
  static const int boardSize = 8;
  late List<List<Piece?>> board;
  Player turn = Player.white;
  bool isAI = false;
  bool gameOver = false;
  Player? winner;

  // Selection state
  int? selectedRow;
  int? selectedCol;

  // Last move state for highlighting
  int? lastMoveStartRow;
  int? lastMoveStartCol;
  int? lastMoveEndRow;
  int? lastMoveEndCol;

  // Castling rights
  bool wKingMoved = false;
  bool bKingMoved = false;
  bool wRookLeftMoved = false; // (7,0)
  bool wRookRightMoved = false; // (7,7)
  bool bRookLeftMoved = false; // (0,0)
  bool bRookRightMoved = false; // (0,7)

  // En Passant target square (row, col) behind the pawn that moved two squares
  int? enPassantRow;
  int? enPassantCol;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    board = List.generate(boardSize, (_) => List.filled(boardSize, null));
    turn = Player.white;
    gameOver = false;
    winner = null;
    selectedRow = null;
    selectedCol = null;
    lastMoveStartRow = null;
    lastMoveStartCol = null;
    lastMoveEndRow = null;
    lastMoveEndCol = null;
    
    wKingMoved = false;
    bKingMoved = false;
    wRookLeftMoved = false;
    wRookRightMoved = false;
    bRookLeftMoved = false;
    bRookRightMoved = false;
    enPassantRow = null;
    enPassantCol = null;

    // Initialize Pieces
    // Black (Top)
    _placePiece(0, 0, PieceType.rook, Player.black);
    _placePiece(0, 1, PieceType.knight, Player.black);
    _placePiece(0, 2, PieceType.bishop, Player.black);
    _placePiece(0, 3, PieceType.queen, Player.black);
    _placePiece(0, 4, PieceType.king, Player.black);
    _placePiece(0, 5, PieceType.bishop, Player.black);
    _placePiece(0, 6, PieceType.knight, Player.black);
    _placePiece(0, 7, PieceType.rook, Player.black);
    for (int i = 0; i < 8; i++) {
      _placePiece(1, i, PieceType.pawn, Player.black);
    }

    // White (Bottom)
    _placePiece(7, 0, PieceType.rook, Player.white);
    _placePiece(7, 1, PieceType.knight, Player.white);
    _placePiece(7, 2, PieceType.bishop, Player.white);
    _placePiece(7, 3, PieceType.queen, Player.white);
    _placePiece(7, 4, PieceType.king, Player.white);
    _placePiece(7, 5, PieceType.bishop, Player.white);
    _placePiece(7, 6, PieceType.knight, Player.white);
    _placePiece(7, 7, PieceType.rook, Player.white);
    for (int i = 0; i < 8; i++) {
      _placePiece(6, i, PieceType.pawn, Player.white);
    }

    setState(() {});
  }

  void _placePiece(int r, int c, PieceType type, Player owner) {
    board[r][c] = Piece(type: type, owner: owner);
  }

  void _onCellTap(int row, int col) {
    if (gameOver) return;
    final piece = board[row][col];

    // Move logic
    if (selectedRow != null && selectedCol != null) {
      if (selectedRow == row && selectedCol == col) {
        setState(() {
          selectedRow = null;
          selectedCol = null;
        });
        return;
      }

      if (piece != null && piece.owner == turn) {
        setState(() {
          selectedRow = row;
          selectedCol = col;
        });
        return;
      }

      _attemptMove(selectedRow!, selectedCol!, row, col);
      return;
    }

    if (piece != null && piece.owner == turn) {
      setState(() {
        selectedRow = row;
        selectedCol = col;
      });
    }
  }

  void _attemptMove(int r0, int c0, int r1, int c1, {bool isAiMove = false}) async {
    if (!_isLegalMove(r0, c0, r1, c1, turn, board)) {
      if (!isAiMove) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Illegal Move!")));
      return;
    }

    final movingPiece = board[r0][c0]!;
    
    // Handle Promotion
    bool promote = false;
    if (movingPiece.type == PieceType.pawn) {
      if ((turn == Player.white && r1 == 0) || (turn == Player.black && r1 == 7)) {
        promote = true;
      }
    }

    PieceType promoteType = PieceType.queen; // Default
    if (promote && !isAiMove) {
      PieceType? selected = await showDialog<PieceType>(
        context: context,
        barrierDismissible: false,
        builder: (context) => SimpleDialog(
          title: Text("Promote to:"),
          children: [
            SimpleDialogOption(onPressed: () => Navigator.pop(context, PieceType.queen), child: Text("Queen")),
            SimpleDialogOption(onPressed: () => Navigator.pop(context, PieceType.rook), child: Text("Rook")),
            SimpleDialogOption(onPressed: () => Navigator.pop(context, PieceType.bishop), child: Text("Bishop")),
            SimpleDialogOption(onPressed: () => Navigator.pop(context, PieceType.knight), child: Text("Knight")),
          ],
        ),
      );
      if (selected != null) promoteType = selected;
    }

    setState(() {
      // Execute Move
      _executeMoveOnBoard(r0, c0, r1, c1, board, promote ? promoteType : null);

      // Update History
      lastMoveStartRow = r0;
      lastMoveStartCol = c0;
      lastMoveEndRow = r1;
      lastMoveEndCol = c1;

      // Reset Selection and Turn
      selectedRow = null;
      selectedCol = null;
      turn = turn == Player.white ? Player.black : Player.white;

      // Check Game Over
      if (!_hasLegalMoves(turn, board)) {
        gameOver = true;
        // If in check, checkmate. If not, stalemate.
        if (_isInCheck(turn, board)) {
          winner = turn == Player.white ? Player.black : Player.white;
        } else {
          winner = null; // Draw
        }
      } else if (isAI && turn == Player.black) {
        _aiMove();
      }
    });
  }

  void _executeMoveOnBoard(int r0, int c0, int r1, int c1, List<List<Piece?>> b, PieceType? promotion) {
    final piece = b[r0][c0]!;
    
    // En Passant Capture
    if (piece.type == PieceType.pawn && c1 != c0 && b[r1][c1] == null) {
      // Captured pawn is at [r0][c1]
      b[r0][c1] = null;
    }

    // Castling Move Rook
    if (piece.type == PieceType.king && (c1 - c0).abs() > 1) {
      if (c1 == 6) { // King side
        final rook = b[r0][7];
        b[r0][5] = rook;
        b[r0][7] = null;
      } else if (c1 == 2) { // Queen side
        final rook = b[r0][0];
        b[r0][3] = rook;
        b[r0][0] = null;
      }
    }

    // Update Castling Rights
    if (piece.type == PieceType.king) {
      if (piece.owner == Player.white) {
        wKingMoved = true;
      } else {
        bKingMoved = true;
      }
    }
    if (piece.type == PieceType.rook) {
      if (r0 == 7 && c0 == 0) wRookLeftMoved = true;
      if (r0 == 7 && c0 == 7) wRookRightMoved = true;
      if (r0 == 0 && c0 == 0) bRookLeftMoved = true;
      if (r0 == 0 && c0 == 7) bRookRightMoved = true;
    }

    // Set En Passant Target
    enPassantRow = null;
    enPassantCol = null;
    if (piece.type == PieceType.pawn && (r1 - r0).abs() == 2) {
      enPassantRow = (r0 + r1) ~/ 2;
      enPassantCol = c0;
    }

    // Move Piece
    b[r1][c1] = promotion != null 
        ? Piece(type: promotion, owner: piece.owner) 
        : piece;
    b[r0][c0] = null;
  }

  bool _isLegalMove(int r0, int c0, int r1, int c1, Player player, List<List<Piece?>> b) {
    if (!_isValidMove(r0, c0, r1, c1, player, b)) return false;

    // Simulate move to check for self-check
    // Note: This simulation is simplified and doesn't fully handle deep copy of castling rights/en passant for the simulation state,
    // but sufficient for basic check validation.
    List<List<Piece?>> tempBoard = List.generate(boardSize, (i) => List.from(b[i]));
    
    // We need to handle en passant capture in simulation to verify check correctly
    final piece = tempBoard[r0][c0]!;
    if (piece.type == PieceType.pawn && c1 != c0 && tempBoard[r1][c1] == null) {
       tempBoard[r0][c1] = null; // Remove captured pawn
    }

    tempBoard[r1][c1] = piece;
    tempBoard[r0][c0] = null;

    // Handle King move for castling simulation (king shouldn't pass through check)
    if (piece.type == PieceType.king && (c1 - c0).abs() > 1) {
      int dir = (c1 - c0) > 0 ? 1 : -1;
      // Check square passed through
      List<List<Piece?>> stepBoard = List.generate(boardSize, (i) => List.from(b[i]));
      stepBoard[r0][c0 + dir] = piece;
      stepBoard[r0][c0] = null;
      if (_isInCheck(player, stepBoard)) return false;
    }

    if (_isInCheck(player, tempBoard)) return false;

    return true;
  }

  bool _isValidMove(int r0, int c0, int r1, int c1, Player player, List<List<Piece?>> b) {
    final piece = b[r0][c0];
    if (piece == null || piece.owner != player) return false;
    
    // Destination check
    if (b[r1][c1] != null && b[r1][c1]!.owner == player) return false;

    int dr = r1 - r0;
    int dc = c1 - c0;
    int absDr = dr.abs();
    int absDc = dc.abs();
    int forward = player == Player.white ? -1 : 1;

    switch (piece.type) {
      case PieceType.pawn:
        // Forward 1
        if (dc == 0 && dr == forward && b[r1][c1] == null) return true;
        // Forward 2
        if (dc == 0 && dr == forward * 2 && b[r1][c1] == null && b[r0 + forward][c0] == null) {
          if (player == Player.white && r0 == 6) return true;
          if (player == Player.black && r0 == 1) return true;
        }
        // Capture
        if (absDc == 1 && dr == forward) {
          if (b[r1][c1] != null && b[r1][c1]!.owner != player) return true;
          // En Passant
          if (r1 == enPassantRow && c1 == enPassantCol) return true;
        }
        return false;

      case PieceType.king:
        if (absDr <= 1 && absDc <= 1) return true;
        // Castling
        if (dr == 0 && absDc == 2 && !bKingMoved && player == Player.black) {
          if (c1 == 6 && !bRookRightMoved && b[0][5] == null && b[0][6] == null) return true;
          if (c1 == 2 && !bRookLeftMoved && b[0][1] == null && b[0][2] == null && b[0][3] == null) return true;
        }
        if (dr == 0 && absDc == 2 && !wKingMoved && player == Player.white) {
          if (c1 == 6 && !wRookRightMoved && b[7][5] == null && b[7][6] == null) return true;
          if (c1 == 2 && !wRookLeftMoved && b[7][1] == null && b[7][2] == null && b[7][3] == null) return true;
        }
        return false;

      case PieceType.knight:
        return (absDr == 2 && absDc == 1) || (absDr == 1 && absDc == 2);

      case PieceType.bishop:
        if (absDr != absDc) return false;
        return _isPathClear(r0, c0, r1, c1, b);

      case PieceType.rook:
        if (dr != 0 && dc != 0) return false;
        return _isPathClear(r0, c0, r1, c1, b);

      case PieceType.queen:
        if (dr != 0 && dc != 0 && absDr != absDc) return false;
        return _isPathClear(r0, c0, r1, c1, b);
    }
  }

  bool _isPathClear(int r0, int c0, int r1, int c1, List<List<Piece?>> b) {
    int dr = r1 - r0;
    int dc = c1 - c0;
    int stepR = dr == 0 ? 0 : (dr > 0 ? 1 : -1);
    int stepC = dc == 0 ? 0 : (dc > 0 ? 1 : -1);

    int r = r0 + stepR;
    int c = c0 + stepC;
    while (r != r1 || c != c1) {
      if (b[r][c] != null) return false;
      r += stepR;
      c += stepC;
    }
    return true;
  }

  bool _isInCheck(Player player, List<List<Piece?>> b) {
    int? kR, kC;
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        final p = b[r][c];
        if (p != null && p.type == PieceType.king && p.owner == player) {
          kR = r;
          kC = c;
          break;
        }
      }
    }
    if (kR == null) return true;

    Player opponent = player == Player.white ? Player.black : Player.white;
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (b[r][c]?.owner == opponent) {
          if (_isValidMove(r, c, kR, kC!, opponent, b)) return true;
        }
      }
    }
    return false;
  }

  bool _hasLegalMoves(Player player, List<List<Piece?>> b) {
    for (int r0 = 0; r0 < boardSize; r0++) {
      for (int c0 = 0; c0 < boardSize; c0++) {
        if (b[r0][c0]?.owner == player) {
          for (int r1 = 0; r1 < boardSize; r1++) {
            for (int c1 = 0; c1 < boardSize; c1++) {
              if (_isLegalMove(r0, c0, r1, c1, player, b)) return true;
            }
          }
        }
      }
    }
    return false;
  }

  // --- AI Logic ---
  void _aiMove() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    double bestScore = -100000.0;
    int? bestR0, bestC0, bestR1, bestC1;

    for (int r0 = 0; r0 < boardSize; r0++) {
      for (int c0 = 0; c0 < boardSize; c0++) {
        if (board[r0][c0]?.owner == Player.black) {
          for (int r1 = 0; r1 < boardSize; r1++) {
            for (int c1 = 0; c1 < boardSize; c1++) {
              if (_isLegalMove(r0, c0, r1, c1, Player.black, board)) {
                double score = _simulateAndScore(r0, c0, r1, c1);
                if (score > bestScore) {
                  bestScore = score;
                  bestR0 = r0;
                  bestC0 = c0;
                  bestR1 = r1;
                  bestC1 = c1;
                }
              }
            }
          }
        }
      }
    }

    if (bestR0 != null) {
      _attemptMove(bestR0, bestC0!, bestR1!, bestC1!, isAiMove: true);
    } else {
      // No moves, game over handled in attemptMove usually, but just in case
      setState(() => gameOver = true);
    }
  }

  double _simulateAndScore(int r0, int c0, int r1, int c1) {
    // Simplified scoring based on material capture
    double score = 0;
    final target = board[r1][c1];
    if (target != null) {
      score += _getPieceValue(target.type);
    }
    // Small random factor
    score += math.Random().nextDouble() * 0.5;
    return score;
  }

  int _getPieceValue(PieceType type) {
    switch (type) {
      case PieceType.pawn: return 10;
      case PieceType.knight: return 30;
      case PieceType.bishop: return 30;
      case PieceType.rook: return 50;
      case PieceType.queen: return 90;
      case PieceType.king: return 900;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.inversePrimary,
        title: Text(gameOver 
            ? 'Game Over - ${winner == Player.white ? "White" : (winner == Player.black ? "Black" : "Draw")}' 
            : 'Chess - ${turn == Player.white ? "White" : "Black"}\'s Turn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetGame,
            tooltip: 'Restart Game',
          ),
          Row(children: [Text("AI"), Switch(value: isAI, onChanged: (v) => setState(() => isAI = v))]),
        ],
      ),
      body: Center(
        child: AspectRatio(
          aspectRatio: 1.0,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
            itemCount: 64,
            itemBuilder: (context, index) {
              int r = index ~/ 8;
              int c = index % 8;
              return _buildCell(r, c);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final piece = board[row][col];
    final isSelected = selectedRow == row && selectedCol == col;
    final isLastMove = (row == lastMoveStartRow && col == lastMoveStartCol) ||
                       (row == lastMoveEndRow && col == lastMoveEndCol);
    final isBlackSquare = (row + col) % 2 != 0;

    bool isValidMoveTarget = false;
    if (selectedRow != null && selectedCol != null) {
      isValidMoveTarget = _isLegalMove(selectedRow!, selectedCol!, row, col, turn, board);
    }

    Color bgColor = isBlackSquare ? const Color(0xFFD18B47) : const Color(0xFFFFCE9E); // Colors from chess.java
    if (isSelected) {
      bgColor = Colors.blue.withValues(alpha: 05);
    } else if (isLastMove) {
      bgColor = Colors.yellow.withValues(alpha: 05);
    }else if (isValidMoveTarget) {
      bgColor = Colors.red.withValues(alpha: 05);
    }

    return GestureDetector(
      onTap: () => _onCellTap(row, col),
      child: Container(
        color: bgColor,
        child: piece != null
            ? Padding(
                padding: const EdgeInsets.all(4.0),
                child: Image.asset(piece.imagePath),
              )
            : null,
      ),
    );
  }
}

enum Player { white, black }
enum PieceType { king, queen, rook, bishop, knight, pawn }

class Piece {
  final PieceType type;
  final Player owner;

  Piece({required this.type, required this.owner});

  String get imagePath {
    const String basePath = 'assets/images/chess';
    String filename = '';
    // Based on chess.java: King.png is White, King1.png is Black
    String suffix = owner == Player.black ? '1.png' : '.png';
    
    switch (type) {
      case PieceType.king: filename = 'King'; break;
      case PieceType.queen: filename = 'Queen'; break;
      case PieceType.rook: filename = 'Rook'; break;
      case PieceType.bishop: filename = 'Bishop'; break;
      case PieceType.knight: filename = 'Knight'; break;
      case PieceType.pawn: filename = 'Pawn'; break;
    }
    return '$basePath/$filename$suffix';
  }
}
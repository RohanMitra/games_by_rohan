import 'dart:math' as math;
import 'package:flutter/material.dart';

class ShogiPage extends StatefulWidget {
  const ShogiPage({super.key});

  @override
  State<ShogiPage> createState() => _ShogiPageState();
}

class _ShogiPageState extends State<ShogiPage> {
  static const int boardSize = 9;
  late List<List<Piece?>> board;
  Player turn = Player.sente;
  List<Piece> senteHand = [];
  List<Piece> goteHand = [];
  bool isAI = false;
  bool gameOver = false;
  Player? winner;

  // Selection state
  int? selectedRow;
  int? selectedCol;
  Piece? selectedHandPiece;

  // Last move state
  int? lastMoveStartRow;
  int? lastMoveStartCol;
  int? lastMoveEndRow;
  int? lastMoveEndCol;

  @override
  void initState() {
    super.initState();
    _resetGame();
  }

  void _resetGame() {
    board = List.generate(boardSize, (_) => List.filled(boardSize, null));
    senteHand.clear();
    goteHand.clear();
    turn = Player.sente;
    selectedRow = null;
    selectedCol = null;
    selectedHandPiece = null;
    lastMoveStartRow = null;
    lastMoveStartCol = null;
    lastMoveEndRow = null;
    lastMoveEndCol = null;
    gameOver = false;
    winner = null;

    // Initialize Sente pieces
    _placePiece(8, 0, PieceType.lance, Player.sente);
    _placePiece(8, 1, PieceType.knight, Player.sente);
    _placePiece(8, 2, PieceType.silver, Player.sente);
    _placePiece(8, 3, PieceType.gold, Player.sente);
    _placePiece(8, 4, PieceType.king, Player.sente);
    _placePiece(8, 5, PieceType.gold, Player.sente);
    _placePiece(8, 6, PieceType.silver, Player.sente);
    _placePiece(8, 7, PieceType.knight, Player.sente);
    _placePiece(8, 8, PieceType.lance, Player.sente);
    _placePiece(7, 1, PieceType.bishop, Player.sente);
    _placePiece(7, 7, PieceType.rook, Player.sente);
    for (int i = 0; i < 9; i++) {
      _placePiece(6, i, PieceType.pawn, Player.sente);
    }

    // Gote (Top)
    _placePiece(0, 0, PieceType.lance, Player.gote);
    _placePiece(0, 1, PieceType.knight, Player.gote);
    _placePiece(0, 2, PieceType.silver, Player.gote);
    _placePiece(0, 3, PieceType.gold, Player.gote);
    _placePiece(0, 4, PieceType.king, Player.gote);
    _placePiece(0, 5, PieceType.gold, Player.gote);
    _placePiece(0, 6, PieceType.silver, Player.gote);
    _placePiece(0, 7, PieceType.knight, Player.gote);
    _placePiece(0, 8, PieceType.lance, Player.gote);
    _placePiece(1, 1, PieceType.rook, Player.gote);
    _placePiece(1, 7, PieceType.bishop, Player.gote);
    for (int i = 0; i < 9; i++) {
      _placePiece(2, i, PieceType.pawn, Player.gote);
    }

    setState(() {});
  }

  void _placePiece(int r, int c, PieceType type, Player owner) {
    board[r][c] = Piece(type: type, owner: owner);
  }

  void _onCellTap(int row, int col) {
    if (gameOver) return;
    final piece = board[row][col];

    // 1. Handle Drop from Hand
    if (selectedHandPiece != null) {
      if (piece == null) {
        _attemptDrop(row, col);
      } else {
        // Cancel hand selection if tapping occupied square
        setState(() => selectedHandPiece = null);
      }
      return;
    }

    // 2. Handle Move on Board
    if (selectedRow != null && selectedCol != null) {
      // Deselect if tapping same square
      if (selectedRow == row && selectedCol == col) {
        setState(() {
          selectedRow = null;
          selectedCol = null;
        });
        return;
      }

      // Change selection if tapping own piece
      if (piece != null && piece.owner == turn) {
        setState(() {
          selectedRow = row;
          selectedCol = col;
        });
        return;
      }

      // Attempt Move
      _attemptMove(selectedRow!, selectedCol!, row, col);
      return;
    }

    // 3. Select Piece
    if (piece != null && piece.owner == turn) {
      setState(() {
        selectedRow = row;
        selectedCol = col;
      });
    }
  }

  void _attemptDrop(int row, int col) {
    // Basic Drop Validation
    if (selectedHandPiece == null) return;

    if (!_isLegalDrop(row, col, selectedHandPiece!, turn, board)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Illegal Drop!")));
      return;
    }

    setState(() {
      board[row][col] = Piece(type: selectedHandPiece!.type, owner: turn);
      if (turn == Player.sente) {
        senteHand.remove(selectedHandPiece);
      } else {
        goteHand.remove(selectedHandPiece);
      }

      lastMoveStartRow = null;
      lastMoveStartCol = null;
      lastMoveEndRow = row;
      lastMoveEndCol = col;

      selectedHandPiece = null;
      turn = turn == Player.sente ? Player.gote : Player.sente;

      if (!_hasLegalMoves(turn, board)) {
        gameOver = true;
        winner = turn == Player.sente ? Player.gote : Player.sente;
      } else if (isAI && turn == Player.gote) {
        _aiMove();
      }
    });
  }

  void _attemptMove(int r0, int c0, int r1, int c1, {bool isAiMove = false}) async {
    // Use _isLegalMove instead of _isValidMove to ensure safety
    if (!_isLegalMove(r0, c0, r1, c1, turn, board)) {
      if (!isAiMove) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Illegal Move!")));
      return;
    }

    final movingPiece = board[r0][c0]!;
    bool promote = movingPiece.promoted;
    bool canPromote = false;

    // Promotion Logic
    if (!movingPiece.promoted && movingPiece.type != PieceType.king && movingPiece.type != PieceType.gold) {
      // Sente promotes entering rows 0-2, Gote promotes entering rows 6-8
      // Or moving FROM those zones
      bool inZone = (turn == Player.sente) ? (r1 <= 2 || r0 <= 2) : (r1 >= 6 || r0 >= 6);
      
      if (inZone) {
        // Forced promotion check
        bool forced = false;
        if (turn == Player.sente) {
          if (r1 == 0 && (movingPiece.type == PieceType.pawn || movingPiece.type == PieceType.lance || movingPiece.type == PieceType.knight)) forced = true;
          if (r1 == 1 && movingPiece.type == PieceType.knight) forced = true;
        } else {
          if (r1 == 8 && (movingPiece.type == PieceType.pawn || movingPiece.type == PieceType.lance || movingPiece.type == PieceType.knight)) forced = true;
          if (r1 == 7 && movingPiece.type == PieceType.knight) forced = true;
        }

        if (forced) {
          promote = true;
        } else {
          canPromote = true;
        }
      }
    }

    if (canPromote && !isAiMove) {
      bool? result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Promote?"),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text("No")),
            TextButton(onPressed: () => Navigator.pop(context, true), child: Text("Yes")),
          ],
        ),
      );
      if (result == true) promote = true;
    }
    // AI always promotes if it can (based on PDE logic)
    if (canPromote && isAiMove) promote = true;

    setState(() {
      // Capture
      if (board[r1][c1] != null) {
        Piece captured = board[r1][c1]!;
        // Demote and change owner
        Piece toHand = Piece(type: captured.type, owner: turn, promoted: false);
        if (turn == Player.sente) {
          senteHand.add(toHand);
        } else {
          goteHand.add(toHand);
        }
      }

      // Move
      board[r1][c1] = Piece(type: movingPiece.type, owner: turn, promoted: promote);
      board[r0][c0] = null;

      lastMoveStartRow = r0;
      lastMoveStartCol = c0;
      lastMoveEndRow = r1;
      lastMoveEndCol = c1;

      // Reset Selection and Turn
      selectedRow = null;
      selectedCol = null;
      turn = turn == Player.sente ? Player.gote : Player.sente;

      if (!_hasLegalMoves(turn, board)) {
        gameOver = true;
        winner = turn == Player.sente ? Player.gote : Player.sente;
      } else if (isAI && turn == Player.gote) {
        _aiMove();
      }
    });
  }

  // Checks geometry and basic rules, but NOT king safety (self-check).
  // Used by _isInCheck to avoid recursion.
  bool _isValidMove(int r0, int c0, int r1, int c1, Player player, [List<List<Piece?>>? testBoard]) {
    final b = testBoard ?? board;
    final piece = b[r0][c0];
    if (piece == null || piece.owner != player) return false; // Should not happen if logic is correct
    
    // Cannot capture own piece
    if (b[r1][c1] != null && b[r1][c1]!.owner == player) return false;

    int dr = r1 - r0;
    int dc = c1 - c0;
    int absDr = dr.abs();
    int absDc = dc.abs();

    // Direction multipliers for Sente (up is -1) vs Gote (up is +1)
    int forward = (player == Player.sente) ? -1 : 1;

    // Logic ported from shogi.pde validMove
    if (piece.promoted) {
      if (piece.type == PieceType.rook) {
        // Dragon (Rook + King)
        if (absDr <= 1 && absDc <= 1) return true;
        return _isPathClear(r0, c0, r1, c1, b);
      } else if (piece.type == PieceType.bishop) {
        // Horse (Bishop + King)
        if (absDr <= 1 && absDc <= 1) return true;
        return _isPathClear(r0, c0, r1, c1, b);
      } else {
        // Gold General movement (Tokin, Narigin, etc.)
        return _isValidGoldMove(dr, dc, forward);
      }
    } else {
      switch (piece.type) {
        case PieceType.king:
          return absDr <= 1 && absDc <= 1;
        case PieceType.rook:
          return _isPathClear(r0, c0, r1, c1, b) && (dr == 0 || dc == 0);
        case PieceType.bishop:
          return _isPathClear(r0, c0, r1, c1, b) && (absDr == absDc);
        case PieceType.gold:
          return _isValidGoldMove(dr, dc, forward);
        case PieceType.silver:
          // Forward OR Diagonals
          if (dr == forward && absDc <= 1) return true; // Forward, Forward-Left, Forward-Right
          if (dr == -forward && absDc == 1) return true; // Back-Left, Back-Right
          return false;
        case PieceType.knight:
          return (dr == forward * 2) && (absDc == 1);
        case PieceType.lance:
          if (dc != 0) return false;
          if (player == Player.sente && dr >= 0) return false; // Must move up
          if (player == Player.gote && dr <= 0) return false; // Must move down
          return _isPathClear(r0, c0, r1, c1, b);
        case PieceType.pawn:
          return (dr == forward) && (dc == 0);
      }
    }
  }

  bool _isValidGoldMove(int dr, int dc, int forward) {
    // Forward (any), Side (1), Back (straight only)
    if (dr == forward && dc.abs() <= 1) return true; // Forward 3
    if (dr == 0 && dc.abs() == 1) return true; // Side 2
    if (dr == -forward && dc == 0) return true; // Back 1
    return false;
  }

  bool _isPathClear(int r0, int c0, int r1, int c1, List<List<Piece?>> b) {
    int dr = r1 - r0;
    int dc = c1 - c0;
    int stepR = dr == 0 ? 0 : (dr > 0 ? 1 : -1);
    int stepC = dc == 0 ? 0 : (dc > 0 ? 1 : -1);

    // Check if diagonal or orthogonal
    if (dr != 0 && dc != 0 && dr.abs() != dc.abs()) return false;

    int r = r0 + stepR;
    int c = c0 + stepC;
    while (r != r1 || c != c1) {
      if (b[r][c] != null) return false;
      r += stepR;
      c += stepC;
    }
    return true;
  }

  void _onHandPieceTap(Piece piece) {
    if (piece.owner == turn) {
      setState(() {
        selectedHandPiece = piece;
        selectedRow = null;
        selectedCol = null;
      });
    }
  }

  // --- Check and Legality Logic ---

  bool _isInCheck(Player player, List<List<Piece?>> b) {
    // Find King
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
    if (kR == null) return true; // Should not happen, but if king missing, technically lost

    // Check if any opponent piece can move to King's position
    Player opponent = player == Player.sente ? Player.gote : Player.sente;
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        final p = b[r][c];
        if (p != null && p.owner == opponent) {
          if (_isValidMove(r, c, kR, kC!, opponent, b)) return true;
        }
      }
    }
    return false;
  }

  bool _isLegalMove(int r0, int c0, int r1, int c1, Player player, List<List<Piece?>> b) {
    // 1. Geometric validity
    if (!_isValidMove(r0, c0, r1, c1, player, b)) return false;

    // 2. Does it cause self-check?
    // Simulate move
    List<List<Piece?>> tempBoard = List.generate(boardSize, (i) => List.from(b[i]));
    final moving = tempBoard[r0][c0]!;
    tempBoard[r1][c1] = Piece(type: moving.type, owner: moving.owner, promoted: moving.promoted);
    tempBoard[r0][c0] = null;

    if (_isInCheck(player, tempBoard)) return false;

    return true;
  }

  bool _isLegalDrop(int r, int c, Piece piece, Player player, List<List<Piece?>> b) {
    if (b[r][c] != null) return false;

    // 1. Basic Rules
    if (!_isValidDropRules(r, c, piece, player, b)) return false;

    // 2. Self-Check Check
    List<List<Piece?>> tempBoard = List.generate(boardSize, (i) => List.from(b[i]));
    tempBoard[r][c] = Piece(type: piece.type, owner: player);
    if (_isInCheck(player, tempBoard)) return false;

    // 3. Uchifuzume (Pawn Drop Mate)
    if (piece.type == PieceType.pawn) {
      Player opponent = player == Player.sente ? Player.gote : Player.sente;
      // If dropping the pawn puts opponent in check
      if (_isInCheck(opponent, tempBoard)) {
        // And opponent has NO legal moves
        if (!_hasLegalMoves(opponent, tempBoard)) {
          return false; // Illegal to win by pawn drop mate
        }
      }
    }

    return true;
  }

  bool _hasLegalMoves(Player player, List<List<Piece?>> b) {
    // 1. Board Moves
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

    // 2. Drops
    // Note: This uses the actual hand state. If checking hypothetical future where hand changed, this needs update.
    List<Piece> hand = player == Player.sente ? senteHand : goteHand;
    // Optimization: only check unique piece types in hand
    Set<PieceType> typesInHand = hand.map((p) => p.type).toSet();
    
    for (var type in typesInHand) {
      Piece sample = Piece(type: type, owner: player);
      for (int r = 0; r < boardSize; r++) {
        for (int c = 0; c < boardSize; c++) {
          if (b[r][c] == null && _isLegalDrop(r, c, sample, player, b)) return true;
        }
      }
    }

    return false;
  }

  // --- AI Logic ---

  void _aiMove() async {
    // Small delay to make it feel like thinking
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    double bestScore = -1000000.0;
    int? bestR0, bestC0, bestR1, bestC1;
    Piece? bestHandPiece;
    bool isDrop = false;

    // 1. Iterate Board Moves
    for (int r0 = 0; r0 < boardSize; r0++) {
      for (int c0 = 0; c0 < boardSize; c0++) {
        final piece = board[r0][c0];
        if (piece != null && piece.owner == Player.gote) {
          for (int r1 = 0; r1 < boardSize; r1++) {
            for (int c1 = 0; c1 < boardSize; c1++) {
              if (_isLegalMove(r0, c0, r1, c1, Player.gote, board)) {
                // Simulate
                double score = _simulateAndScore(r0, c0, r1, c1, null);
                if (score > bestScore) {
                  bestScore = score;
                  bestR0 = r0;
                  bestC0 = c0;
                  bestR1 = r1;
                  bestC1 = c1;
                  isDrop = false;
                }
              }
            }
          }
        }
      }
    }

    // 2. Iterate Drop Moves
    for (final piece in goteHand) {
      for (int r1 = 0; r1 < boardSize; r1++) {
        for (int c1 = 0; c1 < boardSize; c1++) {
          if (board[r1][c1] == null && _isLegalDrop(r1, c1, piece, Player.gote, board)) {
             double score = _simulateAndScore(-1, -1, r1, c1, piece);
             if (score > bestScore) {
               bestScore = score;
               bestHandPiece = piece;
               bestR1 = r1;
               bestC1 = c1;
               isDrop = true;
             }
          }
        }
      }
    }

    // Execute
    if (isDrop && bestHandPiece != null && bestR1 != null && bestC1 != null) {
      setState(() {
        selectedHandPiece = bestHandPiece;
        _attemptDrop(bestR1!, bestC1!);
      });
    } else if (!isDrop && bestR0 != null && bestC0 != null && bestR1 != null && bestC1 != null) {
      _attemptMove(bestR0, bestC0, bestR1, bestC1, isAiMove: true);
    }
  }

  double _simulateAndScore(int r0, int c0, int r1, int c1, Piece? dropPiece) {
    // Clone board
    List<List<Piece?>> tempBoard = List.generate(boardSize, (i) => List.from(board[i]));
    
    double score = 0;
    
    // Apply Move
    if (dropPiece != null) {
      // Drop
      tempBoard[r1][c1] = Piece(type: dropPiece.type, owner: Player.gote);
    } else {
      // Board Move
      final moving = tempBoard[r0][c0]!;
      final captured = tempBoard[r1][c1];
      if (captured != null) {
        score += _getPieceValue(captured);
      }
      
      // Auto promote logic for AI (Gote promotes at rows 6,7,8)
      bool promote = moving.promoted;
      if (!promote) {
        if (r1 >= 6 || r0 >= 6) promote = true; // Simplified AI promotion
      }
      
      tempBoard[r1][c1] = Piece(type: moving.type, owner: moving.owner, promoted: promote);
      tempBoard[r0][c0] = null;
    }

    // Heuristics from shogi.pde
    // redMoves (AI) - whiteMoves (Player)
    int aiMoves = _countMobility(Player.gote, tempBoard);
    int playerMoves = _countMobility(Player.sente, tempBoard);
    score += (aiMoves - playerMoves);

    // Attacked penalty
    score -= _calculateAttacked(Player.gote, tempBoard);

    // Randomness (0.9 to 1.0)
    score *= (0.9 + math.Random().nextDouble() * 0.1);

    return score;
  }

  int _getPieceValue(Piece piece) {
    int val = 0;
    switch (piece.type) {
      case PieceType.pawn: val = 2; break;
      case PieceType.lance: val = 4; break;
      case PieceType.knight: val = 4; break;
      case PieceType.silver: val = 8; break;
      case PieceType.gold: val = 10; break;
      case PieceType.bishop: val = 18; break;
      case PieceType.rook: val = 20; break;
      case PieceType.king: val = 1000; break;
    }
    if (piece.promoted) val += 6;
    return val;
  }

  int _countMobility(Player player, List<List<Piece?>> b) {
    int count = 0;
    for (int r0 = 0; r0 < boardSize; r0++) {
      for (int c0 = 0; c0 < boardSize; c0++) {
        if (b[r0][c0]?.owner == player) {
          for (int r1 = 0; r1 < boardSize; r1++) {
            for (int c1 = 0; c1 < boardSize; c1++) {
              if (_isValidMove(r0, c0, r1, c1, player, b)) count++; // AI heuristic uses geometry for speed
            }
          }
        }
      }
    }
    return count;
  }

  int _calculateAttacked(Player player, List<List<Piece?>> b) {
    int score = 0;
    Player opponent = player == Player.sente ? Player.gote : Player.sente;
    
    // Iterate all opponent pieces and see what they can capture
    for (int r0 = 0; r0 < boardSize; r0++) {
      for (int c0 = 0; c0 < boardSize; c0++) {
        if (b[r0][c0]?.owner == opponent) {
          for (int r1 = 0; r1 < boardSize; r1++) {
            for (int c1 = 0; c1 < boardSize; c1++) {
              // If valid move and target is my piece
              if (_isValidMove(r0, c0, r1, c1, opponent, b)) {
                final target = b[r1][c1];
                if (target != null && target.owner == player) {
                  score += _getPieceValue(target);
                }
              }
            }
          }
        }
      }
    }
    return score;
  }

  bool _isValidDropRules(int r, int c, Piece piece, Player player, List<List<Piece?>> b) {
    // Nifu (Two Pawns) check
    if (piece.type == PieceType.pawn) {
      for (int row = 0; row < boardSize; row++) {
        final p = b[row][c];
        if (p != null && p.owner == player && p.type == PieceType.pawn && !p.promoted) {
          return false;
        }
      }
      if (player == Player.sente && r == 0) return false;
      if (player == Player.gote && r == 8) return false;
    }
    if (piece.type == PieceType.lance) {
      if (player == Player.sente && r == 0) return false;
      if (player == Player.gote && r == 8) return false;
    }
    if (piece.type == PieceType.knight) {
      if (player == Player.sente && r <= 1) return false;
      if (player == Player.gote && r >= 7) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.inversePrimary,
        title: Text(gameOver 
            ? 'Game Over - ${winner == Player.sente ? "Sente" : "Gote"} Wins!' 
            : 'Shogi - ${turn == Player.sente ? "Sente" : "Gote"}\'s Turn'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _resetGame,
            tooltip: 'Restart Game',
          ),
          Row(children: [Text("AI"), Switch(value: isAI, onChanged: (v) => setState(() => isAI = v))]),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Gote Hand (Top)
            _buildHandArea(goteHand, Player.gote),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: AspectRatio(
                aspectRatio: 1.0,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 9,
                    crossAxisSpacing: 1,
                    mainAxisSpacing: 1,
                  ),
                  itemCount: 81,
                  itemBuilder: (context, index) {
                    int r = index ~/ 9;
                    int c = index % 9;
                    return _buildCell(r, c);
                  },
                ),
              ),
            ),
            // Sente Hand (Bottom)
            _buildHandArea(senteHand, Player.sente),
          ],
        ),
      ),
    );
  }

  Widget _buildHandArea(List<Piece> hand, Player player) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 70,
      color: colorScheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(Icons.person, color: player == Player.sente ? colorScheme.onSurface : colorScheme.onSurfaceVariant),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: hand.length,
              itemBuilder: (context, index) {
                final piece = hand[index];
                final isSelected = selectedHandPiece == piece;
                return GestureDetector(
                  onTap: () => _onHandPieceTap(piece),
                  child: Container(
                    margin: const EdgeInsets.all(4),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? colorScheme.primaryContainer : colorScheme.secondaryContainer,
                      border: Border.all(color: colorScheme.outline),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Transform.rotate(
                        angle: piece.owner == Player.gote ? math.pi : 0,
                        child: Image.asset(piece.imagePath, width: 40, height: 40),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCell(int row, int col) {
    final colorScheme = Theme.of(context).colorScheme;
    final piece = board[row][col];
    final isSelected = selectedRow == row && selectedCol == col;
    final isLastMove = (row == lastMoveStartRow && col == lastMoveStartCol) ||
                       (row == lastMoveEndRow && col == lastMoveEndCol);
    
    // Highlight valid moves if a piece is selected
    bool isValidMoveTarget = false;
    if (selectedRow != null && selectedCol != null) {
      isValidMoveTarget = _isLegalMove(selectedRow!, selectedCol!, row, col, turn, board);
      // Don't highlight if occupied by own piece (already checked in isValidMove but visual cue)
      if (piece != null && piece.owner == turn) isValidMoveTarget = false;
    }

    return GestureDetector(
      onTap: () => _onCellTap(row, col),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outline),
          color: isSelected 
              ? colorScheme.primaryContainer 
              : (isValidMoveTarget 
                  ? colorScheme.tertiaryContainer 
                  : (isLastMove ? colorScheme.secondaryContainer : colorScheme.surface)),
        ),
        child: piece != null
            ? Center(
                child: Transform.rotate(
                  angle: piece.owner == Player.gote ? math.pi : 0,
                  child: Image.asset(piece.imagePath, fit: BoxFit.contain),
                ),
              )
            : null,
      ),
    );
  }
}

enum Player { sente, gote }
enum PieceType { king, rook, bishop, gold, silver, knight, lance, pawn }

class Piece {
  final PieceType type;
  final Player owner;
  final bool promoted;

  Piece({required this.type, required this.owner, this.promoted = false});

  String get imagePath {
    const String basePath = 'assets/images/shogi';
    String filename;
    switch (type) {
      case PieceType.king:
        filename = 'King.png';
        break;
      case PieceType.rook:
        filename = promoted ? 'Rook1.png' : 'Rook.png';
        break;
      case PieceType.bishop:
        filename = promoted ? 'Bishop1.png' : 'Bishop.png';
        break;
      case PieceType.gold:
        filename = 'Gold.png';
        break;
      case PieceType.silver:
        filename = promoted ? 'Silver1.png' : 'Silver.png';
        break;
      case PieceType.knight:
        filename = promoted ? 'Knight1.png' : 'Knight.png';
        break;
      case PieceType.lance:
        filename = promoted ? 'Lance1.png' : 'Lance.png';
        break;
      case PieceType.pawn:
        filename = promoted ? 'Pawn1.png' : 'Pawn.png';
        break;
    }
    return '$basePath/$filename';
  }
}
import 'package:flutter/material.dart';

class CheckersPage extends StatefulWidget {
  const CheckersPage({super.key});

  @override
  State<CheckersPage> createState() => _CheckersPageState();
}

class _CheckersPageState extends State<CheckersPage> {
  static const int boardSize = 8;
  late List<List<Piece?>> board;
  Player turn = Player.white;
  bool isAI = false;
  bool gameOver = false;
  Player? winner;

  // Selection state
  int? selectedRow;
  int? selectedCol;

  // Game state flags from java logic
  bool doubleJump = false;
  bool jumping = false;
  int p0 = -1, p1 = -1; // Position for double jump constraint

  // Last move for highlighting
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
    turn = Player.white;
    gameOver = false;
    winner = null;
    selectedRow = null;
    selectedCol = null;
    doubleJump = false;
    jumping = false;
    p0 = -1;
    p1 = -1;
    lastMoveStartRow = null;
    lastMoveStartCol = null;
    lastMoveEndRow = null;
    lastMoveEndCol = null;

    // Initialize Pieces based on startPosition() in checkers.java
    // Black (Red in java logic) at top (rows 0, 1, 2)
    // Pieces are placed where (row + col) is odd (Dark squares)
    for (int r = 0; r < 3; r++) {
      for (int c = 0; c < boardSize; c++) {
        if ((r + c) % 2 != 0) {
          board[r][c] = Piece(type: PieceType.pawn, owner: Player.black);
        }
      }
    }

    // White at bottom (rows 5, 6, 7)
    for (int r = 5; r < 8; r++) {
      for (int c = 0; c < boardSize; c++) {
        if ((r + c) % 2 != 0) {
          board[r][c] = Piece(type: PieceType.pawn, owner: Player.white);
        }
      }
    }

    setState(() {});
  }

  void _onCellTap(int row, int col) {
    if (gameOver) return;
    
    // If AI turn, ignore taps
    if (isAI && turn == Player.black) return;

    final piece = board[row][col];

    // Move logic
    if (selectedRow != null && selectedCol != null) {
      if (selectedRow == row && selectedCol == col) {
        // Deselect
        setState(() {
          selectedRow = null;
          selectedCol = null;
        });
        return;
      }

      // If tapping another own piece, select it (unless double jumping constraint)
      if (piece != null && piece.owner == turn) {
        if (!doubleJump) {
          setState(() {
            selectedRow = row;
            selectedCol = col;
          });
        }
        return;
      }

      // Attempt move
      if (_isValidMove(selectedRow!, selectedCol!, row, col, turn, board)) {
        _executeMove(selectedRow!, selectedCol!, row, col);
      }
      return;
    }

    // Select piece
    if (piece != null && piece.owner == turn) {
      // If double jump active, can only select the specific piece
      if (doubleJump) {
        if (row == p0 && col == p1) {
          setState(() {
            selectedRow = row;
            selectedCol = col;
          });
        }
      } else {
        setState(() {
          selectedRow = row;
          selectedCol = col;
        });
      }
    }
  }

  void _executeMove(int r0, int c0, int r1, int c1) {
    setState(() {
      // Move piece logic ported from movePiece in checkers.java
      Piece movingPiece = board[r0][c0]!;
      bool promote = false;

      // Promotion
      if (movingPiece.type == PieceType.pawn) {
        if (movingPiece.owner == Player.white && r1 == 0) {
          movingPiece = Piece(type: PieceType.king, owner: Player.white);
          promote = true;
        } else if (movingPiece.owner == Player.black && r1 == 7) {
          movingPiece = Piece(type: PieceType.king, owner: Player.black);
          promote = true;
        }
      }

      board[r1][c1] = movingPiece;
      board[r0][c0] = null;

      // Handle Jump Capture
      bool jumped = false;
      if ((r0 - r1).abs() == 2) {
        int midR = (r0 + r1) ~/ 2;
        int midC = (c0 + c1) ~/ 2;
        board[midR][midC] = null;
        jumped = true;
      }

      // Double Jump Logic
      bool canJumpAgain = false;
      if (jumped && !promote) {
        // Check 4 directions for another jump
        if (_canJumpFrom(r1, c1, turn, board)) {
          canJumpAgain = true;
        }
      }

      if (canJumpAgain) {
        doubleJump = true;
        p0 = r1;
        p1 = c1;
        // Turn does not change
        selectedRow = r1;
        selectedCol = c1;
      } else {
        doubleJump = false;
        p0 = -1;
        p1 = -1;
        selectedRow = null;
        selectedCol = null;
        
        // Check if next player must jump
        Player nextPlayer = turn == Player.white ? Player.black : Player.white;
        if (_mustJump(nextPlayer, board)) {
          jumping = true;
        } else {
          jumping = false;
        }

        // Check Game Over (No moves for next player)
        if (_numMoves(nextPlayer, board) == 0) {
          gameOver = true;
          winner = turn; // Current player wins if next player has no moves
        }

        turn = nextPlayer;
      }

      lastMoveStartRow = r0;
      lastMoveStartCol = c0;
      lastMoveEndRow = r1;
      lastMoveEndCol = c1;

      if (!gameOver && isAI && turn == Player.black) {
        _aiMove();
      }
    });
  }

  bool _isValidMove(int r0, int c0, int r1, int c1, Player player, List<List<Piece?>> b) {
    // Bounds check
    if (r1 < 0 || r1 >= boardSize || c1 < 0 || c1 >= boardSize) return false;
    if (b[r1][c1] != null) return false; // Target must be empty

    // Double jump constraint
    if (doubleJump) {
      if (r0 != p0 || c0 != p1) return false;
      if ((r1 - r0).abs() != 2) return false;
    }

    // Mandatory jump constraint
    if (jumping) {
      if ((r1 - r0).abs() != 2) return false;
    }

    final piece = b[r0][c0];
    if (piece == null || piece.owner != player) return false;

    int dr = r1 - r0; // down1 - down
    int dc = c1 - c0; // right1 - right

    // Logic from validMove in checkers.java
    if (player == Player.white) {
      if (piece.type == PieceType.pawn) {
        // Move forward 1 (White moves UP, so dr is -1)
        if (dc.abs() == 1 && dr == -1 && !jumping && !doubleJump) return true;
        // Jump 2
        if (dc.abs() == 2 && dr == -2) {
          int midR = r0 - 1;
          int midC = (c0 + c1) ~/ 2;
          if (_isOpponent(midR, midC, player, b)) return true;
        }
      } else {
        // King
        if (dc.abs() == 1 && dr.abs() == 1 && !jumping && !doubleJump) return true;
        if (dc.abs() == 2 && dr.abs() == 2) {
          int midR = (r0 + r1) ~/ 2;
          int midC = (c0 + c1) ~/ 2;
          if (_isOpponent(midR, midC, player, b)) return true;
        }
      }
    } else {
      // Black (Red in java)
      if (piece.type == PieceType.pawn) {
        // Move forward 1 (Black moves DOWN, so dr is 1)
        if (dc.abs() == 1 && dr == 1 && !jumping && !doubleJump) return true;
        // Jump 2
        if (dc.abs() == 2 && dr == 2) {
          int midR = r0 + 1;
          int midC = (c0 + c1) ~/ 2;
          if (_isOpponent(midR, midC, player, b)) return true;
        }
      } else {
        // King
        if (dc.abs() == 1 && dr.abs() == 1 && !jumping && !doubleJump) return true;
        if (dc.abs() == 2 && dr.abs() == 2) {
          int midR = (r0 + r1) ~/ 2;
          int midC = (c0 + c1) ~/ 2;
          if (_isOpponent(midR, midC, player, b)) return true;
        }
      }
    }

    return false;
  }

  bool _isOpponent(int r, int c, Player player, List<List<Piece?>> b) {
    if (r < 0 || r >= boardSize || c < 0 || c >= boardSize) return false;
    final p = b[r][c];
    return p != null && p.owner != player;
  }

  bool _canJumpFrom(int r, int c, Player player, List<List<Piece?>> b) {
    // Temporarily set flags to allow checking pure jump validity
    // But _isValidMove relies on global flags.
    // We can simulate the check manually for "can jump again" logic.
    
    List<int> drs = [-2, -2, 2, 2];
    List<int> dcs = [-2, 2, -2, 2];

    for (int i = 0; i < 4; i++) {
      int r1 = r + drs[i];
      int c1 = c + dcs[i];
      if (r1 >= 0 && r1 < boardSize && c1 >= 0 && c1 < boardSize && b[r1][c1] == null) {
        int midR = (r + r1) ~/ 2;
        int midC = (c + c1) ~/ 2;
        if (_isOpponent(midR, midC, player, b)) {
          Piece p = b[r][c]!;
          // Direction check
          if (p.type == PieceType.king) return true;
          if (player == Player.white && drs[i] < 0) return true;
          if (player == Player.black && drs[i] > 0) return true;
        }
      }
    }
    return false;
  }

  bool _mustJump(Player player, List<List<Piece?>> b) {
    for (int r = 0; r < boardSize; r++) {
      for (int c = 0; c < boardSize; c++) {
        if (b[r][c]?.owner == player) {
          if (_canJumpFrom(r, c, player, b)) return true;
        }
      }
    }
    return false;
  }

  int _numMoves(Player player, List<List<Piece?>> b) {
    int count = 0;
    // We need to know if jumping is required to count correctly
    bool jumpReq = _mustJump(player, b);

    for (int r0 = 0; r0 < boardSize; r0++) {
      for (int c0 = 0; c0 < boardSize; c0++) {
        if (b[r0][c0]?.owner == player) {
          for (int r1 = 0; r1 < boardSize; r1++) {
            for (int c1 = 0; c1 < boardSize; c1++) {
              // Simulate validity check
              bool valid = false;
              if (b[r1][c1] == null) {
                int dr = r1 - r0;
                int dc = c1 - c0;
                Piece p = b[r0][c0]!;
                
                if (jumpReq) {
                  if (dr.abs() == 2 && dc.abs() == 2) {
                    int midR = (r0 + r1) ~/ 2;
                    int midC = (c0 + c1) ~/ 2;
                    if (_isOpponent(midR, midC, player, b)) {
                      if (p.type == PieceType.king) {
                        valid = true;
                      } else if (player == Player.white && dr < 0) {
                        valid = true;
                      }
                      else if (player == Player.black && dr > 0) {
                        valid = true;
                      }
                    }
                  }
                } else {
                  if (dr.abs() == 1 && dc.abs() == 1) {
                    if (p.type == PieceType.king) {
                      valid = true;
                    } else if (player == Player.white && dr < 0) {
                      valid = true;
                    }
                    else if (player == Player.black && dr > 0) {
                      valid = true;
                    }
                  }
                }
              }
              if (valid) count++;
            }
          }
        }
      }
    }
    return count;
  }

  // --- AI Logic ---
  void _aiMove() async {
    await Future.delayed(const Duration(milliseconds: 500));
    if (!mounted) return;

    int bestScore = -10000;
    int? bestR0, bestC0, bestR1, bestC1;

    // Determine if AI must jump
    bool jumpReq = _mustJump(Player.black, board);

    for (int r0 = 0; r0 < boardSize; r0++) {
      for (int c0 = 0; c0 < boardSize; c0++) {
        if (board[r0][c0]?.owner == Player.black) {
          for (int r1 = 0; r1 < boardSize; r1++) {
            for (int c1 = 0; c1 < boardSize; c1++) {
              // Check validity manually
              bool valid = false;
              if (board[r1][c1] == null) {
                 int dr = r1 - r0;
                 int dc = c1 - c0;
                 Piece p = board[r0][c0]!;
                 
                 if (jumpReq) {
                   if (dr.abs() == 2 && dc.abs() == 2) {
                     int midR = (r0 + r1) ~/ 2;
                     int midC = (c0 + c1) ~/ 2;
                     if (_isOpponent(midR, midC, Player.black, board)) {
                        if (p.type == PieceType.king || dr > 0) valid = true;
                     }
                   }
                 } else {
                   if (dr.abs() == 1 && dc.abs() == 1) {
                      if (p.type == PieceType.king || dr > 0) valid = true;
                   }
                 }
              }

              if (valid) {
                // Simulate Move
                List<List<Piece?>> tempBoard = List.generate(boardSize, (i) => List.from(board[i]));
                Piece moving = tempBoard[r0][c0]!;
                if (r1 == 7) moving = Piece(type: PieceType.king, owner: Player.black);
                tempBoard[r1][c1] = moving;
                tempBoard[r0][c0] = null;
                if ((r1 - r0).abs() == 2) {
                  tempBoard[(r0 + r1) ~/ 2][(c0 + c1) ~/ 2] = null;
                }

                // Score = redMoves - whiteMoves
                int redMoves = _numMoves(Player.black, tempBoard);
                int whiteMoves = _numMoves(Player.white, tempBoard);
                int score = redMoves - whiteMoves;

                if (score >= bestScore) {
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
      _executeMove(bestR0, bestC0!, bestR1!, bestC1!);
    } else {
      // No moves
      setState(() {
        gameOver = true;
        winner = Player.white;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: colorScheme.inversePrimary,
        title: Text(gameOver 
            ? 'Game Over - ${winner == Player.white ? "White" : "Black"} Wins!' 
            : 'Checkers - ${turn == Player.white ? "White" : "Black"}\'s Turn'),
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
    final isDarkSquare = (row + col) % 2 != 0;

    // Highlight valid moves
    bool isValidMoveTarget = false;
    if (selectedRow != null && selectedCol != null && board[row][col] == null && isDarkSquare) {
      if (_isValidMove(selectedRow!, selectedCol!, row, col, turn, board)) {
        isValidMoveTarget = true;
      }
    }

    Color bgColor = isDarkSquare ? const Color(0xFFD18B47) : const Color(0xFFFFCE9E);
    if (isSelected) {
      bgColor = Colors.blue.withValues(alpha: 05);
    } else if (isLastMove) {
      bgColor = Colors.yellow.withValues(alpha: 05);
    } else if (isValidMoveTarget) {
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
enum PieceType { pawn, king }

class Piece {
  final PieceType type;
  final Player owner;

  Piece({required this.type, required this.owner});

  String get imagePath {
    const String basePath = 'assets/images/checkers';
    String filename = '';
    // Java: wKing=King.png, bKing=King1.png, wPawn=Pawn.png, bPawn=Pawn1.png
    String suffix = owner == Player.black ? '1.png' : '.png';
    
    switch (type) {
      case PieceType.king: filename = 'King'; break;
      case PieceType.pawn: filename = 'Pawn'; break;
    }
    return '$basePath/$filename$suffix';
  }
}
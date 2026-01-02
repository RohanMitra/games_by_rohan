int down, right, down1, right1;//curr move, (down, right)starting pos   (down1,right1)ending pos
int p0, p1;//for double jumping
int bestl, bestk, besti, bestj;//AI move
boolean click;//first click select piece, second click moves piece
boolean white = true;
boolean red = false;
boolean turn;//player turn
boolean promote;
boolean doubleJump, jumping;
boolean gameOver;
PImage wKing, bKing, wPawn, bPawn;
PImage[][] board;

void setup() {
  size(640, 640);
  //size(displayWidth, displayHeight);//for android
  noStroke();
  textSize(width/8);
  textAlign(CENTER);

  wKing = loadImage("King.png");
  bKing = loadImage("King1.png");
  wPawn = loadImage("Pawn.png");
  bPawn = loadImage("Pawn1.png");
  wKing.resize(width/8, height/8);
  bKing.resize(width/8, height/8);
  wPawn.resize(width/8, height/8);
  bPawn.resize(width/8, height/8);
  /*for android
   wKing.loadPixels();
   bKing.loadPixels();
   wPawn.loadPixels();
   bPawn.loadPixels();
   */
  startPosition();
}
void draw() {
  showBoard();
  if (gameOver) {
    fill(0, 255, 0);
    text("GAMEOVER", 0, height/2, width, height);
  }
}
void showBoard() {
  for (int i = 0; i<8; i++)
    for (int j = 0; j<8; j++) { 
      if ((i+j)%2 == 0) fill(255, 206, 158);
      else fill(209, 139, 71);
      rect(i*width/8, j*height/8, width/8, height/8);//chessboard
      if (board[j][i] != null) image(board[j][i], i*width/8, j*height/8);//piece
      if (j == bestl && i == bestk) {
        fill(255, 255, 0, 100);//highlight original pos AI
        rect(i*width/8, j*height/8, width/8, height/8);
      }
      if (j == besti && i == bestj) {
        fill(0, 255, 255, 100);//highlight piece AI
        rect(i*width/8, j*height/8, width/8, height/8);
      }
      if (click) {
        if (validMove(down, right, j, i, turn, board)) {
          fill(255, 0, 0, 100);//highlight posibble moves in red
          rect(i*width/8, j*height/8, width/8, height/8);
        }
        if (j == down && i == right && board[j][i] != null) {
          fill(0, 0, 255, 100);//highlight piece in blue
          rect(i*width/8, j*height/8, width/8, height/8);
        }
      }
    }
}
void mousePressed() {
  if (gameOver) startPosition();
  if (click) {
    down1 = round(mouseY / (height/8));
    right1 = round(mouseX / (width/8));
    rect(right1*width/8, down1*height/8, width/8, height/8);
    print(down1, right1);
    if (validMove(down, right, down1, right1, turn, board)) {
      board = movePiece(down, right, down1, right1, board, true);//move piece
      click = false;
    } else {//change piece
      down = down1;
      right = right1;
      click = true;
    }
  } else {
    down = round(mouseY / (height/8));
    right = round(mouseX / (width/8));
    click = true;
  }
  //
  while (turn == red) {
    moveRed();
  }
  //
}
void moveRed() {
  PImage[][] Board = new PImage[8][8];
  for (int k = 0; k<8; k++) {
    for (int l = 0; l<8; l++) {
      Board[k][l] = board[k][l];
    }
  }
  int redMoves;
  int whiteMoves;
  int score = -100;
  int currScore;
  for (int k = 0; k<8; k++) {
    for (int l = 0; l<8; l++) {
      if (notRed(l, k, board)) {
        continue;
      }
      for (int i = 0; i<8; i++) {
        for (int j = 0; j<8; j++) {
          if (validMove(l, k, i, j, turn, board)) {
            Board = movePiece(l, k, i, j, Board, false);//move piece
            redMoves = numMoves(red, Board);
            whiteMoves = numMoves(white, Board);
            currScore = redMoves-whiteMoves;
            if (score<=currScore) {
              score = currScore;
              bestl = l;
              bestk = k;
              besti = i;
              bestj = j;
            }
            //undomove
            for (int a = 0; a<8; a++) {
              for (int b = 0; b<8; b++) {
                Board[a][b] = board[a][b];
              }
            }
          }
        }
      }
    }
  }
  board = movePiece(bestl, bestk, besti, bestj, board, true);//move piece
}
void startPosition() {
  board = new PImage[8][8];

  board[0][1] = bPawn;
  board[0][3] = bPawn;
  board[0][5] = bPawn; 
  board[0][7] = bPawn;
  board[1][0] = bPawn;
  board[1][2] = bPawn;
  board[1][4] = bPawn;
  board[1][6] = bPawn;
  board[2][1] = bPawn;
  board[2][3] = bPawn;
  board[2][5] = bPawn; 
  board[2][7] = bPawn;

  board[5][0] = wPawn;
  board[5][2] = wPawn;
  board[5][4] = wPawn;
  board[5][6] = wPawn;
  board[6][1] = wPawn;
  board[6][3] = wPawn;
  board[6][5] = wPawn;
  board[6][7] = wPawn;
  board[7][0] = wPawn;
  board[7][2] = wPawn;
  board[7][4] = wPawn;
  board[7][6] = wPawn;

  //global variables
  promote = false;
  down=right=down1=right1=-1;
  bestl= bestk= besti= bestj=-1;//AI move
  click = false;
  turn = white;
  gameOver = false;
  doubleJump = false;
}
PImage[][] movePiece(int i0, int j0, int i1, int j1, PImage[][] Board, boolean update) {
  if (Board[i0][j0] == wPawn) {//promote
    if (i1 == 0) {
      Board[i0][j0] = wKing;
      promote = true;
      if (update)doubleJump = false;
    }
  } else if (Board[i0][j0] == bPawn) {//promote
    if (i1 == 7) {
      Board[i0][j0] = bKing;
      promote = true;
      if (update)doubleJump = false;
    }
  }
  Board[i1][j1] = Board[i0][j0];//move piece
  Board[i0][j0] = null;//remove original piece
  if (abs(j0 - j1) == 2) {//jump
    Board[(i0 + i1)/2][(j0 + j1)/2] = null;
    if (!promote) {//can jump again
      if (validMove(i1, j1, i1+2, j1+2, turn, Board) || validMove(i1, j1, i1+2, j1-2, turn, Board) ||
        validMove(i1, j1, i1-2, j1+2, turn, Board) || validMove(i1, j1, i1-2, j1-2, turn, Board)) {
        turn = !turn;
        if (update)doubleJump = true;
        p0 = i1;
        p1 = j1;
      } else {
        if (update)doubleJump = false;
      }
    }
  }
  promote = false;
  if (mustJump(!turn)) {
    if (update)jumping = true;
  } else {
    if (update)jumping = false;
  }
  if (numMoves(!turn, Board) == 0 && update) {//no legal moves
    gameOver = true;
  }
  if (update)
    turn = !turn;
  return Board;
}
int numMoves(boolean side, PImage[][] Board) {//no valid moves
  int x = 0;
  for (int k = 0; k<8; k++) {
    for (int l = 0; l<8; l++) {
      if (side == white) {
        if (notWhite(l, k, Board))
          continue;
      } else if (notRed(l, k, Board)) {
        continue;
      }
      for (int i = 0; i<8; i++) {
        for (int j = 0; j<8; j++) {
          if (validMove(l, k, i, j, side, Board)) x++;
        }
      }
    }
  }
  return x;
}
boolean mustJump(boolean side) {
  for (int k = 0; k<8; k++) {
    for (int l = 0; l<8; l++) {
      if (side == white) {
        if (notWhite(l, k, board))
          continue;
      } else if (notRed(l, k, board)) {
        continue;
      }
      for (int i = 0; i<8; i++) {
        for (int j = 0; j<8; j++) {
          if (validMove(l, k, i, j, side, board) && abs(l-i)==2) return true;
        }
      }
    }
  }
  return false;
}
boolean validMove(int down, int right, int down1, int right1, boolean side, PImage[][] Board) {
  if (down > 7 ||  down < 0 || down1 > 7 ||  down1 < 0 || right > 7 ||  right < 0 || right1 > 7 ||  right1 < 0) {
    return false;
  }
  if (doubleJump) {
    if (down!=p0 || right != p1 || abs(right1-right) != 2) return false;
  }
  if (jumping) {
    if (abs(right1-right) != 2) return false;
  }
  if (side == white) {//white
    if (Board[down][right] == wPawn) {
      if (abs(right1 - right) == 1 && down1 == down-1 && Board[down1][right1] == null) { // move forward 1
        return true;
      }
      if (abs(right1 - right) == 2 && down1 == down-2 && Board[down1][right1] == null && 
        RED(down-1, (right + right1)/2, Board)) { //jump
        return true;
      }
    } else if (Board[down][right] == wKing) {
      if (abs(right1 - right) == 1 && abs(down1-down) == 1 && Board[down1][right1] == null) { // move forward 1
        return true;
      }
      if (abs(right1 - right) == 2 && abs(down1-down) == 2 && Board[down1][right1] == null 
        && RED((down+down1)/2, (right + right1)/2, Board)) { //jump
        return true;
      }
    }
  } else {
    if (Board[down][right] == bPawn) {
      if (abs(right1 - right) == 1 && down1 == down+1 && Board[down1][right1] == null) { // move forward 1
        return true;
      }
      if (abs(right1 - right) == 2 && down1 == down+2 && Board[down1][right1] == null && 
        WHITE(down+1, (right + right1)/2, Board)) { //jump
        return true;
      }
    } else if (Board[down][right] == bKing) {
      if (abs(right1 - right) == 1 && abs(down1-down) == 1 && Board[down1][right1] == null) { // move forward 1
        return true;
      }
      if (abs(right1 - right) == 2 && abs(down1-down) == 2 && Board[down1][right1] == null && 
        WHITE((down+down1)/2, (right + right1)/2, Board)) { //jump
        return true;
      }
    }
  }
  return false;
}
boolean RED (int down1, int right1, PImage[][] Board) {
  return (Board[down1][right1] == bPawn || Board[down1][right1] == bKing);
}
boolean WHITE (int down1, int right1, PImage[][] Board) {
  return (Board[down1][right1] == wPawn || Board[down1][right1] == wKing);
}
boolean notRed (int down1, int right1, PImage[][] Board) {
  return (WHITE(down1, right1, Board) || Board[down1][right1] ==null);
}
boolean notWhite (int down1, int right1, PImage[][] Board) {
  return (RED(down1, right1, Board) || Board[down1][right1] ==null);
}

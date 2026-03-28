let board = [];
let currentPlayer = 'white';
let mode = 'human_human';
let difficulty = 'medium';
let selected = null;
let legalMoves = [];
let gameOver = false;
let autoplay = null;

const boardEl = document.getElementById('board');
const currentPlayerEl = document.getElementById('currentPlayer');
const gameStatusEl = document.getElementById('gameStatus');
const winnerEl = document.getElementById('winner');

async function post(url, data) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data)
  });
  return response.json();
}

function convertBoardForBackend(board) {
  return board.map(row => row.map(cell => {
    if (cell === 'white') return 'white';
    if (cell === 'black') return 'black';
    return 'empty';
  }));
}

async function startNewGame() {
  const size = Number(document.getElementById('sizeSelect').value);
  mode = document.getElementById('modeSelect').value;
  difficulty = document.getElementById('difficultySelect').value;

  const result = await post('/api/new_game', {
    size,
    mode,
    difficulty
  });

  board = result.state["1"] || result.state.board || result.state.Board || result.state.board;
  currentPlayer = 'white';
  selected = null;
  legalMoves = [];
  gameOver = false;
  winnerEl.textContent = '-';
  gameStatusEl.textContent = 'playing';
  normalizeBoardAfterProlog(result.state);
  renderBoard();
   if (mode === 'ai_ai') {
    runAutoplay();
  }
}

function normalizeBoardAfterProlog(stateObj) {
  if (Array.isArray(stateObj.board)) {
    board = stateObj.board;
  } else if (Array.isArray(stateObj[0])) {
    board = stateObj[0];
  } else if (Array.isArray(stateObj)) {
    board = stateObj[0];
  }
}

function renderBoard() {
  const size = board.length;
  boardEl.style.gridTemplateColumns = `repeat(${size}, 72px)`;
  boardEl.innerHTML = '';

  currentPlayerEl.textContent = currentPlayer;

  for (let r = 0; r < size; r++) {
    for (let c = 0; c < size; c++) {
      const cell = document.createElement('div');
      cell.className = `cell ${(r + c) % 2 === 0 ? 'light' : 'dark'}`;

      if (selected && selected.row === r + 1 && selected.col === c + 1) {
        cell.classList.add('selected');
      }

      if (legalMoves.some(m => m.toRow === r + 1 && m.toCol === c + 1)) {
        cell.classList.add('legal');
      }
      cell.addEventListener('click', () => handleCellClick(r + 1, c + 1));

      const value = board[r][c];
      if (value === 'white' || value === 'black') {
        const piece = document.createElement('div');
        piece.className = `piece ${value}-piece`;
        cell.appendChild(piece);
      }

      boardEl.appendChild(cell);
    }
  }
}

async function handleCellClick(row, col) {
  if (gameOver) return;
  if (mode === 'ai_ai') return;
  if (mode === 'human_ai' && currentPlayer === 'black') return;

  const clicked = board[row - 1][col - 1];

  if (clicked === currentPlayer) {
    selected = { row, col };
    const result = await post('/api/legal_moves', {
      board: convertBoardForBackend(board),
      player: currentPlayer
    });
    legalMoves = result.moves.filter(m => m.fromRow === row && m.fromCol === col);
    renderBoard();
    return;
  }
    if (selected) {
    const move = legalMoves.find(m => m.toRow === row && m.toCol === col);
    if (move) {
      await makeMove(move);
    }
  }
}

async function makeMove(move) {
  const result = await post('/api/make_move', {
    board: convertBoardForBackend(board),
    player: currentPlayer,
    move
  });

  if (!result.ok) return;

  board = result.board;
  selected = null;
  legalMoves = [];

  if (result.gameOver) {
    gameOver = true;
    gameStatusEl.textContent = 'finished';
    winnerEl.textContent = result.winner;
    renderBoard();
    return;
  }
  currentPlayer = result.nextPlayer;
  renderBoard();

  if (mode === 'human_ai' && currentPlayer === 'black') {
    setTimeout(aiTurn, 300);
  }
}

async function aiTurn() {
  if (gameOver) return;

  const result = await post('/api/ai_move', {
    board: convertBoardForBackend(board),
    player: currentPlayer,
    difficulty
  });

  if (!result.ok) return;

  board = result.board;
    if (result.gameOver) {
    gameOver = true;
    gameStatusEl.textContent = 'finished';
    winnerEl.textContent = result.winner;
    renderBoard();
    return;
  }

  currentPlayer = result.nextPlayer;
  renderBoard();
}

function runAutoplay() {
  clearInterval(autoplay);
  autoplay = setInterval(async () => {
    if (gameOver) {
      clearInterval(autoplay);
      return;
    }
    await aiTurn();
  }, 500);
}

document.getElementById('newGameBtn').addEventListener('click', startNewGame);

document.getElementById('surrenderBtn').addEventListener('click', async () => {
  if (gameOver) return;
  const result = await post('/api/surrender', { player: currentPlayer });
  gameOver = true;
  gameStatusEl.textContent = 'finished';
  winnerEl.textContent = result.winner;
});

document.getElementById('endGameBtn').addEventListener('click', async () => {
  await post('/api/end_game', {});
  gameOver = true;
  gameStatusEl.textContent = 'ended';
  clearInterval(autoplay);
});

document.getElementById('autoBtn').addEventListener('click', () => {
  if (mode === 'ai_ai') runAutoplay();
});

startNewGame();
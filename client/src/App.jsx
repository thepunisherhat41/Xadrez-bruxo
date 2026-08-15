import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Chess } from 'chess.js';
import { createBattleScene } from './game/createScene.js';

const WS_URL = import.meta.env.VITE_WS_URL || 'ws://localhost:2567';
const INITIAL_CLOCK_MS = 10 * 60 * 1000;
const PIECE_NAMES = { p: 'Peão', r: 'Torre', n: 'Cavalo', b: 'Bispo', q: 'Rainha', k: 'Rei' };

function randomName() {
  return `Mago-${Math.floor(1000 + Math.random() * 9000)}`;
}

function formatClock(milliseconds) {
  const totalSeconds = Math.max(0, Math.ceil(Number(milliseconds || 0) / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${String(minutes).padStart(2, '0')}:${String(seconds).padStart(2, '0')}`;
}

function armyName(color) {
  return color === 'w' ? 'Marfim' : 'Obsidiana';
}

export default function App() {
  const canvasRef = useRef(null);
  const sceneRef = useRef(null);
  const socketRef = useRef(null);
  const chessRef = useRef(new Chess());
  const selectedRef = useRef(null);
  const modeRef = useRef('solo');
  const announcementTimerRef = useRef(null);
  const stateRef = useRef({ color: 'w', connected: false, started: true, gameOver: false });

  const [name, setName] = useState(randomName);
  const [roomCode, setRoomCode] = useState('');
  const [currentRoom, setCurrentRoom] = useState('');
  const [connected, setConnected] = useState(false);
  const [mode, setMode] = useState('solo');
  const [color, setColor] = useState('w');
  const [status, setStatus] = useState('Duelo local pronto');
  const [turn, setTurn] = useState('w');
  const [history, setHistory] = useState([]);
  const [selected, setSelected] = useState(null);
  const [players, setPlayers] = useState([]);
  const [clocks, setClocks] = useState({ w: INITIAL_CLOCK_MS, b: INITIAL_CLOCK_MS });
  const [announcement, setAnnouncement] = useState(null);

  const announce = useCallback((kind, title, subtitle = '') => {
    if (announcementTimerRef.current) clearTimeout(announcementTimerRef.current);
    const payload = { id: Date.now(), kind, title, subtitle };
    setAnnouncement(payload);
    const duration = kind === 'checkmate' ? 3000 : kind === 'check' ? 1900 : 1450;
    announcementTimerRef.current = setTimeout(() => setAnnouncement(null), duration);
  }, []);

  const legalMovesFor = useCallback((square) => {
    try {
      return chessRef.current.moves({ square, verbose: true }).map((move) => move.to);
    } catch {
      return [];
    }
  }, []);

  const applyState = useCallback((payload) => {
    if (!payload?.fen) return;
    chessRef.current.load(payload.fen);
    setTurn(chessRef.current.turn());
    setHistory(payload.history || []);
    if (payload.players) setPlayers(payload.players);
    if (payload.clocks) setClocks(payload.clocks);
    stateRef.current.started = Boolean(payload.started);
    stateRef.current.gameOver = Boolean(payload.gameOver);

    sceneRef.current?.renderFen(payload.fen);
    sceneRef.current?.highlightSquares(null, []);
    sceneRef.current?.setBattleState({ check: payload.check, checkmate: payload.checkmate });
    selectedRef.current = null;
    setSelected(null);

    if (payload.resultReason === 'timeout') {
      const winner = armyName(payload.winner);
      setStatus(`TEMPO ESGOTADO — ${winner} venceu a batalha.`);
      announce('checkmate', 'TEMPO ESGOTADO', `${winner.toUpperCase()} VENCEU`);
    } else if (payload.checkmate) {
      const winner = armyName(payload.winner || (payload.turn === 'w' ? 'b' : 'w'));
      setStatus(`XEQUE-MATE — ${winner} venceu`);
      announce('checkmate', 'XEQUE-MATE', `${winner.toUpperCase()} DOMINOU A ARENA`);
    } else if (payload.draw) {
      setStatus('A batalha terminou em empate.');
      announce('draw', 'EMPATE', 'NENHUM EXÉRCITO CEDEU');
    } else if (payload.check) {
      setStatus('XEQUE! O rei está sob ataque.');
      announce('check', 'XEQUE', 'O REI ESTÁ SOB ATAQUE');
    } else if (payload.gameOver) {
      setStatus('Partida encerrada.');
    } else if (!payload.started && modeRef.current === 'online') {
      setStatus('Sala criada — aguardando adversário');
    } else {
      setStatus(payload.turn === 'w' ? 'Turno do exército de Marfim' : 'Turno do exército de Obsidiana');
    }
  }, [announce]);

  const send = useCallback((payload) => {
    const socket = socketRef.current;
    if (!socket || socket.readyState !== WebSocket.OPEN) return false;
    socket.send(JSON.stringify(payload));
    return true;
  }, []);

  const connect = useCallback(() => {
    if (socketRef.current?.readyState === WebSocket.OPEN) return socketRef.current;
    const socket = new WebSocket(WS_URL);
    socketRef.current = socket;
    socket.addEventListener('open', () => {
      setConnected(true);
      stateRef.current.connected = true;
      setStatus('Conectado ao portal multiplayer');
    });
    socket.addEventListener('close', () => {
      setConnected(false);
      stateRef.current.connected = false;
      if (modeRef.current === 'online') setStatus('Portal multiplayer desconectado');
    });
    socket.addEventListener('message', (event) => {
      const message = JSON.parse(event.data);
      if (message.type === 'room') {
        modeRef.current = 'online';
        setMode('online');
        setCurrentRoom(message.code);
        setColor(message.color);
        stateRef.current.color = message.color;
        stateRef.current.started = message.started;
        stateRef.current.gameOver = false;
        sceneRef.current?.setPerspective(message.color);
        setStatus(message.started ? 'O duelo começou!' : 'Sala criada — aguardando adversário');
        if (message.started) announce('duel', 'DUELO INICIADO', `${armyName(message.color).toUpperCase()} É O SEU EXÉRCITO`);
      }
      if (message.type === 'state') {
        applyState(message);
      }
      if (message.type === 'clock') {
        if (message.clocks) setClocks(message.clocks);
        if (message.turn) setTurn(message.turn);
      }
      if (message.type === 'move') {
        const captured = Boolean(message.move?.captured);
        if (captured) {
          const attacker = sceneRef.current?.pieceLabel(message.move.from) || PIECE_NAMES[message.move.piece] || 'Guerreiro';
          const victim = PIECE_NAMES[message.move.captured] || 'inimigo';
          announce('capture', 'CAPTURA', `${attacker.toUpperCase()} DESTRUIU ${victim.toUpperCase()}`);
        }
        sceneRef.current?.animateMove(message.move.from, message.move.to, captured, () => applyState(message));
      }
      if (message.type === 'error') setStatus(message.message);
      if (message.type === 'opponent-left') {
        stateRef.current.started = false;
        setStatus('Seu adversário deixou a arena. O relógio foi congelado.');
        announce('warning', 'PORTAL ROMPIDO', 'O ADVERSÁRIO DEIXOU A ARENA');
      }
    });
    return socket;
  }, [announce, applyState]);

  const createRoom = useCallback(() => {
    const socket = connect();
    const run = () => send({ type: 'create', name });
    socket.readyState === WebSocket.OPEN ? run() : socket.addEventListener('open', run, { once: true });
  }, [connect, name, send]);

  const joinRoom = useCallback(() => {
    if (!roomCode.trim()) {
      setStatus('Digite o código da sala.');
      return;
    }
    const socket = connect();
    const run = () => send({ type: 'join', code: roomCode.trim().toUpperCase(), name });
    socket.readyState === WebSocket.OPEN ? run() : socket.addEventListener('open', run, { once: true });
  }, [connect, name, roomCode, send]);

  const resetSolo = useCallback(() => {
    modeRef.current = 'solo';
    stateRef.current.started = true;
    stateRef.current.color = 'w';
    stateRef.current.gameOver = false;
    setMode('solo');
    setColor('w');
    setPlayers([]);
    setClocks({ w: INITIAL_CLOCK_MS, b: INITIAL_CLOCK_MS });
    chessRef.current.reset();
    setHistory([]);
    setTurn('w');
    setCurrentRoom('');
    selectedRef.current = null;
    setSelected(null);
    setAnnouncement(null);
    sceneRef.current?.renderFen(chessRef.current.fen());
    sceneRef.current?.highlightSquares(null, []);
    sceneRef.current?.setPerspective('w');
    sceneRef.current?.setBattleState({ check: false, checkmate: false });
    setStatus('Duelo local reiniciado');
  }, []);

  const handleSquareClick = useCallback((square) => {
    const chess = chessRef.current;
    const currentSelected = selectedRef.current;
    const piece = chess.get(square);
    const currentMode = modeRef.current;
    const playerColor = stateRef.current.color;

    if (stateRef.current.gameOver) return;
    if (currentMode === 'online' && (!stateRef.current.started || chess.turn() !== playerColor)) return;

    if (!currentSelected) {
      if (!piece || piece.color !== chess.turn()) return;
      if (currentMode === 'online' && piece.color !== playerColor) return;
      selectedRef.current = square;
      setSelected(square);
      sceneRef.current?.highlightSquares(square, legalMovesFor(square));
      return;
    }

    if (piece && piece.color === chess.turn()) {
      selectedRef.current = square;
      setSelected(square);
      sceneRef.current?.highlightSquares(square, legalMovesFor(square));
      return;
    }

    const legal = chess.moves({ square: currentSelected, verbose: true }).find((move) => move.to === square);
    if (!legal) {
      selectedRef.current = null;
      setSelected(null);
      sceneRef.current?.highlightSquares(null, []);
      return;
    }

    if (currentMode === 'online') {
      send({ type: 'move', from: currentSelected, to: square, promotion: 'q' });
      return;
    }

    const from = currentSelected;
    const attacker = sceneRef.current?.pieceLabel(from) || PIECE_NAMES[legal.piece] || 'Guerreiro';
    const move = chess.move({ from, to: square, promotion: 'q' });
    selectedRef.current = null;
    setSelected(null);
    sceneRef.current?.highlightSquares(null, []);
    if (move.captured) announce('capture', 'CAPTURA', `${attacker.toUpperCase()} DESTRUIU ${PIECE_NAMES[move.captured].toUpperCase()}`);
    sceneRef.current?.animateMove(from, square, Boolean(move.captured), () => {
      sceneRef.current?.renderFen(chess.fen());
      sceneRef.current?.setBattleState({ check: chess.isCheck(), checkmate: chess.isCheckmate() });
      setTurn(chess.turn());
      setHistory(chess.history());
      if (chess.isCheckmate()) {
        stateRef.current.gameOver = true;
        const winner = chess.turn() === 'w' ? 'Obsidiana' : 'Marfim';
        setStatus(`XEQUE-MATE! ${winner} venceu.`);
        announce('checkmate', 'XEQUE-MATE', `${winner.toUpperCase()} DOMINOU A ARENA`);
      } else if (chess.isDraw()) {
        stateRef.current.gameOver = true;
        setStatus('A batalha terminou em empate.');
        announce('draw', 'EMPATE', 'NENHUM EXÉRCITO CEDEU');
      } else if (chess.isCheck()) {
        setStatus('XEQUE!');
        announce('check', 'XEQUE', 'O REI ESTÁ SOB ATAQUE');
      } else {
        setStatus(chess.turn() === 'w' ? 'Turno do exército de Marfim' : 'Turno do exército de Obsidiana');
      }
    });
  }, [announce, legalMovesFor, send]);

  useEffect(() => {
    if (!canvasRef.current) return undefined;
    const battleScene = createBattleScene(canvasRef.current, handleSquareClick);
    sceneRef.current = battleScene;
    battleScene.renderFen(chessRef.current.fen());
    return () => battleScene.dispose();
  }, [handleSquareClick]);

  useEffect(() => () => {
    socketRef.current?.close();
    if (announcementTimerRef.current) clearTimeout(announcementTimerRef.current);
  }, []);

  const turnLabel = turn === 'w' ? 'MARFIM' : 'OBSIDIANA';
  const connectionLabel = connected ? 'PORTAL ONLINE' : mode === 'solo' ? 'MODO LOCAL' : 'OFFLINE';
  const lastMoves = useMemo(() => history.slice(-8).reverse(), [history]);
  const whitePlayer = players.find((player) => player.color === 'w')?.name || (mode === 'solo' ? 'Comandante Marfim' : 'Aguardando...');
  const blackPlayer = players.find((player) => player.color === 'b')?.name || (mode === 'solo' ? 'Comandante Obsidiana' : 'Aguardando...');
  const whiteClock = mode === 'online' ? formatClock(clocks.w) : '∞';
  const blackClock = mode === 'online' ? formatClock(clocks.b) : '∞';

  return (
    <main className="app-shell">
      <canvas ref={canvasRef} className="battle-canvas" />
      <div className="vignette" />

      {announcement && (
        <div key={announcement.id} className={`battle-announcement ${announcement.kind}`}>
          <div className="announcement-line" />
          <strong>{announcement.title}</strong>
          {announcement.subtitle && <span>{announcement.subtitle}</span>}
        </div>
      )}

      <header className="topbar glass">
        <div>
          <div className="eyebrow">ARCANE BATTLE CHESS</div>
          <h1>XADREZ <span>BRUXO</span></h1>
        </div>
        <div className="topbar-status">
          {mode === 'online' && <div className={`side-badge ${color === 'w' ? 'ivory' : 'obsidian'}`}>{armyName(color).toUpperCase()}</div>}
          <div className={`connection ${connected ? 'online' : ''}`}><i />{connectionLabel}</div>
        </div>
      </header>

      <section className="left-panel glass">
        <div className="panel-title">SALA DE DUELO</div>
        <label>Seu codinome</label>
        <input value={name} onChange={(e) => setName(e.target.value.slice(0, 24))} />
        <button className="primary" onClick={createRoom}>CRIAR SALA MULTIPLAYER</button>
        <div className="divider"><span>OU</span></div>
        <div className="join-row">
          <input placeholder="CÓDIGO" value={roomCode} onChange={(e) => setRoomCode(e.target.value.toUpperCase().slice(0, 6))} />
          <button onClick={joinRoom}>ENTRAR</button>
        </div>
        {currentRoom && <div className="room-code"><small>CÓDIGO DA ARENA</small><strong>{currentRoom}</strong></div>}
        <button className="ghost" onClick={resetSolo}>JOGAR LOCAL / TREINO</button>
      </section>

      <section className="right-panel glass">
        <div className="duelists">
          <div className={`duelist obsidian ${turn === 'b' ? 'active' : ''}`}>
            <div className="duelist-sigil">◆</div>
            <div className="duelist-info"><small>OBSIDIANA</small><strong>{blackPlayer}</strong></div>
            <div className="clock">{blackClock}</div>
          </div>
          <div className="versus">VS</div>
          <div className={`duelist ivory ${turn === 'w' ? 'active' : ''}`}>
            <div className="duelist-sigil">◇</div>
            <div className="duelist-info"><small>MARFIM</small><strong>{whitePlayer}</strong></div>
            <div className="clock">{whiteClock}</div>
          </div>
        </div>

        <div className="turn-card">
          <small>AGORA</small>
          <strong>{turnLabel}</strong>
          <span>{selected ? `Selecionado: ${selected.toUpperCase()}` : 'Escolha uma peça'}</span>
        </div>
        <div className="status">{status}</div>
        <div className="moves">
          <div className="panel-title">ÚLTIMOS MOVIMENTOS</div>
          {lastMoves.length === 0 ? <p>Nenhum feitiço lançado ainda.</p> : lastMoves.map((move, index) => <span key={`${move}-${index}`}>{history.length - index}. {move}</span>)}
        </div>
      </section>

      <footer className="hud glass">
        <span>ARRASTE PARA GIRAR</span><b>•</b><span>SCROLL PARA ZOOM</span><b>•</b><span>COMBATE CINEMATOGRÁFICO ATIVO</span>
      </footer>
    </main>
  );
}

import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { Chess } from 'chess.js';
import { createBattleScene } from './game/createScene.js';

const WS_URL = import.meta.env.VITE_WS_URL || 'ws://localhost:2567';

function randomName() {
  return `Mago-${Math.floor(1000 + Math.random() * 9000)}`;
}

export default function App() {
  const canvasRef = useRef(null);
  const sceneRef = useRef(null);
  const socketRef = useRef(null);
  const chessRef = useRef(new Chess());
  const selectedRef = useRef(null);
  const modeRef = useRef('solo');
  const stateRef = useRef({ color: 'w', connected: false, started: true });

  const [name, setName] = useState(randomName);
  const [roomCode, setRoomCode] = useState('');
  const [currentRoom, setCurrentRoom] = useState('');
  const [connected, setConnected] = useState(false);
  const [mode, setMode] = useState('solo');
  const [, setColor] = useState('w');
  const [status, setStatus] = useState('Duelo local pronto');
  const [turn, setTurn] = useState('w');
  const [history, setHistory] = useState([]);
  const [selected, setSelected] = useState(null);

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
    sceneRef.current?.renderFen(payload.fen);
    sceneRef.current?.highlightSquares(null, []);
    selectedRef.current = null;
    setSelected(null);

    if (payload.checkmate) {
      setStatus(`XEQUE-MATE — ${payload.turn === 'w' ? 'Obsidiana' : 'Marfim'} venceu`);
    } else if (payload.check) {
      setStatus('XEQUE! O rei está sob ataque.');
    } else if (payload.gameOver) {
      setStatus('Partida encerrada.');
    } else {
      setStatus(payload.turn === 'w' ? 'Turno do exército de Marfim' : 'Turno do exército de Obsidiana');
    }
  }, []);

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
        setStatus(message.started ? 'O duelo começou!' : 'Sala criada — aguardando adversário');
      }
      if (message.type === 'state') {
        stateRef.current.started = message.started;
        applyState(message);
      }
      if (message.type === 'move') {
        const captured = Boolean(message.move?.captured);
        sceneRef.current?.animateMove(message.move.from, message.move.to, captured, () => applyState(message));
      }
      if (message.type === 'error') setStatus(message.message);
      if (message.type === 'opponent-left') setStatus('Seu adversário deixou a arena.');
    });
    return socket;
  }, [applyState]);

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
    setMode('solo');
    chessRef.current.reset();
    setHistory([]);
    setTurn('w');
    setCurrentRoom('');
    selectedRef.current = null;
    setSelected(null);
    sceneRef.current?.renderFen(chessRef.current.fen());
    sceneRef.current?.highlightSquares(null, []);
    setStatus('Duelo local reiniciado');
  }, []);

  const handleSquareClick = useCallback((square) => {
    const chess = chessRef.current;
    const currentSelected = selectedRef.current;
    const piece = chess.get(square);
    const currentMode = modeRef.current;
    const playerColor = stateRef.current.color;

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
    const move = chess.move({ from, to: square, promotion: 'q' });
    selectedRef.current = null;
    setSelected(null);
    sceneRef.current?.highlightSquares(null, []);
    sceneRef.current?.animateMove(from, square, Boolean(move.captured), () => {
      sceneRef.current?.renderFen(chess.fen());
      setTurn(chess.turn());
      setHistory(chess.history());
      if (chess.isCheckmate()) setStatus('XEQUE-MATE! A arena escolheu seu campeão.');
      else if (chess.isCheck()) setStatus('XEQUE!');
      else setStatus(chess.turn() === 'w' ? 'Turno do exército de Marfim' : 'Turno do exército de Obsidiana');
    });
  }, [legalMovesFor, send]);

  useEffect(() => {
    if (!canvasRef.current) return undefined;
    const battleScene = createBattleScene(canvasRef.current, handleSquareClick);
    sceneRef.current = battleScene;
    battleScene.renderFen(chessRef.current.fen());
    return () => battleScene.dispose();
  }, [handleSquareClick]);

  useEffect(() => () => socketRef.current?.close(), []);

  const turnLabel = turn === 'w' ? 'MARFIM' : 'OBSIDIANA';
  const connectionLabel = connected ? 'PORTAL ONLINE' : mode === 'solo' ? 'MODO LOCAL' : 'OFFLINE';
  const lastMoves = useMemo(() => history.slice(-8).reverse(), [history]);

  return (
    <main className="app-shell">
      <canvas ref={canvasRef} className="battle-canvas" />
      <div className="vignette" />

      <header className="topbar glass">
        <div>
          <div className="eyebrow">ARCANE BATTLE CHESS</div>
          <h1>XADREZ <span>BRUXO</span></h1>
        </div>
        <div className={`connection ${connected ? 'online' : ''}`}><i />{connectionLabel}</div>
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
        <span>ARRASTE PARA GIRAR</span><b>•</b><span>SCROLL PARA ZOOM</span><b>•</b><span>CAPTURAS CINEMATOGRÁFICAS</span>
      </footer>
    </main>
  );
}

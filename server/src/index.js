import { createServer } from 'node:http';
import { Chess } from 'chess.js';
import { WebSocketServer } from 'ws';

const PORT = Number(process.env.PORT || 2567);
const rooms = new Map();

function roomCode() {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let code = '';
  do {
    code = Array.from({ length: 6 }, () => alphabet[Math.floor(Math.random() * alphabet.length)]).join('');
  } while (rooms.has(code));
  return code;
}

function send(ws, payload) {
  if (ws.readyState === 1) ws.send(JSON.stringify(payload));
}

function statePayload(room, type = 'state', move = null) {
  const chess = room.chess;
  return {
    type,
    move,
    code: room.code,
    fen: chess.fen(),
    pgn: chess.pgn(),
    history: chess.history(),
    turn: chess.turn(),
    check: chess.isCheck(),
    checkmate: chess.isCheckmate(),
    draw: chess.isDraw(),
    gameOver: chess.isGameOver(),
    started: room.players.length === 2,
    players: room.players.map(({ name, color }) => ({ name, color })),
  };
}

function broadcast(room, payload) {
  room.players.forEach((player) => send(player.ws, payload));
}

function leaveCurrentRoom(ws) {
  const code = ws.roomCode;
  if (!code || !rooms.has(code)) return;
  const room = rooms.get(code);
  room.players = room.players.filter((player) => player.ws !== ws);
  if (room.players.length === 0) rooms.delete(code);
  else broadcast(room, { type: 'opponent-left' });
  ws.roomCode = null;
}

function createRoom(ws, name) {
  leaveCurrentRoom(ws);
  const code = roomCode();
  const room = { code, chess: new Chess(), players: [{ ws, name: name || 'Mago', color: 'w' }] };
  rooms.set(code, room);
  ws.roomCode = code;
  send(ws, { type: 'room', code, color: 'w', started: false });
  send(ws, statePayload(room));
}

function joinRoom(ws, code, name) {
  const normalized = String(code || '').toUpperCase();
  const room = rooms.get(normalized);
  if (!room) return send(ws, { type: 'error', message: 'Arena não encontrada.' });
  if (room.players.length >= 2) return send(ws, { type: 'error', message: 'Esta arena já tem dois duelistas.' });
  leaveCurrentRoom(ws);
  room.players.push({ ws, name: name || 'Mago', color: 'b' });
  ws.roomCode = normalized;
  send(ws, { type: 'room', code: normalized, color: 'b', started: true });
  send(room.players[0].ws, { type: 'room', code: normalized, color: 'w', started: true });
  broadcast(room, statePayload(room));
}

function makeMove(ws, payload) {
  const room = rooms.get(ws.roomCode);
  if (!room || room.players.length !== 2) return send(ws, { type: 'error', message: 'Aguardando outro duelista.' });
  const player = room.players.find((entry) => entry.ws === ws);
  if (!player) return;
  if (room.chess.turn() !== player.color) return send(ws, { type: 'error', message: 'Ainda não é o seu turno.' });
  try {
    const move = room.chess.move({ from: payload.from, to: payload.to, promotion: payload.promotion || 'q' });
    if (!move) throw new Error('invalid move');
    broadcast(room, statePayload(room, 'move', {
      from: move.from,
      to: move.to,
      san: move.san,
      captured: move.captured || null,
      promotion: move.promotion || null,
    }));
  } catch {
    send(ws, { type: 'error', message: 'Movimento inválido.' });
  }
}

const httpServer = createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'content-type': 'application/json', 'access-control-allow-origin': '*' });
    res.end(JSON.stringify({ ok: true, rooms: rooms.size }));
    return;
  }
  res.writeHead(200, { 'content-type': 'text/plain; charset=utf-8' });
  res.end('Xadrez Bruxo multiplayer server');
});

const wss = new WebSocketServer({ server: httpServer });
wss.on('connection', (ws) => {
  send(ws, { type: 'hello', message: 'Portal conectado.' });
  ws.on('message', (raw) => {
    let payload;
    try { payload = JSON.parse(raw.toString()); } catch { return send(ws, { type: 'error', message: 'Mensagem inválida.' }); }
    if (payload.type === 'create') createRoom(ws, payload.name);
    if (payload.type === 'join') joinRoom(ws, payload.code, payload.name);
    if (payload.type === 'move') makeMove(ws, payload);
  });
  ws.on('close', () => leaveCurrentRoom(ws));
});

httpServer.listen(PORT, '0.0.0.0', () => {
  console.log(`Xadrez Bruxo multiplayer listening on :${PORT}`);
});

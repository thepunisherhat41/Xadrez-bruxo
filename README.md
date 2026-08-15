# Xadrez Bruxo

Um **battle chess 3D multiplayer** para navegador: regras reais de xadrez, arena arcana, peças animadas e capturas cinematográficas.

> O projeto é uma criação original inspirada no gênero de battle chess. Não usa personagens, nomes, brasões, músicas ou assets de Harry Potter.

## O que já existe

- Tabuleiro 3D interativo em Babylon.js.
- 32 peças procedurais 3D com dois exércitos visuais: Marfim e Obsidiana.
- Regras completas e validação de jogadas com `chess.js`.
- Seleção de peça e destaque de movimentos legais.
- Coreografia procedural diferente por classe de peça:
  - peão investe;
  - cavalo salta alto;
  - bispo gira/canaliza durante o avanço;
  - torre ataca com impacto pesado;
  - rainha executa um dash agressivo;
  - rei se move de forma mais lenta e imponente.
- Capturas com reação da vítima, colapso, partículas, anel de impacto e camera shake.
- Banners cinematográficos para captura, xeque, xeque-mate, empate e timeout.
- Áudio procedural original via Web Audio API para início do duelo, captura, xeque, xeque-mate, empate e alertas.
- Atalho `M` para silenciar/reativar os efeitos sonoros.
- Câmera orbital, zoom, iluminação dinâmica, glow e atmosfera/fog.
- Perspectiva automática do tabuleiro conforme a cor do jogador online.
- Modo local para testar imediatamente.
- Salas multiplayer por código de 6 caracteres.
- Servidor WebSocket autoritativo: o servidor valida turno e movimento.
- Relógio multiplayer autoritativo de 10 minutos por jogador.
- Timeout decidido no servidor, sem confiar no relógio do navegador.
- Estado de xeque, xeque-mate, empate, vencedor e histórico sincronizados.
- HUD com duelistas, facção, turno e cronômetros.
- Interface responsiva para desktop e celular.
- GitHub Actions com build do cliente, validação do servidor e smoke test do endpoint `/health`.

## Executar localmente

Requer Node.js 20+.

```bash
npm install
npm run dev
```

- Frontend: `http://localhost:5173`
- Multiplayer: `ws://localhost:2567`
- Health: `http://localhost:2567/health`

Abra duas abas, crie uma sala em uma delas e entre com o código na outra.

## Build

```bash
npm run build
```

## Configuração

No frontend, use `VITE_WS_URL` para apontar para o servidor multiplayer publicado:

```bash
VITE_WS_URL=wss://seu-servidor.exemplo
```

O relógio inicial do servidor pode ser alterado por variável de ambiente:

```bash
INITIAL_CLOCK_MS=600000
```

## Arquitetura

```text
client (React + Babylon.js)
        │
        │ WebSocket
        ▼
server (Node + ws + chess.js)
        │
        ├── autoridade sobre salas e jogadores
        ├── validação de turnos e movimentos
        ├── relógios oficiais
        └── resultado oficial da partida
```

## Próximas evoluções

1. Modelos GLB/GLTF originais para substituir as peças procedurais.
2. Rigging e sequências completas de ataque / defesa / morte por personagem.
3. Música dinâmica e áudio espacial mais avançado.
4. Modos Bullet / Blitz / Rapid configuráveis.
5. Lobby público, matchmaking e reconexão segura.
6. ELO, perfil, histórico persistente e replay.
7. Espectadores com câmera automática cinematográfica.
8. Facções, arenas e cosméticos sem vantagem competitiva.
9. Contas, temporadas, torneios e leaderboards.

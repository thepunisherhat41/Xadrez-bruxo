# Xadrez Bruxo

Um **battle chess 3D multiplayer** para navegador: regras reais de xadrez, arena arcana, peças animadas e capturas cinematográficas.

> O projeto é uma criação original inspirada no gênero de battle chess. Não usa personagens, nomes, brasões, músicas ou assets de Harry Potter.

## O que já existe

- Tabuleiro 3D interativo em Babylon.js.
- 32 peças procedurais 3D com dois exércitos visuais.
- Regras completas e validação de jogadas com `chess.js`.
- Seleção de peça e destaque de movimentos legais.
- Animação de deslocamento e explosão de partículas em capturas.
- Câmera orbital, zoom, iluminação dinâmica, glow e atmosfera/fog.
- Modo local para testar imediatamente.
- Salas multiplayer por código de 6 caracteres.
- Servidor WebSocket autoritativo: o servidor valida turno e movimento.
- Estado de xeque, xeque-mate, empate e histórico sincronizados.
- Interface responsiva para desktop e celular.

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

## Arquitetura

```text
client (React + Babylon.js)
        │
        │ WebSocket
        ▼
server (Node + ws + chess.js)
        │
        └── autoridade sobre salas, turnos e movimentos
```

## Próximas evoluções

1. Modelos GLB/GLTF exclusivos e animações individuais por classe de peça.
2. Sequências de ataque/defesa/morte em vez do efeito procedural inicial.
3. Lobby público, matchmaking e reconexão.
4. Relógio de xadrez e modos Bullet / Blitz / Rapid.
5. ELO, perfil, histórico e replay.
6. Espectadores e câmera automática cinematográfica.
7. Facções, arenas e cosméticos sem vantagem competitiva.
8. Persistência de partidas e contas.

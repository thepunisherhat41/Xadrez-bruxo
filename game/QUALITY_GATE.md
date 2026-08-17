# Xadrez Bruxo — High-Fidelity Vertical Slice Gate

A próxima APK só pode ser gerada para teste humano quando TODOS os itens abaixo estiverem cumpridos. Compilar não é suficiente.

## Referência visual

North star: arena de xadrez mágico dark-fantasy premium, em landscape, com tabuleiro de pedra PBR, runas discretas, personagens humanoides adultos em escala correta, iluminação cinematográfica azul/dourada vs violeta, e HUD mínimo.

A build deve transmitir a mesma categoria visual da concept art aprovada, sem copiar personagens, símbolos, nomes, roupas ou propriedades intelectuais de Harry Potter.

## Bloqueadores visuais

- Nenhum personagem chibi, bobblehead ou low-poly cartunesco como peça principal.
- As seis classes precisam ter silhuetas distintas sem depender de legenda: Peão, Torre, Cavalo, Bispo, Rainha e Rei.
- Não pode haver T-pose em gameplay.
- Nenhuma arma pode atravessar o tabuleiro ou parecer um placeholder geométrico desproporcional.
- As 64 casas devem permanecer claramente legíveis no ângulo tático padrão.
- Nenhum portal, coluna, HUD ou cenário pode bloquear a linha entre câmera e casas jogáveis.
- A câmera inicial precisa parecer intencional/cinematográfica, não uma câmera de editor 3D.
- Rei e Rainha precisam ser visualmente dominantes; Peões precisam ser menores e menos ornamentados.
- As facções precisam ser distinguíveis por materiais, luz, silhueta e VFX, não apenas por círculo colorido no chão.
- Sombras devem ancorar personagens no tabuleiro; personagens não podem parecer flutuar.

## Bloqueadores de gameplay

- Tap seleciona a casa correta no celular.
- Legal moves são destacados com leitura imediata.
- Captura executa uma sequência curta: aproximação/ataque → reação → morte/dissolução → retorno automático à câmera tática.
- Nenhuma animação decide resultado da jogada; regras continuam determinísticas.
- Vs IA funciona sem internet.
- 1v1 local funciona sem internet.
- Save/resume offline funciona sem internet.
- Online usa o servidor autoritativo existente e não altera regras locais silenciosamente.

## Mobile

- Gameplay apenas em sensor-landscape.
- Validar enquadramento em pelo menos 16:9, 19.5:9 e 20:9.
- Touch targets de UI >= 44 px equivalentes.
- Drag de câmera limitado; pinch zoom limitado; nenhum gesto pode tornar o tabuleiro injogável.
- Preset **Alta Qualidade** prioriza arte/PBR/efeitos.
- Preset **Performance** reduz efeitos e resolução de sombras sem alterar gameplay.

## Performance budget

A build não será aprovada só por atingir FPS alto com visual ruim. O alvo é qualidade escalável:

- Alta Qualidade: alvo 30–45 FPS em aparelhos intermediários/fortes, com PBR, glow, sombras principais e efeitos de captura.
- Performance: alvo 60 FPS quando o hardware permitir, reduzindo sombras, partículas e pós-processamento.
- O jogo deve permanecer responsivo mesmo quando uma captura cinematográfica estiver ocorrendo.

## Evidências obrigatórias antes de APK

1. Screenshot real gerado pelo Godot em 1920×1080.
2. Screenshot real gerado pelo Godot em proporção 19.5:9.
3. Screenshot real gerado pelo Godot em proporção 20:9.
4. Smoke test de regras/IA verde.
5. Captura visual sem T-pose e com 32 peças carregadas.
6. Teste real de seleção/movimento/captura.
7. Só depois disso: gerar APK.

Se qualquer screenshot parecer um protótipo amador, a vertical slice está REPROVADA mesmo que todos os testes técnicos estejam verdes.

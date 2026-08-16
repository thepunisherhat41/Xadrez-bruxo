# Xadrez Bruxo — Visual Contract

## North star

A partida deve parecer um duelo de fantasia cinematográfico e adulto, não um tabuleiro com bonecos chibi.

O alvo visual é uma arena de pedra escura com runas, duas ordens de guerreiros humanoides proporcionais, luz fria/dourada contra violeta/vermelho, silhuetas distintas por classe e câmera tática inclinada. O jogador deve reconhecer imediatamente peão, torre, cavalo, bispo, rainha e rei sem depender de ícones.

## Regras que bloqueiam release

1. **Mobile landscape obrigatório.** Android/iOS usam sensor-landscape; portrait nunca é gameplay.
2. **Tabuleiro inteiro legível.** As 64 casas precisam caber na tela durante o modo tático padrão.
3. **Nenhum cenário entre câmera e tabuleiro.** Portais, colunas e arquitetura ficam atrás ou nas laterais da linha de visão.
4. **Sem chibi/bobblehead.** Personagens têm proporção humanoide adulta e cabeça proporcional.
5. **Peça ocupa no máximo ~72% da largura da casa** no enquadramento inicial, evitando amontoamento.
6. **Câmera não é livre.** Drag permite apenas uma órbita curta; pinch altera zoom dentro de limites competitivos.
7. **Captura é cinematográfica, não confusa.** Push-in curto, ataque, impacto, morte/dissolução e retorno automático ao ângulo tático em menos de 3 segundos.
8. **UI mínima durante a partida.** Relógios, turno, conexão e menu. Nada cobre o centro do tabuleiro.
9. **60 FPS é o alvo mobile.** Sombras, partículas e pós-processamento têm presets e orçamento por aparelho.
10. **Offline é primeiro-classe.** Vs IA e 1v1 local não abrem WebSocket e funcionam sem internet.

## Facções originais

### Ordem Astral
- armadura azul-marinho, aço escovado e ouro envelhecido;
- magia azul/branca;
- leitura de cavalaria, magos e guardiões;
- rei como comandante arcano;
- rainha como arquimaga de batalha.

### Corte do Eclipse
- ferro negro, tecido violeta, detalhes carmesim;
- magia violeta/vermelha;
- necromantes, cavaleiros sombrios e guardiões rúnicos;
- rei como soberano do eclipse;
- rainha como feiticeira do véu.

## Silhuetas por classe

- **Peão:** soldado/aprendiz com espada curta ou lança.
- **Torre:** guardião pesado/golem humanoide, ombros largos, martelo/escudo.
- **Cavalo:** cavaleiro montado ou guerreiro com montaria arcana; nunca apenas um cavalo decorativo.
- **Bispo:** mago de cajado, túnica longa, foco mágico claramente visível.
- **Rainha:** personagem mais agressiva e elegante, arma + magia, capa e coroa flutuante discreta.
- **Rei:** comandante pesado, espada/cetro, manto e aura régia.

## Câmera

- Base: landscape 16:9, testada também em 19.5:9 e 20:9.
- Perfil tático: perspectiva 42–48°, tabuleiro inteiro visível, horizonte discreto.
- Perfil captura: aproximação curta no quadrante da luta; sem corte brusco e sem perder orientação espacial.
- Black joga com rotação de 180° da arena, mantendo a mesma composição.

## Arte externa

Somente assets com licença compatível e proveniência registrada. Para a base humanoide e animações, priorizar os kits CC0 recentes do Quaternius (Universal Base Characters, Modular Character Outfits - Fantasy e Universal Animation Library). O jogo não usa personagens, nomes, brasões, roupas, música ou iconografia de Harry Potter; a inspiração é apenas o conceito genérico de xadrez mágico com peças vivas.

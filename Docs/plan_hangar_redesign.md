**Estado em 2026-09-04: as Fases 1 (§2) e 2 (§3) estão implementadas e verificadas.**
Layout encolhido, robô grande, peças/stats escondidos, fundo novo em pixel art. No
processo, apareceu e foi corrigido um bug de renderização que não tinha nada a ver com
o layout (§2.5), e a Fase 2 saiu diferente do desenho original — ver §3.5. **Pendência
real, não decisão de escopo: a arte nova está no working tree do submódulo
(`assets/source`) e do repo-irmão (`botbattle_assets`), sem commit nem push nos dois —
ver §3.6.**

# Plano de execução: hangar vira vitrine do robô

O hangar hoje é uma tela de edição: nome, atributos, carga, abas de peças/exoesqueleto
— tudo visível ao mesmo tempo, disputando espaço com o robô. Este plano faz o robô ser
o motivo da tela: grande, ao centro, num cenário próprio, sem peças nem status
disputando atenção.

**Escopo desta rodada: só o essencial.** O robô fica grande e a peça deixa de ter uma
lista sempre visível para escolher; mas escolher peça clicando *nela* (no próprio robô)
é a próxima etapa, documentada na §5, e não entra aqui. Por ora não há forma de trocar
peça a partir desta tela — só de olhar o robô e apertar BATALHAR.

Complementa [feature_hangar.md](feature_hangar.md), que continua descrevendo o *sistema*
de peças (isso não muda). Este documento é só a apresentação.

---

## 0. Decisões tomadas (sessão de 2026-09-04)

| Tema | Decisão |
| --- | --- |
| Peças | Somem da tela principal. Sem painel, sem gaveta, sem tela separada **por enquanto** — a lista de peças não tem mais um botão que a abra nesta rodada. |
| Vida e status (FOR/AGI/DEF/VIDA/EN) | Somem também, por completo — nenhum lugar do hangar mostra o agregado. Continuam existindo na batalha. |
| Escala do robô | Grande, "hero shot" — domina a tela. Número exato não foi travado; calibra-se olhando o jogo rodando (§2.3), como o resto do projeto já faz. |
| Fundo | Arte nova de oficina/hangar em pixel art, gerada pelo PixelLab, no mesmo formato em camadas (`sky`/`backdrop`/`floor`) que a arena de batalha já usa — identidade visual própria, diferente do `neon_grid`. |
| Próxima etapa (fora desta rodada) | Trocar peça vai passar a ser: tocar na peça desenhada no robô → escolher a opção daquele encaixe. Fica registrado na §5, não implementado agora. |

---

## 1. O que muda

```
HOJE                              DEPOIS
┌──────────────────┐              ┌──────────────────┐
│ [Nome]            │              │ [Nome]            │
│ FOR22 AGI18 DEF8   │              │                   │
│ ▬▬▬▬▬░░ 44/120     │              │                   │
├──────────────────┤              │                   │
│                    │              │        🤖          │
│       🤖 (1.3×)     │              │     (grande,       │
│                    │              │   em evidência)     │
│                    │              │                   │
├──────────────────┤              │                   │
│ Peças │Exoesq.     │              │                   │
│ Cabeça: —          │              ├──────────────────┤
│ Braço D: Espada    │              │   [ BATALHAR ]     │
│ Braço E: Plasma     │              └──────────────────┘
│ Perna E: Ágil       │
│ Perna D: Ágil       │
│ ...                 │
│ [ BATALHAR ]        │
└──────────────────┘
```

Nada do **modelo** muda — `Loadout`, `Chassis`, `Part`, `PartCatalog` e a persistência
em `user://loadout.json` continuam exatamente como estão (ver
[feature_hangar.md](feature_hangar.md) §6-7). O jogador batalha com a montagem que
já tem salva (ou o `r7.tres` padrão, no primeiro acesso). Isso é intencional: sem uma
forma de trocar peça nesta tela, editar a montagem volta a exigir código direto no
`.tres` ou um teste — igual acontecia antes de o hangar existir. Aceitável como estado
intermediário, porque a §5 é o próximo passo já combinado.

---

## 2. Fase 1 — layout: encolher a UI, dar a tela para o robô

**Arquivos.** `scenes/hangar/hangar.tscn`, `scenes/hangar/hangar.gd`

### 2.1 Esconder, não apagar

O painel de peças (`Tabs`, `Scroll`/`Content`) e a linha de status (`StatsLabel`,
`LoadRow`) **continuam existindo na cena e no script** — só ficam com `visible = false`
e sem nenhum botão que os revele. Três motivos para não apagar:

- é exatamente o material que a §5 (tocar na peça) vai reaproveitar — `_build_part_list`,
  `_make_option` e `_delta_text` já fazem a escolha de uma peça de um encaixe, só falta
  o gatilho ser um toque no robô em vez de um item de lista;
- é o mesmo padrão que o projeto já usa: `ui/hitbox_debug_panel.gd` fica
  `visible = Debug.enabled` dentro de um `VBoxContainer` (`battle.tscn`,
  `TopColumn/HitboxPanel`) — escondido não ocupa espaço no layout, e reaparecer é só
  virar a flag;
- apagar e recriar depois custa mais do que manter dormente.

Em `VBoxContainer`, um filho com `visible = false` não reserva espaço — é o mecanismo
que faz isso funcionar sem reescrever o layout ao redor.

**No `hangar.tscn`:**

```
UI/Root/TopPanel/VBox/StatsLabel   → visible = false
UI/Root/TopPanel/VBox/LoadRow      → visible = false
UI/Root/BottomPanel/VBox/Tabs      → visible = false
UI/Root/BottomPanel/VBox/Scroll    → visible = false
```

`hangar.gd` não muda nessas linhas: `_refresh()` continua atualizando `stats_label` e
`load_bar` por baixo dos panos (barato, e mantém o código pronto pra §5), e
`_build_tabs()`/`_rebuild_content()` continuam construindo dentro de containers que
simplesmente não aparecem.

### 2.2 Encolher os dois painéis

Hoje `TopPanel` e `BottomPanel` têm altura **fixa** (`offset_bottom = 330.0` e
`offset_top = -880.0`, respectivamente) — a altura não vem do conteúdo, então esconder
os filhos acima deixa uma faixa translúcida vazia sobrando (o `PanelContainer` desenha o
`StyleBoxFlat` do tema no retângulo inteiro, preenchido ou não). Os dois têm que encolher
junto:

| Painel | Offset de hoje | Aplicado | Por quê |
| --- | --- | --- | --- |
| `TopPanel` | `offset_bottom = 330.0` | **170.0** | só sobra `NameEdit` (78 de altura) + as margens do painel (22 em cima, 22 embaixo) — bate exato |
| `BottomPanel` | `offset_top = -880.0` | **-200.0** | só sobra `BattleButton` + margens do painel e do botão, com uma folga pequena |

Verificado em 1080×1920 de verdade (nunca no preview de desktop 540×960, que aplica um
`0.5` extra de `stretch/mode="canvas_items"` e faz tudo parecer errado) — ver §2.5 para
como a verificação foi feita.

### 2.3 O robô: maior, mais para a frente

`Robot` (`Node2D`) e seu filho `Sprite` (`RobotSprite`) crescem para preencher o espaço
que os dois painéis deixaram de ocupar. Aplicado, contra `RobotSprite.HEIGHT = 347`
(altura da montada, com a origem nos pés, `actors/robot_sprite.gd:17`):

| | Antes | Aplicado |
| --- | --- | --- |
| `Robot.position` | `Vector2(540, 990)` | **`Vector2(540, 1680)`** |
| `Sprite.scale` | `Vector2(1.3, 1.3)` | **`Vector2(3.6, 3.6)`** |

Altura na tela ≈1250px (65% dos 1920px), pés a 40px do topo do `BottomPanel` novo,
~260px de folga acima da cabeça dentro da faixa livre entre os dois painéis — número
verificado batendo captura real (§2.5), não só calculado.

### 2.4 Pronto quando

- Abrir o hangar mostra: nome editável no topo (faixa fina), robô grande ao centro,
  `BATALHAR` embaixo (faixa fina) — nada de peças, nada de FOR/AGI/DEF/VIDA/EN visível.
- Trocar o nome e apertar `BATALHAR` ainda funciona como hoje (salva e vai pra
  batalha) — nada no fluxo de `_on_battle_pressed()` muda.
- `grep -n "visible = false" scenes/hangar/hangar.tscn` mostra as quatro linhas da §2.1.
- **Verificado** com captura real da cena (não maquete) — ver §2.5.

### 2.5 Achado durante a implementação: um bug de renderização, não de calibração

A escala maior expôs um problema que na escala antiga (1.3×) passava despercebido num
canto: as peças acopladas nos braços (espada, canhão de plasma) apareciam flutuando
longe do braço, em vez de na mão. A primeira hipótese — encaixes nunca calibrados para
a arte do PixelLab (`plan_pixellab.md` §12, "peça aparece torta, não some") — **era só
metade do problema**.

**O que era calibração de verdade.** `art_offset`/`art_height` dos encaixes `arm_left`/
`arm_right` em `anatomy/humanoid.tres` vinham da era Aseprite (128×256), nunca medidos
contra a arte real (136×136). Foram recalibrados com o mesmo método do
`botbattle_assets/tools/calibrate.py` (medir bbox de alpha, resolver `art_height`/
`art_offset` contra um alvo) — usando como alvo a própria mão do braço, já calibrada
(`arm_left.art_offset = (-65, 159)` em `humanoid.tres`), medida com Pillow contra
`short_sword` e `plasma_cannon` (as duas peças que hoje ocupam esses encaixes) e
resolvida pela fórmula:

```
art_offset.x = cx_alvo   - ((x0+x1)/2 - largura_canvas/2)
art_offset.y = base_alvo + (altura_canvas - y1)
```

Isso **melhorou** a posição (as peças pararam de flutuar longe), mas não resolveu:
espada e canhão continuavam caindo os dois do mesmo lado, um por cima do outro.

**O bug de verdade estava em `actors/part_node.gd`.** `_draw_art()` espelhava peças do
braço direito com um `Rect2` de destino de largura **negativa** — a técnica de sempre
para espelhar em Godot, e o comentário no código dizia exatamente isso. Só que, neste
projeto (renderer de compatibilidade, `GLES3`/Metal), um `Rect2` de destino com largura
negativa **não espelha no lugar**: o quadro inteiro sai deslocado por uma largura
inteira do próprio desenho. Provado isolando a variável — desligar `flip_h` na mesma
peça, sem tocar em mais nada, jogava a espada exatamente onde a conta prevê. `draw_
texture_rect_region` com `src_rect` invertido (a alternativa óbvia) tem o mesmo problema.

**A correção** troca o espelho de "retângulo de destino negativo" por uma transform de
desenho temporária em torno do próprio centro da peça:

```gdscript
if flip_h:
    draw_set_transform(Vector2(2.0 * art_offset.x, 0.0), 0.0, Vector2(-1.0, 1.0))
    draw_texture_rect(_texture, dest, false)
    draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
else:
    draw_texture_rect(_texture, dest, false)
```

**Por que isso importa além do hangar.** `PartNode.flip_h` é usado por qualquer encaixe
cuja chave termine em `_right` — hoje só `arm_right` (`_mount_flip_h`,
`robot_sprite.gd`), mas em qualquer visão montada, inclusive a Sentinela V-9 **na
batalha** (que usa `blade_forearm` nesse mesmo encaixe). O bug já existia lá; só não
tinha sido notado porque a escala pequena escondia o deslocamento. Corrigir em
`part_node.gd` conserta os dois lugares de uma vez — não é um conserto local do hangar.

**Verificação.** `BOTBATTLE_SEED=1 -s tools/simulate.gd` saiu **idêntico** à linha-base
de `plan_desvios.md` (a mudança é só de desenho, não toca regra) e `-s tools/
smoke_test.gd` completou uma batalha inteira sem erro novo. A prova visual foi uma
ferramenta descartável que isolava uma peça por vez e comparava a posição prevista pela
transform real do nó (`PartNode.get_global_transform() * art_offset`) contra o pixel
medido na captura — o processo de descoberta em si (não fica no repo; só a correção e
`tools/capture_hangar.gd`, que serve à §4).

---

## 3. Fase 2 — fundo novo em pixel art

**Arquivos.** `scenes/hangar/hangar.tscn` (nó `Background`), arte nova em
`botbattle_assets/scenarios/hangar_bay/` (via submódulo, `assets/source/scenarios/`)

O compositor já existe e já está ligado — `scenes/battle/arena_background.gd`, o mesmo
script que desenha a arena de batalha (`Background` no `hangar.tscn` já usa esse script,
hoje com `arena_id` vazio, então cai no procedural com `horizon = 0.36`). Não precisa de
código novo, só de arte e da troca de `arena_id`.

### 3.1 Depois da Fase 1, não antes

O `floor.png` da arena tem que assentar exatamente onde os pés do robô pisam — e isso só
fica definitivo depois de a §2.3 calibrar a posição/escala do robô. Gerar a arte antes
arrisca ter que regerar a camada de piso quando a posição mudar (o mesmo raciocínio de
`plan_pixellab.md` §0.2, que também não fecha a composição antes do que ela depende).

### 3.2 A receita (igual à da arena, `plan_pixellab.md` §9)

Três camadas, 216×384 cada (limite de 400px por lado do gerador,
`plan_pixellab.md` §13.3), esticadas para 1080×1920 em escala inteira (×5):

| Camada | Conteúdo | Opaca? |
| --- | --- | --- |
| `sky.png` | teto da oficina / luz de fundo | sim |
| `backdrop.png` | estrutura do hangar — vigas, catracas, prateleiras de peças ao fundo | não |
| `floor.png` | piso da baia onde o robô está apoiado, com a linha do horizonte batendo com o `horizon` do compositor | não |

Duas armadilhas já documentadas (`plan_pixellab.md` §9.2) valem de novo aqui:
**`no_background: true` não é respeitado** pelo gerador (recortar por chroma-key contra
a cor do canto), e **o gerador inventa conteúdo fora do pedido** (conferir cada camada
antes de aceitar).

Uma vez geradas, o caminho é `assets/source/scenarios/hangar_bay/{sky,backdrop,floor}.png`
(dentro do submódulo `botbattle_assets`, mesma árvore da arena) e a troca é uma linha:

```gdscript
# hangar.tscn, nó Background
arena_id = "hangar_bay"
horizon = <o mesmo valor que a Fase 1 usou pra plantar os pés do robô>
```

### 3.3 O fallback continua obrigatório

Se **qualquer** uma das três camadas faltar, `arena_background.gd` já cai sozinho no
`_draw()` procedural (`plan_pixellab.md` §9.1: "meia arena desenhada é pior que
nenhuma") — não há nada a fazer aqui além de não quebrar esse caminho. É por isso que dá
para entregar a Fase 1 sozinha, com o `horizon` procedural de hoje, e a Fase 2 depois,
sem bloquear uma na outra.

### 3.4 Pronto quando

O hangar sobe com `arena_id = "hangar_bay"` mostrando a arte nova, e sobe também com
`arena_id = ""` mostrando o procedural de hoje — os dois caminhos continuam funcionando.

### 3.5 O que saiu diferente do desenho da §3.2

**As três camadas viraram uma.** As duas armadilhas da §3.2 se confirmaram, mas a
segunda (`no_background` ignorado) foi mais séria do que o esperado: as três gerações
saíram **100% opacas** (`alpha=255` em todo pixel, conferido com Pillow) — inclusive a
pedida como `sky` (que já deveria ser opaca). Diferente da arena de batalha, nenhuma
tinha uma área de fundo uniforme pra recortar por chroma-key: são cenas completas
(teto+paredes+piso, tudo numa imagem só), porque o gerador insiste em compor uma cena
inteira a partir de qualquer descrição de ambiente, não um recorte isolado — e uma delas
(pedida como "teto") veio com uma silhueta de robô inventada dentro, inutilizável (o jogo
já tem seu próprio robô; dois na mesma cena confunde).

Das três gerações, a pedida como piso saiu como um corredor completo — teto, paredes e
piso em perspectiva de ponto único, luz âmbar, faixas de risco amarelas — coerente e forte
sozinha. Virou a camada `sky.png` inteira (é a que desenha primeiro, ao fundo);
`backdrop.png` e `floor.png` são **216×384 totalmente transparentes**, só pra satisfazer a
checagem de 3 arquivos do `_load_layers()` sem desenhar nada por cima. O motivo de cada
escolha está anotado em `metadata.json` do próprio cenário.

**`horizon` não precisou mudar.** Como só há uma camada com conteúdo, não existe mais uma
costura entre "onde o chão da arte começa" e o `horizon` do compositor — a imagem cobre o
quadro inteiro. `hangar.tscn` manteve `horizon = 0.36` (só importa pro fallback
procedural, que não aparece enquanto as 3 camadas existirem).

**A cor do spotlight sob o robô precisou mudar junto.** `_platform()` (as elipses sob os
pés) usa `grid_color`/`floor_color`, que são `@export` do compositor e **não** vêm da
arte gerada — ficam com o azul frio do `neon_grid` por padrão, mesmo depois da troca de
`arena_id`. Sobrepor um anel azul frio numa arte âmbar quente ficaria destoante, então o
nó `Background` do hangar ganhou:

```gdscript
floor_color = Color(0.11, 0.078, 0.047, 1)   # antes: o padrão frio do script
grid_color = Color(0.88, 0.62, 0.32, 1)      # antes: o padrão frio do script
```

### 3.6 Duas pegadinhas técnicas — guarde para a próxima arte

**Duplicidade de repositório.** `botbattle_assets/` (o repo-irmão, fora do projeto Godot)
e `assets/source/` (o submódulo, dentro dele) são **dois checkouts separados do mesmo
remoto** — escrever num não aparece no outro. A arte entrou primeiro no repo-irmão (fluxo
natural pra revisar antes de comprometer o projeto) e teve que ser **copiada manualmente**
para dentro do submódulo pra o jogo enxergar. Isso não é overhead novo desta sessão — é
exatamente a mecânica que `plan_pixellab.md` §0 já descreve ("Fase 0: commitar e dar push
na arte" antes de tocar no submódulo) — só que aqui os dois ficaram **sem commit e sem
push nos dois lados**. Antes de qualquer outra pessoa (ou máquina) rodar o jogo, alguém
precisa: commitar+dar push em `botbattle_assets` (ou diretamente no checkout de
`assets/source`, já que apontam pro mesmo remoto) e então `git submodule update` (ou
equivalente) do lado de dentro — senão o hangar volta a cair no procedural em qualquer
clone novo, silenciosamente, exatamente o alerta que `plan_pixellab.md` §0.2 já dava.

**PNG solto não é textura carregável.** Copiar um `.png` para dentro de `res://` não
basta — sem o `.png.import` gerado pelo importador do Godot, `ResourceLoader.exists()`
devolve `false` e `_load_layers()` cai no fallback procedural **sem erro nenhum no
console**, o que pareceu, por um instante, que `arena_id` estava errado. A forma de gerar
o `.import` sem abrir o editor:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --editor --quit-after 30
```

Isso escaneia e reimporta o projeto inteiro e fecha sozinho. É o mesmo mecanismo que já
roda automaticamente ao abrir o editor normal — só precisa ser forçado quando o arquivo
chegou por fora dele (cópia manual, script, outra máquina).

---

## 4. Verificação

Não há simulador nem regra de combate envolvida (isso é só apresentação), então a
verificação é visual — mas não precisa ser só no olho: `tools/capture_hangar.gd` sobe
`hangar.tscn` de verdade (não uma maquete) e salva `.captures/hangar.png`:

```bash
# a cena sobe sem erro
/Applications/Godot.app/Contents/MacOS/Godot --path . --quit-after 240

# captura real da cena, pra julgar enquadramento/escala sem abrir o editor
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/capture_hangar.gd

# abrir de verdade e olhar — julgue sempre em 1080×1920, nunca no preview de desktop
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

Foi assim que a §2.5 foi encontrada e verificada — abrir só no editor, num raciocínio
"deve estar certo", não teria pego o deslocamento.

Confira: nome editável funciona, `BATALHAR` ainda leva pra batalha com a montagem certa
(a que já estava salva), nenhuma peça nem stat aparece na tela, o robô é a primeira
coisa que o olho encontra.

---

## 5. Fora de escopo (próxima etapa, não desta rodada)

- **Tocar na peça pra trocar.** Cada `PartNode` já existe como nó próprio na árvore do
  `RobotSprite` (um por osso e por encaixe — `feature_parts.md`), então cada um pode
  virar uma área de toque. O fluxo natural: tocar num pedaço do robô → abre um picker
  só daquele encaixe (a mesma lista que `_build_part_list(key)` já monta hoje, dormente
  desde a §2.1) → escolhe → `loadout.equip(key, part)` → `_refresh()`. A diferença para
  o painel de hoje é só o gatilho (toque no desenho, não item de uma lista sempre
  visível).
- **Reexibir status.** Se algum dia precisar aparecer de novo (mesmo que só dentro do
  picker por encaixe da próxima etapa), `stats_label`/`load_bar` já calculam o valor
  certo — é só tirar o `visible = false`.
- **Escolha de exoesqueleto (aba "Exoesqueleto").** Mesma situação das peças: a lógica
  (`_build_chassis_list`, `_pick_chassis`) fica dormente, sem entrada nesta tela.
- **Animação/idle do robô na vitrine** (respirar, girar, brilho). Não foi pedido; o
  `RobotSprite` já tem uma animação `idle` que toca sozinha (`IDLE_ANIMATION`,
  `robot_sprite.gd`) — nada a fazer aqui a menos que se queira mais.

---

## 6. Onde cada coisa mora

| Arquivo | Papel nesta mudança |
| --- | --- |
| `scenes/hangar/hangar.tscn` | Layout: painéis menores, robô maior, peças/stats escondidos |
| `scenes/hangar/hangar.gd` | Sem mudança de lógica — só passa a alimentar containers escondidos |
| `anatomy/humanoid.tres` | Calibração real dos encaixes `arm_left`/`arm_right` (§2.5) |
| `actors/part_node.gd` | Correção do espelho de peças do lado direito (§2.5) — vale para hangar e batalha |
| `tools/capture_hangar.gd` | Ferramenta nova: captura real do hangar pra verificação (§4) |
| `scenes/battle/arena_background.gd` | Reaproveitado sem alteração — compositor de camadas + fallback |
| `botbattle_assets/scenarios/hangar_bay/` | Arte nova (submódulo `assets/source`) |
| `Docs/feature_hangar.md` | Continua descrevendo o *sistema* de peças — não muda com este plano |
| `Docs/plan_pixellab.md` §9 | Receita de referência para gerar as camadas |

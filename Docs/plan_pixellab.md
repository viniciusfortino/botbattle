# Plano: integração PixelLab — duas visões do robô e cenário em pixel art

Especificação de execução. Foi levantada lendo o código atual (`robot_sprite.gd`,
`part_node.gd`, `art_library.gd`, `arena_background.gd`, `hangar.gd`, `battle.gd`,
`humanoid.tres`, `battle.tscn`) e medindo os assets do repositório de arte.

**Leia a seção 11 (armadilhas) antes da primeira linha de código** — quatro delas quebram
o resultado em silêncio, e uma (§11.1) inviabiliza a visão montada se for ignorada.

---

## 1. O que muda

O jogo desenha tudo por código hoje. O `RobotSprite` monta uma árvore de nós a partir da
`Anatomy` (um `PartNode` por osso e por encaixe) e cada nó desenha a arte quando ela
existe, ou uma silhueta procedural quando não existe. O cenário é um `_draw()`. O jogador
escolhe as cores do robô no hangar.

A partir daqui o robô passa a ter **duas visões**, e a escolha de cor acaba.

| Visão | Quem usa | Direção | Como é montada |
| --- | --- | --- | --- |
| **fullbody** | O herói, na batalha | perfil (`east` / `west`) | Uma imagem só: `characters/mk1/full` |
| **montada** | O inimigo, na batalha; o robô do jogador, no hangar | frontal (`south`) | Uma imagem por osso/peça, composta pela `Anatomy` |

A visão montada existe para o jogador **bater o olho e identificar as peças do
adversário** — e é a mesma tela em que ele escolhe as próprias peças no hangar. É por isso
que ela é frontal: perfil esconde metade dos encaixes.

### Decisões tomadas

| Tema | Decisão |
| --- | --- |
| Ligação dos repos | **Submódulo git.** Symlink não serve: o time é mais de uma pessoa, em máquinas diferentes. |
| Resolução | Mantém 1080×1920, pixel art escalado com filtro *nearest* e fator inteiro. |
| Composição da arena | **Inimigo ao centro e maior** (é o que precisa ser lido); **herói de perfil no canto inferior**, recortado pelo quadro, como moldura. |
| Cor do robô | A **escolha** acaba. O **dado** de cor permanece, autorado por unidade — ver §7. |
| Cenário | Camadas separadas (céu, fundo, piso); posição das plataformas continua no código. |

---

## 2. Pendências

### 2.1 MCP do PixelLab — bloqueia a geração de arte

O servidor está registrado no caminho antigo do projeto (`~/Projects/botbattle`), então não
carrega em `~/Projects/project_bottobatlle`. **Será reinstalado.** Enquanto isso:

- **as fases 0 a 4 rodam sem ele**, com o que já existe em `characters/mk1/`;
- **as fases 5 a 8 dependem dele**, porque exigem arte que ainda não foi gerada.

Quando o MCP voltar, **a primeira coisa a fazer é levantar o que as ferramentas dele
sabem fazer** — em especial as duas perguntas abaixo, que podem eliminar trabalho manual:

1. **Dá para exportar partes alinhadas a um esqueleto/mannequin comum?** O
   `metadata.json` já traz `template_id: "mannequin"`, e a extensão do PixelLab no Aseprite
   tem `skeleton.lua`, `pose-references.lua` e `generate-animation-skeleton.lua`. Se a
   resposta for sim, a calibração da §6.3 — o item mais caro deste plano — praticamente
   desaparece.
2. **Dá para gerar variantes de estado** (`damaged`, `critical`) de uma peça já existente,
   mantendo a identidade visual? Disso depende o dano por parte voltar a aparecer (§6.4).

### 2.2 Arte que ainda não existe

| O que | Situação |
| --- | --- |
| Herói fullbody | **Pronto** — `characters/mk1/full`, poses `Idle` e `fighting_pose_flexe` |
| Ossos da visão montada | Parcial — só `face`, `torso`, `left-arm`. Faltam `hip`, `arm_right`, `leg_left`, `leg_right` |
| As 11 peças de `parts/` | **Nenhuma existe.** E nenhum `.tres` preenche `art_id` |
| Cenários | **Nenhum.** `botbattle_assets/scenarios/` está vazio |
| Estados de dano | Nenhum, em nenhuma parte |

---

## 3. Fase 0 — Ponto de partida

### 3.1 Desfazer os symlinks

A sessão anterior moveu os 8 `.aseprite` para o repo de assets e deixou symlinks no lugar.
**Nada disso foi commitado**, e a decisão de submódulo torna a abordagem obsoleta (symlink
relativo exige os dois repos lado a lado, no mesmo layout, em toda máquina — exatamente o
que quebra num time). Reverter:

```bash
cd botbattle
git restore --staged --worktree assets/sprites/
```

Os `.aseprite` voltam a ser arquivos de verdade no repo do jogo. Eles vão para o submódulo
na fase 1, agora pelo caminho certo. No repo de assets, `sprites/` já tem cópia idêntica
(mesmo md5) — pode ficar; é ela que o submódulo vai servir.

### 3.2 Limpar o que é comprovadamente morto

Os 18 `.jpg` em `assets/sprites/` (e seus `.jpg.import`) são inalcançáveis por três
motivos independentes:

- `art_library.gd:64` monta o caminho como `"%s.aseprite"` — **nunca** tenta `.jpg`;
- nenhuma cena, script ou `.tres` referencia um `.jpg`;
- e se carregasse, `_has_real_transparency()` rejeitaria JPEG, que não tem alpha.

As remoções de `Unity/`, `Unreal Engine/` e `Godot/` já estão staged da sessão anterior —
mantenha.

---

## 4. Fase 1 — Submódulo

O repositório de arte entra **dentro** da árvore do projeto Godot, porque só o que está
sob `res://` é importável.

```bash
cd botbattle
git rm -r --cached assets/sprites          # os .aseprite passam a vir do submódulo
rm -rf assets/sprites
git submodule add git@github.com:viniciusfortino/botbattle_assets.git assets/source
git commit -m "assets: repositório de arte como submódulo em assets/source"
```

Resultado:

```
botbattle/assets/source/        ← submódulo
  characters/mk1/{full,face,torso,left-arm}/
  scenarios/
  sprites/chassis/mk1/*.aseprite
```

Os caminhos viram `res://assets/source/...`. Atualizar as constantes do `ArtLibrary`:

```gdscript
const CHASSIS_PATH := "res://assets/source/sprites/chassis"
const PARTS_PATH := "res://assets/source/sprites/parts"
```

> O nome `assets/source` aparece em constante de código — se for trocar, troque agora.

### 4.1 Os `.import` caem dentro do submódulo

Ao importar `res://assets/source/.../south.png`, o Godot grava o sidecar `.png.import`
ao lado do arquivo — ou seja, **dentro da árvore do submódulo**. Sem tratamento,
`git status` no repo do jogo passa a acusar o submódulo como sujo, para sempre.

Criar `botbattle_assets/.gitignore`:

```gitignore
# Metadados gerados pelo Godot do projeto que consome estes assets
*.import
.godot/
.DS_Store
```

### 4.2 Não versionar o que não vai para o jogo

O submódulo traz a árvore inteira para o disco de todo mundo — inclusive as 6 direções que
o jogo não usa e os `.aseprite`. Isso é aceitável no *checkout*; o que não pode é ir para
o build. Excluir no `export_presets.cfg` (filtro de exclusão do Godot):

```
*.aseprite, *.json, assets/source/characters/*/*/rotations/north*.png, …
```

Ou seja: o repo do jogo deixa de carregar arte no **histórico** (ganho do submódulo), e o
**build** deixa de carregar o que não usa (ganho do filtro de exportação). São problemas
diferentes, resolvidos em lugares diferentes.

---

## 5. Fase 2 — Pixel art no projeto

Em `project.godot`, seção `[rendering]`:

```ini
textures/canvas_textures/default_texture_filter=0   # Nearest
```

Sem isso o pixel art sai borrado. O renderizador continua `gl_compatibility`.

### 5.1 A escala tem de ser inteira

`PartNode._draw_art()` escala pela altura, e a origem é de 128 px. A escala final na tela é:

```
(art_height / 128) × visual_scale
```

Se não for inteira, o pixel treme e distorce enquanto o corpo balança
(`_apply_vertical_offset()` usa `sin()`). Combinações que fecham, para a composição nova
(inimigo ao centro e maior; herói no canto, em primeiro plano):

| Combatente | art_height | visual_scale | Escala |
| --- | --- | --- | --- |
| Inimigo (montada, centro) | 384 | 1.0 | 3× |
| Herói (fullbody, canto) | 384 | 1.6667 (5/3) | 5× |

A regra vale para qualquer par: `art_height` múltiplo de 128, e `visual_scale` escolhido de
modo que o produto caia em inteiro. Ajuste os números à composição final — **a regra é o
que importa, não estes valores**.

> Na janela de desktop (540×960) o `stretch/mode="canvas_items"` aplica mais um 0.5, e aí
> nenhuma escala é inteira. Julgue nitidez em 1080×1920, nunca no preview de desktop.

Conferir também os usos de `RobotSprite.HEIGHT` (const = 360.0) antes de mexer em altura.

---

## 6. Fase 3 — A refatoração das duas visões

Esta é a fase central. A `Anatomy`, o `Body` e as hitboxes **não mudam** — o combate
continua idêntico. Muda quem desenha, e como.

### 6.1 O resolvedor de arte

Criar `actors/character_art.gd` — **classe nova, não estender `ArtLibrary`**. O contrato do
`ArtLibrary` (recortar ao conteúdo, exigir transparência real, convenção `_front`) é do
pipeline Aseprite e não serve aqui; ver §11.1.

```
res://assets/source/characters/<char_id>/<part>/<Pose>/rotations/<direction>.png
```

```gdscript
class_name CharacterArt
extends RefCounted

## Devolve o quadro de 128×128 INTEIRO — sem recorte. Ver §11.1.
static func texture(char_id: String, part: String, pose: String, direction: String) -> Texture2D
## Poses disponíveis, lidas do metadata.json — não hardcode nome de pasta.
static func poses(char_id: String, part: String) -> PackedStringArray
static func clear_cache() -> void
```

O `metadata.json` de cada parte traz `states[].folder` e `frames.rotations` com os nomes
exatos (`Idle`, `fighting_pose_flexe`). Ler dele é o que permite acrescentar pose no
PixelLab sem tocar em código — o mesmo princípio que a `Anatomy` já aplica aos encaixes.

### 6.2 A ramificação no `RobotSprite`

Um campo novo em `combat/chassis.gd` decide a visão:

```gdscript
@export_group("Arte")
## Id em characters/<id>/full. Preenchido = visão fullbody; vazio = visão montada.
@export var full_art_id: String = ""
```

`chassis/mk1.tres` recebe `"mk1"`. Em `_build()`:

```gdscript
if _use_fullbody():
    _build_fullbody()   # um PartNode só
else:
    _build_montada()    # a árvore de ossos de hoje, com arte nova
```

A visão montada **é** o `_build()` atual — a árvore de `PartNode` já existe e já funciona.
O que muda nela é a fonte da arte (`CharacterArt` em vez de `ArtLibrary`) e a calibração
da §6.3. Nada da estrutura é jogado fora.

Quem decide a visão é o chassi, não a cena: o herói usa `mk1` (fullbody) e o inimigo usa
`sentinel_v9` (montada). O hangar mostra o robô do jogador em montada mesmo ele sendo
fullbody na batalha — então `RobotSprite` precisa de um override explícito:

```gdscript
## Força a visão montada mesmo com full_art_id preenchido. O hangar usa isso.
@export var force_montada: bool = false
```

### 6.3 Calibração das partes — o item mais caro

**As partes do PixelLab não vêm alinhadas.** Medindo o alpha bbox dentro do canvas de
128×128:

| parte | bbox (`south`) | o que significa |
| --- | --- | --- |
| `face` | (27,17)–(101,111) | ocupa quase todo o quadro |
| `torso` | (22,17)–(106,111) | **mesma região, mesmo tamanho** |
| `left-arm` | (50,5)–(78,126) | faixa vertical estreita |
| `full` | (35,15)–(92,111) | o robô inteiro |

Cada parte foi gerada como sprite isolado preenchendo o próprio quadro. Desenhar as três
na mesma origem produz uma cabeça e um tórax empilhados do mesmo tamanho — não um robô.

Cada osso precisa, portanto, do seu próprio `art_height` e `art_offset`. **Esses campos já
existem** em `BoneDef` e `SlotDef` (`humanoid.tres`), mas os valores atuais foram autorados
para as telas do Aseprite (128×256 nos braços, 192×256 no tórax, pivô no centro inferior —
`feature_parts.md` §8) e **não servem** para o canvas 128×128 do PixelLab.

Procedimento:

1. `RobotSprite` é `@tool` — abra `battle.tscn` no editor e calibre com o robô à vista;
2. ajuste `art_height` e `art_offset` osso por osso em `anatomy/humanoid.tres`;
3. valide com `tools/sprite_bench.gd`, que já renderiza a montagem e salva
   `.captures/bench.png`;
4. critério: as partes se encostam sem sobrepor nem deixar vão, e o pé fica na origem.

Se a pendência §2.1.1 (partes alinhadas a um mannequin comum) se confirmar, **regere as
partes alinhadas e pule os passos 1–3**.

### 6.4 Estados de dano

O cascateamento de estado já existe em `ArtLibrary._staged()`: estado específico → estado
base → null. Reproduza no `CharacterArt` com sufixo na pose (`Idle_damaged`), para que a
arte de dano seja *drop-in* quando existir. Enquanto não existir, toda condição resolve
para a arte intacta e o feedback continua vindo do `flash()` e dos números de dano.

Na visão fullbody não há dano por parte: o herói é uma imagem só.

### 6.5 Poses e o tempo do turno

`play_body(anim)` devolve hoje a duração da animação, e o `battle_manager` espera esse
tempo antes de virar o turno. Na fullbody não há `AnimationPlayer`: a função troca a pose
para `fighting_pose_flexe`, devolve uma duração fixa (~0.45 s) e volta para `Idle` ao fim.

**Leia como `combat/battle_manager.gd` consome esse retorno antes de fixar o número** —
devolver `0.0` faz o turno virar na hora e a pose não chega a aparecer.

### 6.6 O espelhamento tem de sair

`_apply_view()` faz `_skeleton.scale.x = -1.0` quando `back_view` é true — truque para
simular costas sem ter arte de costas. Com arte real de 8 direções isso **tem de ser
desligado nas duas visões**: espelhar arte real troca as assimetrias de lado (o braço
esquerdo vira direito), e na montada isso significa mostrar a peça do adversário no lado
errado — justamente o que a visão existe para comunicar.

A direção passa a ser explícita:

```gdscript
## "east"/"west" na fullbody, "south" na montada.
@export var direction: String = "south"
```

---

## 7. Fase 4 — Fim da escolha de cor

A dinâmica de escolher cor acaba, mas **o dado de cor não pode sumir**: `battle.gd:298`
usa `actor.stats.accent_color` como cor do feixe do laser, e `battle.gd:289` colore o
número de "Guarda". Apagar o campo quebra os dois.

| Onde | O que fazer |
| --- | --- |
| `hangar.gd` | Remover `BODY_COLORS`, `ACCENT_COLORS`, as duas chamadas de `_color_row()` e a própria `_color_row()` |
| `hangar.gd:73-74`, `combatant.gd:50-51`, `sprite_bench.gd:30-31` | Parar de repassar cor ao `RobotSprite` |
| `robot_sprite.gd` | Remover os `@export` de `body_color`/`accent_color`; as silhuetas passam a usar uma paleta fixa (§11.4) |
| `loadout.gd:15-16` | Remover os `@export` — cor deixa de ser escolha do jogador |
| `unit_stats.gd:21-22` | **Manter.** Vira dado autorado por unidade, para os VFX |
| `loadout.gd:226-227` | Passar a ler a cor do chassi/unidade, não do loadout |
| `player_loadout.gd:77-88` | Parar de persistir e de ler as cores do save |

O save antigo tem as chaves `body_color`/`accent_color`. Ler um save assim não pode
quebrar: ignore chave desconhecida em vez de falhar. O repo já tem
`tools/migrate_loadouts.gd` como precedente, se preferir migração explícita.

---

## 8. Fase 5 — Composição da arena

Composição escolhida: **inimigo ao centro e maior** (é o que o jogador precisa ler para
identificar as peças); **herói de perfil no canto inferior**, recortado pelo quadro, servindo
de moldura em primeiro plano.

```
 1080×1920
┌──────────────────┐
│  céu / fundo     │
│        ██        │  INIMIGO ao centro,
│      ██████      │  visão MONTADA (south),
│       ████       │  maior
│     ▁▁▁▁▁▁▁▁     │
│                  │
│ ██               │  HERÓI de perfil,
│████              │  FULLBODY (east/west),
│ ██               │  recortado pelo quadro
│ [ atacar ] [ … ] │
└──────────────────┘
```

Em `battle.tscn`: reposicionar `Actors/Enemy` e `Actors/Hero`, ajustar `visual_scale` de
ambos conforme §5.1 e conferir o `z_index` do herói (hoje 5) para ele ficar à frente do
cenário. O herói recortado pela borda é intencional — não force o corpo inteiro dentro do
quadro.

`ui/target_picker.gd` posiciona os alvos sobre as partes do inimigo: **revalide-o depois de
mudar posição e escala**, senão os toques caem fora das hitboxes.

---

## 9. Fase 6 — Cenário em camadas

Gerar **360×640 por camada** e escalar 3× para 1080×1920 — gerar direto em 1080×1920 dá
uma imagem grande que não é pixel art.

```
botbattle_assets/scenarios/<arena_id>/
  sky.png        360×640   céu / fundo distante
  backdrop.png   360×640   silhuetas, estruturas, horizonte
  floor.png      360×640   piso da arena
```

`arena_background.gd` vira um compositor de camadas, **mantendo o `_draw()` atual como
fallback** quando não há arte — o mesmo padrão que o resto do projeto já usa, e o que
permite integrar uma arena por vez sem quebrar a batalha. As plataformas continuam
posicionadas por código, casando com os pés dos combatentes.

---

## 10. Fase 7 — Verificação

O arnês já existe; use-o em vez de só abrir o jogo.

```bash
# batalha inteira headless, PNG de cada rodada em .captures/
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/smoke_test.gd

# a montagem do robô, isolada
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/sprite_bench.gd

# a cena sobe sem erro?
/Applications/Godot.app/Contents/MacOS/Godot --path . --quit-after 240

# as regras não mudaram? (200 batalhas por estratégia)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/simulate.gd
```

Critérios de pronto:

1. `smoke_test` sai com código 0; as capturas mostram o herói em fullbody de perfil no
   canto e o inimigo em montada frontal ao centro;
2. `simulate.gd` reporta números equivalentes aos de antes — renderização não pode mexer
   no combate;
3. no hangar, trocar uma peça muda visivelmente o robô montado;
4. o pixel art está nítido, sem borrão e sem tremulação;
5. o robô não muda de tamanho nem escorrega ao trocar de pose;
6. o alvo tocado no `target_picker` corresponde à parte atingida.

---

## 11. Armadilhas

### 11.1 Não recortar a textura — inviabiliza a montada

`ArtLibrary._load()` recorta ao conteúdo com `get_used_rect()`. Isso serve a uma peça de
vista única, mas destrói tudo aqui: cada parte tem bbox diferente (§6.3) e cada direção
tem bbox diferente da mesma parte (`face south` 27–101 vs `east` 23–104). Com recorte, o
robô muda de tamanho e escorrega a cada giro e a cada troca de pose, e a calibração de
`art_offset` deixa de ter significado estável. O `CharacterArt` devolve o quadro inteiro.

### 11.2 O espelhamento do `back_view`

Ver §6.6. É silencioso: a arte aparece, só que espelhada — e na montada isso mostra a peça
do adversário no lado errado.

### 11.3 Os `.import` dentro do submódulo

Ver §4.1. Sem o `.gitignore`, o submódulo fica permanentemente sujo no `git status` do
repo do jogo.

### 11.4 A silhueta procedural depende das cores removidas

Os ~180 linhas de `_draw_torso`, `_draw_head`, `_draw_arm`… leem `body_color` e
`accent_color`. **Não apague o desenho procedural junto com a escolha de cor**: hoje
nenhuma das 11 peças tem arte, então sem o fallback a visão montada fica vazia. Troque as
duas variáveis por constantes de paleta fixa no próprio arquivo e mantenha o desenho até a
arte existir peça a peça.

### 11.5 Escala fracionária

Ver §5.1. Só aparece em movimento, e é fácil confundir com problema na geração da arte.

---

## 12. Fora de escopo

- Animação quadro a quadro. As poses do PixelLab são estáticas; `frames.animations` vem
  vazio no `metadata.json` de hoje.
- As 6 direções além de `east`/`west` (fullbody) e `south` (montada).
- Recoloração por paleta indexada (`feature_parts.md` §10) — a arte do PixelLab já vem
  colorida, e a escolha de cor acabou.
- Aposentar o pipeline Aseprite e o `ArtLibrary`. Ele continua servindo o chassi antigo
  enquanto a migração acontece; decidir o destino dele quando as 11 peças tiverem arte.

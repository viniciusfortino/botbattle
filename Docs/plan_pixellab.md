# Plano: integração PixelLab — duas visões do robô e cenário em pixel art

Especificação de execução. Foi levantada lendo o código atual (`robot_sprite.gd`,
`part_node.gd`, `art_library.gd`, `arena_background.gd`, `hangar.gd`, `battle.gd`,
`humanoid.tres`, `battle.tscn`) e medindo os assets do repositório de arte.

**Estado em 2026-09-03: a arte está toda gerada e a calibração da Fase 3 está resolvida.
Falta o código — as fases 0 a 7 continuam por fazer.** O roteiro executável é a §0.

---

## 0. Como executar este plano

Leia esta seção inteira antes da primeira linha de código. Ela existe para que a execução
não dependa de reconstruir o raciocínio das outras seções.

### 0.1 Regras da execução

1. **Faça uma fase por vez, na ordem da §0.2**, e só passe adiante quando o "pronto quando"
   daquela fase passar. As fases têm dependência real entre si.
2. **Não invente valor numérico.** Onde este plano dá um número (calibração da §13.1,
   tamanho de canvas, escala do cenário), use o número. Onde ele não dá, meça — não
   estime.
3. **Rode o jogo de verdade a cada fase.** O arnês da §10 é headless e barato; erro de
   montagem não aparece em teste unitário, aparece na captura.
4. **Não mexa em `Anatomy`, `Body`, `BodyPart`, nem em nada de combate.** Este plano é de
   renderização. Se um passo parecer exigir mudar regra de combate, o passo está errado —
   pare e pergunte.
5. **Mantenha o desenho procedural vivo** até a arte cobrir tudo (§11.4). Ele é o fallback
   que permite migrar peça a peça sem tela vazia.

### 0.2 Ordem, dependências e "pronto quando"

| # | Fase | Depende de | Pronto quando |
| --- | --- | --- | --- |
| 0 | **Commitar e dar push na arte** em `botbattle_assets` | — | `git status` limpo lá; o remoto tem `characters/`, `parts/`, `scenarios/` |
| 1 | **§3 Fase 0** — limpar `.jpg` mortos e symlinks | — | `git status` limpo do que a §3 manda tirar; jogo abre |
| 2 | **§4 Fase 1** — submódulo em `assets/source` | 0, 1 | `res://assets/source/characters/mk1/torso/Idle/rotations/south.png` carrega no editor |
| 3 | **§5 Fase 2** — filtro *nearest* | 2 | `project.godot` tem `default_texture_filter=0`; sprite não sai borrado |
| 4 | **§6.1 `CharacterArt`** | 2 | o teste da §6.1.3 passa |
| 5 | **§6.3 aplicar a calibração** | 4 | `sprite_bench` mostra o robô montado inteiro, pé no chão |
| 6 | **§6.2 + §6.6** — duas visões e fim do espelho | 5 | herói fullbody de perfil, inimigo montado frontal |
| 7 | **§6.4 + §6.5** — dano e pose no turno | 6 | turno não vira instantâneo; peça danificada troca de arte |
| 8 | **§7 Fase 4** — fim da escolha de cor | 6 | hangar sem seletor; laser e "Guarda" ainda coloridos |
| 9 | **§9 Fase 6** — cenário em camadas | 3 | arena com as 3 camadas, fallback procedural intacto |
| 10 | **§8 Fase 5** — composição da arena | 6, 9 | a composição da §8 na captura do `smoke_test` |
| 11 | **§10 Fase 7** — verificação | tudo | os 5 critérios da §10 |

**O passo 0 não é burocracia.** Toda a arte gerada está *untracked* em `botbattle_assets`
(§13.7). Um `git submodule add` apontando para um remoto que ainda não tem essa arte deixa
o jogo sem textura nenhuma — e o sintoma (tudo caindo na silhueta procedural) parece bug de
código, não commit faltando. Commite e dê push **antes** da Fase 1.

A Fase 5 (§8) vem **depois** do cenário (§9) de propósito: posicionar combatente contra um
fundo que ainda vai mudar é retrabalho garantido.

### 0.3 Onde parar e perguntar

Três pontos deste plano são decisão humana, não técnica. **Não escolha sozinho:**

- **A resolução do herói (§13.4).** Quatro saídas, todas com custo. Traga estas maquetes e
  pergunte: `heroi_full_vs_hires.png` (as duas artes lado a lado),
  `heroi_escala_3x_4x.png` (na arena), `heroi_opcoes_perfil.png` (os perfis comparados),
  `montada_8_direcoes.png` (por que a opção 4 não funciona hoje). Se a escolha for
  `full_hires`, ela **arrasta duas tarefas** — pose de ataque e proporção (§13.4).
- **Trocar `RobotSprite.HEIGHT` de 360 para 347** (§13.1). É cosmético e seguro, mas muda
  onde os números de dano flutuam. Confirme antes.
- **Apagar as pastas antigas de arte** (`characters/mk1/face/`, `left-arm/`, `left-leg/`,
  `right-leg/`). `left-leg/` e `right-leg/` são a **única cópia** de personagens já
  apagados do PixelLab (§2.2). Não apague sem confirmação explícita.

### 0.4 O que já está feito — não refaça

- Toda a arte: 7 ossos, 11 peças, cenário. Inventário na §2.2.
- A calibração de `art_height`/`art_offset` (§13.1), conferida contra redesenho.
- As duas perguntas de capacidade do MCP (§2.1). **Não precisa gerar arte nova**, e não
  precisa reabrir o PixelLab, a menos que a §0.3 decida o contrário.

### 0.5 Verificação de que o ambiente está de pé

Antes de começar, confirme que o arnês roda — se ele já estiver quebrado, você não vai
saber distinguir a sua quebra da que já existia:

```bash
cd botbattle
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/simulate.gd
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/sprite_bench.gd
```

Guarde a saída do `simulate.gd`: ela é a **linha de base** do critério 2 da §10 (as regras
não podem mudar). Se algum dos dois já falha hoje, diga isso antes de mexer em qualquer
coisa.

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

## 2. Pendências — RESOLVIDAS

> Sessão de 2026-09-03, já com o MCP do PixelLab no ar. As duas perguntas da §2.1 foram
> respondidas contra as ferramentas reais, e a arte que faltava foi gerada. O que mudou de
> premissa está marcado **CORREÇÃO** — vale mais do que a arte nova, porque três dessas
> premissas apareciam em outras seções do plano.

### 2.1 MCP do PixelLab — respondido

**Pergunta 1 — dá para exportar partes alinhadas a um mannequin comum? NÃO.**

Não existe ferramenta que exporte esqueleto, joints ou keypoints, e `get_character` não
devolve âncora, pivô ou offset por direção. O `template_id: "mannequin"` é interno à
geração e não vira dado. **A calibração da §6.3 não desaparece** — mas também não precisa
ser feita à mão: ela é *medível*, e esta sessão a resolveu por medição (ver §13).

Uma mitigação real existe e é a base da §6.4: `create_character_state` gera uma variante
**no mesmo espaço de canvas da origem**. Ou seja, estados da *mesma* peça ficam alinhados
entre si — o que basta para dano ser drop-in. O que não se alinha é peça diferente com
peça diferente.

**Pergunta 2 — dá para gerar variantes de estado mantendo a identidade? SIM.**

`create_character_state` preserva identidade e proporção e aplica a edição nas 8 rotações.
Custa 20–40 gerações por estado. E melhor: **já estava feito** — a conta tinha
`little damaged` e `critical damaged` de cabeça e tórax desde antes desta sessão.

**CORREÇÃO — a ferramenta certa para peça isolada é `create_8_direction_object`, não
`create_character`.** `create_character` é preso a um mannequin humanoide: pedir "só a
pelve" devolveu um robô inteiro com uma caixa na cabeça. Todas as peças e o quadril desta
sessão saíram de `create_8_direction_object` (40 gerações, ~3 min cada).

**CORREÇÃO — o canvas não é sempre 128×128.** Personagem sai 128×128; objeto sai
**136×136**. A §11.1 e o `CharacterArt` precisam falar em "o quadro inteiro, seja qual for
o tamanho", e `art_height` tem de sair da altura do canvas daquele arquivo — não de um 128
fixo. A fórmula da §13 já é assim.

### 2.2 Arte — inventário corrigido

**CORREÇÃO — a tabela antiga subestimava o que existia.** Pernas e estados de dano já
estavam gerados; o `find` da sessão anterior tinha sido truncado.

| O que | Situação agora |
| --- | --- |
| Herói fullbody | Pronto — `full/{Idle,fighting_pose_flexe}`. Mas ver a ressalva de resolução em §13.4 |
| Ossos da montada | **Completo** — `head`, `torso`, `arm_left`, `arm_right`, `leg_left`, `leg_right`, `hip` |
| As 11 peças de `parts/` | **Todas geradas** em `botbattle_assets/parts/<id>/`. Os `.tres` continuam sem `art_id` (é trabalho da Fase 3) |
| Cenários | **Gerado** — `scenarios/neon_grid/{sky,backdrop,floor}.png` |
| Estados de dano | `head`: `Idle_damaged`, `Idle_critical`, `Idle_offline`. `torso`: `Idle_damaged`, `Idle_critical`. Demais ossos: só `Idle` |

Os ossos passaram a ser nomeados **pela chave da anatomia** (`head`, não `face`;
`arm_left`, não `left-arm`), para o `CharacterArt` resolver sem tabela de tradução. As
pastas antigas (`face/`, `left-arm/`, `left-leg/`, `right-leg/`) continuam no disco e não
devem ser apagadas sem olhar: **`left-leg/` e `right-leg/` vêm de personagens que já foram
apagados da conta do PixelLab, então aqueles arquivos são a única cópia que existe.**

Dois membros são **espelhados no plano sagital**, não gerados: `arm_right` sai de
`arm_left` e `leg_left` sai de `leg_right`, com `dir(east)↔dir(west)` e flip horizontal. Em
corpo bilateralmente simétrico isso é geometricamente correto, sai de graça e garante o par
casado — coisa que gerar de novo não garantiu (as duas pernas geradas em separado não
combinavam entre si). Note que isso **não** contradiz a §6.6: lá o problema é espelhar em
tempo de execução; aqui o espelho é assado no arquivo.

As pernas levaram um **giro de matiz de −40°** para sair do violeta e entrar no azul-aço do
tronco; sem isso a metade de baixo do robô era visivelmente de outro material.

---

## 3. Fase 0 — Ponto de partida

### 3.1 Os symlinks — já commitados, some com eles na Fase 1

Uma sessão anterior moveu os 8 `.aseprite` para o repo de assets e deixou symlinks no
lugar. **Atenção: isso foi commitado** (`6b1cf63 refactor WIP`) — o que HEAD guarda hoje é
o symlink, modo `120000`:

```bash
git ls-files -s assets/sprites/chassis/mk1/head_front.aseprite
# 120000 ... = symlink   |   100644 ... = arquivo de verdade
```

Versões antigas deste plano mandavam `git restore --staged --worktree assets/sprites/`
dizendo que "nada foi commitado". **Não rode isso**: agora ele restauraria o symlink, que é
exatamente o que se quer eliminar.

Não há o que desfazer. A Fase 1 (§4) apaga `assets/sprites/` inteiro e põe o submódulo no
lugar — os symlinks vão junto. O conteúdo real já está a salvo em
`botbattle_assets/sprites/`, que é o que o submódulo vai servir. **Pule para a §3.2.**

Por que symlink não serve, para o caso de a ideia voltar: symlink relativo exige os dois
repos lado a lado, no mesmo layout, em toda máquina — precisamente o que quebra num time
de mais de uma pessoa.

### 3.2 Limpar o que é comprovadamente morto

Os 18 `.jpg` em `assets/sprites/` (e seus `.jpg.import`) são inalcançáveis por três
motivos independentes:

- `art_library.gd:64` monta o caminho como `"%s.aseprite"` — **nunca** tenta `.jpg`;
- nenhuma cena, script ou `.tres` referencia um `.jpg`;
- e se carregasse, `_has_real_transparency()` rejeitaria JPEG, que não tem alpha.

Os 18 `.jpg` e os 18 `.jpg.import` **estão rastreados no git** — então é `git rm`, não
`rm`. E some tudo junto na Fase 1 de qualquer forma, quando `assets/sprites/` for apagado;
fazer aqui só serve para o diff ficar legível.

As remoções de `Unity/`, `Unreal Engine/` e `Godot/` **já foram commitadas** em
`6b1cf63` — nada a fazer, e não tente re-stageá-las.

Confirme o estado antes de agir, porque o repo mudou desde que este plano foi escrito:

```bash
git log --oneline -1        # esperado: 6b1cf63 refactor WIP (ou mais recente)
git status --short          # esperado: limpo, fora este documento
```

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
*.aseprite, assets/source/characters/*/*/rotations/north*.png, …
```

**Não exclua `*.json`.** Uma versão anterior deste plano mandava excluir, e isso quebraria
o `CharacterArt.poses()`, que lê `metadata.json` em tempo de execução (§6.1.2) — e
quebraria *só no build*, funcionando no editor, que é o pior tipo de bug. Se o peso
incomodar: os `metadata.json` somam poucos KB, e o que pesa são os PNGs.

Também não exclua as direções que a §12 diz estarem fora de escopo **sem conferir antes o
que o código pede**: hoje é `south` na montada e `east`/`west` na fullbody, mas o
`direction` é um `@export` (§6.6) e alguém pode tê-lo mudado na cena.

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

`PartNode._draw_art()` escala pela altura do canvas daquele arquivo. A escala final na tela
é:

```
(art_height / altura_do_canvas) × visual_scale
```

**A altura do canvas não é uma constante 128** — personagem sai 128, objeto sai 136 (§2.1).
Por isso a fórmula não pode ter 128 cravado, e a §13.1 dá `art_height` diferente para o
quadril.

Se a escala não for inteira, o pixel treme e distorce enquanto o corpo balança
(`_apply_vertical_offset()` usa `sin()`).

**A calibração da §13.1 já resolve isto pelo caminho mais curto:** `art_height` = a própria
altura do canvas (`U = 1.0`), o que faz o primeiro fator valer exatamente `1`. Aí *qualquer*
`visual_scale` inteiro dá escala inteira, sem precisar casar dois números.

Ou seja: **use `visual_scale` inteiro e a regra está satisfeita.** A §8.1 sugere 2× para o
inimigo e 4× para o herói.

> Cuidado: a regra mantém cada sprite nítido, mas não faz herói e inimigo terem pixels do
> *mesmo tamanho* — dois sprites nítidos em escalas diferentes continuam parecendo de jogos
> diferentes. É a ressalva aberta da §13.4.

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

Dois layouts, uma classe. Osso de personagem e peça de equipamento moram em raízes
diferentes porque peça não pertence a um chassi:

```
res://assets/source/characters/<char_id>/<osso>/<Pose>/rotations/<direção>.png
res://assets/source/parts/<part_id>/<Pose>/rotations/<direção>.png
```

#### 6.1.1 A implementação

Escreva exatamente isto. Os pontos que **não** podem ser "melhorados": nada de
`get_used_rect()` (§11.1), e `art_height` nunca sai de um 128 constante (§2.1).

```gdscript
## Resolve a arte gerada no PixelLab: osso de personagem e peça de equipamento.
##
## Ao contrário do ArtLibrary (pipeline Aseprite), aqui a textura é devolvida INTEIRA,
## sem recorte: cada peça tem bbox diferente e cada direção tem bbox diferente da mesma
## peça, então recortar faz o robô mudar de tamanho a cada giro. Ver §11.1 do plano.
class_name CharacterArt
extends RefCounted

const CHARACTERS := "res://assets/source/characters"
const PARTS := "res://assets/source/parts"

static var _tex_cache: Dictionary = {}
static var _meta_cache: Dictionary = {}


## A arte de um osso do chassi, no estado de dano dado.
static func bone_texture(char_id: String, bone: String, direction: String,
		cond: BodyPart.Condition = BodyPart.Condition.INTACT,
		pose: String = "Idle") -> Texture2D:
	return _staged("%s/%s/%s" % [CHARACTERS, char_id, bone], pose, direction, cond)


## A arte de uma peça montada. Peça não tem chassi: a raiz é outra.
static func part_texture(part_id: String, direction: String,
		cond: BodyPart.Condition = BodyPart.Condition.INTACT,
		pose: String = "Idle") -> Texture2D:
	return _staged("%s/%s" % [PARTS, part_id], pose, direction, cond)


## As poses disponíveis, lidas do metadata.json — nunca hardcode nome de pasta.
static func poses(base_path: String) -> PackedStringArray:
	var out := PackedStringArray()
	for state in _metadata(base_path).get("states", []):
		var folder := String(state.get("folder", ""))
		if not folder.is_empty():
			out.append(folder)
	return out


static func clear_cache() -> void:
	_tex_cache.clear()
	_meta_cache.clear()


## Cascata de estado, igual à do ArtLibrary._staged(): pose específica -> pose base ->
## null (e aí o PartNode cai no desenho procedural). O sufixo é na POSE, não no arquivo:
## "Idle_critical/rotations/south.png". Enquanto a arte de dano não existir para um osso,
## toda condição resolve para a íntegra — que é o comportamento desejado.
static func _staged(base_path: String, pose: String, direction: String,
		cond: BodyPart.Condition) -> Texture2D:
	var suffix := ""
	match cond:
		BodyPart.Condition.CRITICAL, BodyPart.Condition.DESTROYED:
			suffix = "_critical"
		BodyPart.Condition.DAMAGED:
			suffix = "_damaged"

	if not suffix.is_empty():
		var staged := _load(base_path, pose + suffix, direction)
		if staged != null:
			return staged
	return _load(base_path, pose, direction)


static func _load(base_path: String, pose: String, direction: String) -> Texture2D:
	var path := "%s/%s/rotations/%s.png" % [base_path, pose, direction]
	if _tex_cache.has(path):
		var cached = _tex_cache[path]
		return cached if cached is Texture2D else null
	if not ResourceLoader.exists(path):
		_tex_cache[path] = false
		return null
	var tex: Texture2D = load(path)
	_tex_cache[path] = tex
	return tex


static func _metadata(base_path: String) -> Dictionary:
	if _meta_cache.has(base_path):
		return _meta_cache[base_path]
	var out := {}
	var path := "%s/metadata.json" % base_path
	if ResourceLoader.exists(path) or FileAccess.file_exists(path):
		var file := FileAccess.open(path, FileAccess.READ)
		if file != null:
			var parsed = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				out = parsed
	_meta_cache[base_path] = out
	return out
```

#### 6.1.2 A pegadinha do `.json` no export

`ResourceLoader.exists()` devolve `false` para `.json` que o Godot não importa, por isso o
`or FileAccess.file_exists(path)`. E **o `metadata.json` precisa sobreviver ao export** —
se a §4.2 excluir `*.json` do build, `poses()` volta vazio no jogo empacotado e não no
editor, que é o pior tipo de bug. Ou tire `*.json` do filtro de exclusão, ou aceite que
`poses()` só serve para ferramenta de editor.

#### 6.1.3 Pronto quando

Rode isto num script de ferramenta (`--headless -s`) e confira a saída:

```gdscript
var t := CharacterArt.bone_texture("mk1", "torso", "south")
assert(t != null, "torso/Idle/rotations/south.png não carregou")
assert(t.get_size() == Vector2(128, 128), "a textura foi recortada — ver §11.1")

var h := CharacterArt.bone_texture("mk1", "hip", "south")
assert(h.get_size() == Vector2(136, 136), "o canvas do quadril é 136, não 128")

# cascata: o braço não tem arte de dano, então tem de cair na íntegra
var a := CharacterArt.bone_texture("mk1", "arm_left", "south", BodyPart.Condition.CRITICAL)
assert(a != null and a == CharacterArt.bone_texture("mk1", "arm_left", "south"))

# a cabeça TEM arte de dano, então não pode cair na íntegra
var d := CharacterArt.bone_texture("mk1", "head", "south", BodyPart.Condition.DAMAGED)
assert(d != CharacterArt.bone_texture("mk1", "head", "south"))

assert(CharacterArt.part_texture("laser_cannon", "south") != null)
assert("Idle_critical" in CharacterArt.poses("res://assets/source/characters/mk1/head"))
```

As duas primeiras asserções são as que importam: **tamanho 128 e 136 provam que nada foi
recortado e que o canvas não é uniforme.** Se qualquer uma falhar, pare — a §6.3 inteira
depende disso.

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

#### 6.2.1 A troca da fonte da arte — exatamente onde

São duas funções em `actors/robot_sprite.gd`, e só elas. Ambas devolvem um `Callable` que
o `PartNode` chama com a condição; **mantenha esse contrato** — o `PartNode` não muda.

**`_bone_art_resolver(bone)`** (hoje em `robot_sprite.gd:334`) tem três caminhos. Troque
assim:

| caminho de hoje | vira |
| --- | --- |
| peça substitui o osso → `ArtLibrary.part_texture(art_id, cond)` | `CharacterArt.part_texture(art_id, direction, cond)` |
| `if back_view: return Callable()` | **apaga** — `back_view` sai de cena (§6.6) |
| osso do chassi → `ArtLibrary.bone_texture(chassis_id, bone_key, cond)` | `CharacterArt.bone_texture(char_id, bone_key, direction, cond)` |

**`_mount_art_resolver(piece)`** (hoje em `robot_sprite.gd:372`) tem um caminho só:
`ArtLibrary.part_texture(art_id, cond)` → `CharacterArt.part_texture(art_id, direction, cond)`.

Duas coisas a respeitar aqui:

- **Capture `direction` por valor no lambda**, como o código já faz com `chassis_id` e
  `bone_key`. Ler `self.direction` de dentro do `Callable` faz a arte parar de acompanhar
  a troca de direção, porque o `PartNode` só rechama o resolvedor quando a condição muda.
- **O `Engine.is_editor_hint()` no topo continua** devolvendo `Callable()` vazio: no editor
  não há loadout nem corpo, e a pré-visualização é a silhueta. Não tente "consertar" isso.

`_chassis_id` vira o `char_id` do `CharacterArt` — hoje é o mesmo `"mk1"`, mas são conceitos
diferentes (chassi é regra, `char_id` é pasta de arte). Se divergirem, quem manda na arte é
o chassi via `full_art_id`/`id`.

#### 6.2.2 O `art_id` das 11 peças

Nenhum `.tres` de `parts/` tem `art_id` preenchido, e sem isso `_mount_art_resolver`
devolve `Callable()` vazio e a peça nunca aparece. Os arquivos e os ids batem 1 para 1 —
preencha `art_id` com o próprio nome do arquivo:

`agile_leg`, `blade_forearm`, `dorsal_armor`, `generator`, `heavy_arm`, `heavy_leg`,
`laser_cannon`, `plasma_cannon`, `power_cell`, `sensor`, `short_sword`.

Ou seja, em `parts/laser_cannon.tres`: `art_id = "laser_cannon"`.

**Os `art_height`/`art_offset` dos encaixes (`SlotDef`) NÃO foram calibrados** — a §13.1 só
cobre os sete ossos. Os encaixes ainda têm valores da era Aseprite, então espere as peças
aparecerem no lugar errado ou no tamanho errado na primeira vez. Calibre-os com o mesmo
método da §6.3.2, uma peça por vez, e anote os valores no plano.

Quem decide a visão é o chassi, não a cena: o herói usa `mk1` (fullbody) e o inimigo usa
`sentinel_v9` (montada). O hangar mostra o robô do jogador em montada mesmo ele sendo
fullbody na batalha — então `RobotSprite` precisa de um override explícito:

```gdscript
## Força a visão montada mesmo com full_art_id preenchido. O hangar usa isso.
@export var force_montada: bool = false
```

### 6.3 Calibração das partes — aplicar os números da §13.1

**As partes do PixelLab não vêm alinhadas.** Cada uma foi gerada como sprite isolado
preenchendo o próprio quadro, então cabeça e tórax têm quase o mesmo bbox: desenhá-las na
mesma origem empilha duas peças do mesmo tamanho, não faz um robô. Os valores de hoje em
`humanoid.tres` foram autorados para as telas do Aseprite (128×256 nos braços, 192×256 no
tórax — `feature_parts.md` §8) e não servem.

**Isto já foi resolvido por medição (§13.1). Aqui é só transcrever.**

#### 6.3.1 Os valores

Substitua em `anatomy/humanoid.tres`, nos sete `sub_resource` de `BoneDef`:

| `key` | `art_height` | `art_offset` |
| --- | --- | --- |
| `head` | `128.0` | `Vector2(0, 54)` |
| `torso` | `128.0` | `Vector2(0, 59)` |
| `arm_left` | `128.0` | `Vector2(-65, 159)` |
| `arm_right` | `128.0` | `Vector2(65, 159)` |
| `leg_left` | `128.0` | `Vector2(-18, 63)` |
| `leg_right` | `128.0` | `Vector2(19, 63)` |
| `hip` | `136.0` | `Vector2(0, -81)` |

**Não toque em `rest_position`, `z_index` nem `z_index_back`** — a calibração foi resolvida
*em cima* das posições atuais do esqueleto, e mexer nelas invalida a tabela inteira.

Três armadilhas na transcrição:

- **O `hip` é 136, não 128.** Ele veio de `create_8_direction_object`, cujo canvas é maior
  (§2.1). Um 128 ali encolhe o quadril e abre um vão até as pernas.
- **O Godot omite campo com valor padrão.** O `sub_resource` do `hip` hoje não tem linha
  `art_offset` nem `art_height` (os padrões são `Vector2.ZERO` e `100.0`, em
  `bone_def.gd:39-40`). Você precisa **acrescentar** as linhas, não editar.
- **`leg_left` é −18 e `leg_right` é +19** — a assimetria de 1 px é correta e proposital:
  a perna esquerda é o espelho da direita num canvas de largura par, então os dois bboxes
  ficam a ±1 do centro e o offset compensa. Não "conserte" para ±18.

#### 6.3.2 De onde vieram, se precisar refazer

Se uma peça for regerada, o bbox muda e **estes números mudam junto**. Não ajuste à mão:
rode de novo o pipeline de `botbattle_assets/tools/` (§13.5), que mede o bbox de alpha,
remonta o robô encostando âncora em âncora e resolve a fórmula do `PartNode`:

```
art_height   = altura_do_canvas * U                       (U = 1.0)
art_offset.x = cx_alvo   - ((x0+x1)/2 - largura_canvas/2) * U
art_offset.y = base_alvo + (altura_do_canvas - y1) * U
```

#### 6.3.3 Pronto quando

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/sprite_bench.gd
```

Abra `.captures/bench.png` e confira, nesta ordem:

1. é um robô — cabeça em cima do tórax, braços nos ombros, pernas sob o quadril;
2. as partes se encostam **sem vão e sem sobreposição grosseira** nas juntas;
3. o pé encosta na origem (y = 0 do esqueleto);
4. o robô mede **~120 × 347** unidades. Muito diferente disso = valor transcrito errado.

O robô montado tem 347 de altura, não 360. `RobotSprite.HEIGHT` (=360) só ancora VFX
(`battle.gd:272` e `301-302`) — trocar é cosmético, mas **é decisão do usuário** (§0.3).

### 6.4 Estados de dano

O cascateamento de estado já existe em `ArtLibrary._staged()`: estado específico → estado
base → null. Reproduza no `CharacterArt` com sufixo na pose (`Idle_damaged`), para que a
arte de dano seja *drop-in* quando existir. Enquanto não existir, toda condição resolve
para a arte intacta e o feedback continua vindo do `flash()` e dos números de dano.

Na visão fullbody não há dano por parte: o herói é uma imagem só.

### 6.5 Poses e o tempo do turno

A cadeia é esta (conferida, não suposta):

```
scenes/battle/battle.gd:230   var pose_seconds := actor.play_body_animation(...)
combat/combatant.gd:150-151   return sprite.play_body(body_animation_for(action_id))
actors/robot_sprite.gd:222    play_body() -> float
```

`play_body` devolve a duração da animação, e a batalha espera esse tempo antes de virar o
turno. **Repare no early-return de hoje:**

```gdscript
if _player == null or anim.is_empty() or not _player.has_animation(anim):
    return 0.0
```

Na fullbody **não há `AnimationPlayer`** — `_build_player()` só monta o tocador para a
árvore de ossos. Então, sem tratamento, a fullbody cai nesse `return 0.0`, o turno vira na
hora e a pose nunca aparece. É silencioso: nada quebra, a batalha só fica sem animação.

Na visão fullbody, `play_body` deve trocar a pose do único `PartNode` para
`fighting_pose_flexe`, devolver uma duração fixa (**0.45 s** é um bom começo) e voltar
para `Idle` ao fim — com `get_tree().create_timer()` ou um `Tween`, já que não há
`animation_finished` para escutar.

O nome da pose não pode ser hardcoded sem rede: use `CharacterArt.poses()` e caia em
`Idle` se `fighting_pose_flexe` não existir para aquele `char_id`.

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

#### 6.6.1 `back_view` tem 14 usos — trate um por um

Não basta apagar o `@export`. O levantamento completo:

| onde | o que fazer |
| --- | --- |
| `robot_sprite.gd:28-30` | apaga o `@export var back_view` |
| `robot_sprite.gd:235` | **apaga a linha** — é o espelho, a razão de tudo isto |
| `robot_sprite.gd:246,255,263,265` | passa a usar sempre `z_index` (nunca `z_index_back`) |
| `robot_sprite.gd:343` | apaga o `if back_view: return Callable()` (§6.2.1) |
| `robot_sprite.gd:446,469` | ramos de costas do desenho procedural — apaga os ramos |
| `combatant.gd:49` | `sprite.back_view = is_player` vira `sprite.direction = ...` |
| `sprite_bench.gd:29` | idem, no arnês |
| `battle.tscn:45` | tira `back_view = true` do nó |
| `bone_def.gd:43`, `slot_def.gd:25` | `z_index_back` fica órfão — **deixe por ora** |

Sobre a última linha: `z_index_back` deixa de ser lido, mas apagar o campo obriga a
reescrever todos os `sub_resource` de `humanoid.tres` que o mencionam. Fica como limpeza
posterior; campo não lido não faz mal, campo removido às pressas quebra o `.tres`.

**A linha 49 do `combatant.gd` é a que importa conceitualmente:** hoje ela diz "o jogador é
visto de costas". Depois desta fase, quem é visto de que ângulo é `direction`, e quem
decide a *visão* (fullbody ou montada) é o chassi (§6.2) — não o fato de ser o jogador.

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

### 8.1 Ponto de partida, medido

Estes números vieram da maquete em `botbattle_assets/_reference/composicao_arena.png` e
funcionam. Comece por eles em vez de tatear:

| | visão | escala | onde |
| --- | --- | --- | --- |
| Inimigo | montada (`south`), 120×347 de conteúdo | **2×** | centro, pés em y≈1050 |
| Herói | fullbody (`east`), 246×? de conteúdo (`full_hires`) | **4×** | canto inferior esquerdo, cortado pela borda de baixo |

### 8.2 O que decide a escala do herói — pare aqui

**Leia a §13.4 antes de fechar a composição.** Densidade de pixel igual e herói grande em
primeiro plano são objetivos **incompatíveis** com a arte de hoje, porque a fullbody é uma
imagem só e a montada é a soma de sete. Os quatro desfechos possíveis estão medidos na
§13.4, com maquete de cada um. **É decisão do usuário (§0.3), não sua.**

Se ninguém decidiu, **use `full` a 8×** — é o que existe hoje, é o único caminho que não
arrasta trabalho novo, e deixa a questão visível em vez de escondida. Registre que está
aberta e siga; nada mais na Fase 5 depende dessa escolha.

### 8.3 O que NÃO é problema aqui

O `ui/target_picker.gd` **não** lê geometria de sprite — é uma grade de `Button` com rótulo
e porcentagem (§13.2). Mudar posição, escala, `art_height` ou `art_offset` não desalinha
alvo nenhum. Versões antigas deste plano mandavam revalidá-lo; era premissa falsa.

---

## 9. Fase 6 — Cenário em camadas

**A arte já existe** — `botbattle_assets/scenarios/neon_grid/`. Falta o compositor.

```
scenarios/neon_grid/
  sky.png        216×384   opaca — gradiente noturno, estrelas, morros no rodapé
  backdrop.png   216×384   transparente — skyline, base assentada no horizonte
  floor.png      216×384   transparente — grid em perspectiva, começa em y=151
  metadata.json            layer_size, escala, horizon_y
```

**216×384 × 5 = 1080×1920**, escala inteira. (Não é 360×640 ×3 como dizia a versão
anterior deste plano: o gerador do PixelLab limita cada lado a 400 px — §13.3.)

### 9.1 O compositor

`scenes/battle/arena_background.gd` vira um compositor de camadas, **mantendo o `_draw()`
atual como fallback** quando não há arte. Esse fallback não é opcional: é o que permite
integrar uma arena por vez sem quebrar a batalha, e é o mesmo padrão do resto do projeto.

```gdscript
## Vazio = desenho procedural. Preenchido = camadas de scenarios/<id>/.
@export var arena_id: String = ""
```

Regras de desenho:

- as três camadas são desenhadas na ordem `sky` → `backdrop` → `floor`, cada uma esticada
  de 216×384 para `view_size` — com escala **inteira** (×5 em 1080×1920);
- se **qualquer** uma das três faltar, caia no `_draw()` procedural inteiro. Meia arena
  desenhada é pior que nenhuma;
- as plataformas e a linha do horizonte continuam por código. **O `horizon` do script é
  0.42; o grid do `floor.png` começa em `y=151/384 = 0.393`.** Não são o mesmo número —
  ou você move o `horizon` para `0.393`, ou os pés dos combatentes vão flutuar acima do
  piso desenhado. Escolha um e use o mesmo nos dois lugares.

### 9.2 Se for gerar outra arena

Duas armadilhas custaram tempo nesta sessão e vão custar de novo (§13.3):

- **`no_background: true` não é respeitado** — as três camadas voltaram 100% opacas e
  tiveram de ser recortadas por chroma-key contra a cor do canto superior esquerdo;
- **o gerador inventa conteúdo fora do pedido** — o skyline veio com um reflexo espelhado
  na metade de baixo, que foi cortado no recorte.

O custo é 1 geração por camada (`create_image_pixflux`), contra 40 de um objeto.

### 9.3 Pronto quando

A batalha sobe com `arena_id = "neon_grid"` mostrando as três camadas, e sobe **também**
com `arena_id = ""` mostrando o desenho procedural de antes. Os dois caminhos têm de
funcionar — o fallback é requisito, não cortesia.

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
2. `simulate.gd` reporta números equivalentes **à linha de base guardada na §0.5** —
   renderização não pode mexer no combate;
3. no hangar, trocar uma peça muda visivelmente o robô montado;
4. o pixel art está nítido, sem borrão e sem tremulação;
5. o robô não muda de tamanho nem escorrega ao trocar de pose nem ao girar.

### 10.1 Como julgar o critério 4 sem se enganar

Dois erros de leitura, ambos fáceis de cometer:

- **Julgue em 1080×1920, nunca no preview de desktop.** A janela de desktop é 540×960 e o
  `stretch/mode="canvas_items"` aplica mais um 0.5 — ali *nenhuma* escala é inteira e tudo
  parece borrado, inclusive o que está certo (§5.1).
- **Tremulação só aparece em movimento.** O corpo balança com `sin()` em
  `_apply_vertical_offset()`; um quadro parado não denuncia escala fracionária (§11.5).

### 10.2 Como julgar o critério 5

O modo mais rápido de flagrar recorte indevido (§11.1): force o `direction` a girar pelas
8 direções e confira que o bbox do robô **não muda de tamanho**. Se mudar, alguém pôs um
`get_used_rect()` de volta no caminho, ou o `art_height` está saindo de um 128 constante
em vez da altura do canvas do arquivo.

O `.captures/bench.png` do `sprite_bench` serve para isso: robô ~120×347 (§6.3.3), igual
em toda direção.

---

## 11. Armadilhas

### 11.1 Não recortar a textura — inviabiliza a montada

`ArtLibrary._load()` recorta ao conteúdo com `get_used_rect()`. Isso serve a uma peça de
vista única, mas destrói tudo aqui: cada parte tem bbox diferente (§6.3) e cada direção
tem bbox diferente da mesma parte (`face south` 27–101 vs `east` 23–104). Com recorte, o
robô muda de tamanho e escorrega a cada giro e a cada troca de pose, e a calibração de
`art_offset` deixa de ter significado estável. O `CharacterArt` devolve o quadro inteiro.

**Cuidado com "128×128":** o quadro inteiro nem sempre tem 128 px. Personagem sai 128,
objeto sai 136 (§2.1). Devolva o quadro inteiro *seja qual for o tamanho*, e tire
`art_height` da altura daquele canvas — não de uma constante 128.

### 11.2 O espelhamento do `back_view`

Ver §6.6. É silencioso: a arte aparece, só que espelhada — e na montada isso mostra a peça
do adversário no lado errado.

### 11.3 Os `.import` dentro do submódulo

Ver §4.1. Sem o `.gitignore`, o submódulo fica permanentemente sujo no `git status` do
repo do jogo.

### 11.4 A silhueta procedural depende das cores removidas

Os ~180 linhas de `_draw_torso`, `_draw_head`, `_draw_arm`… leem `body_color` e
`accent_color` (13 usos, de `robot_sprite.gd:441` a `:503`). **Não apague o desenho
procedural junto com a escolha de cor** — ele é o fallback que segura qualquer peça ou osso
que ainda não tenha arte, e some a tela inteira se for embora junto.

A troca é mecânica: apague os dois `@export` (`robot_sprite.gd:34` e `:39`) e ponha duas
constantes no mesmo arquivo, com os valores que hoje são o padrão:

```gdscript
## Paleta do desenho de reserva. Não é escolha do jogador (§7): a cor por unidade que
## sobrou vive em UnitStats e serve aos VFX, não à silhueta.
const FALLBACK_BODY := Color("4f9dde")
const FALLBACK_ACCENT := Color("8ef0ff")
```

Depois é `body_color` → `FALLBACK_BODY` e `accent_color` → `FALLBACK_ACCENT` nas 13
ocorrências. Nenhuma outra mudança: os `setter` que chamavam `_redraw_all()` deixam de
existir junto com os `@export`, e ninguém mais escreve nesses campos depois da §7.

**Quando a arte cobrir tudo, este desenho pode sair** — mas isso é decisão para depois de
a §6.2.2 calibrar os encaixes, não agora.

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
- **Gerar arte nova.** A §2.2 está completa. Se algo parecer faltando, é bug de caminho ou
  de calibração, não falta de arte — confira a §6.1.3 antes de abrir o PixelLab.
- **Calibrar os encaixes (`SlotDef`).** A §13.1 cobre os sete ossos, não os nove encaixes.
  Isso é trabalho real e previsto (§6.2.2), mas não bloqueia nenhuma fase: sem calibração o
  encaixe aparece torto, não some.
- Animação de dano por peça (faísca, fumaça). O `PartNode` já guarda a condição para isso
  (`feature_parts.md` §4.2), mas nada disso entra aqui.

---

## 13. Resultados da sessão de 2026-09-03

### 13.1 A calibração da §6.3, resolvida por medição

A §6.3 dizia que calibrar `art_height`/`art_offset` osso a osso, no editor, seria o item
mais caro do plano. Não foi preciso: dá para **medir**. O procedimento é determinístico e
repetível, e está roteirizado (ver §13.5).

Como funciona: mede-se o bbox de alpha de cada peça, monta-se o robô uma vez encostando
âncora em âncora (topo do braço no ombro do tórax, base da cabeça no pescoço, topo da perna
no soquete do quadril), e daí se resolve, para cada osso, o par que faz o `_draw_art`
reproduzir aquela montagem. A conta sai direto da fórmula do `PartNode`:

```
s            = art_height / altura_do_canvas
art_height   = altura_do_canvas * U
art_offset.x = cx_alvo   - ((x0+x1)/2 - largura_do_canvas/2) * U
art_offset.y = base_alvo + (altura_do_canvas - y1) * U
```

onde `(x0,y0,x1,y1)` é o bbox do conteúdo, `U` é quantas unidades de jogo vale um pixel de
arte, e `cx_alvo`/`base_alvo` são o centro-x e a base do conteúdo no espaço local do osso.

Com **`U = 1.0`** (um pixel de arte = uma unidade de jogo) todo osso fica com `art_height`
igual à altura do próprio canvas, a densidade de pixel é a mesma no corpo inteiro, e
qualquer `visual_scale` inteiro dá escala inteira na tela — que é o que a §5.1 pede.

| osso | art_height | art_offset | canvas |
| --- | --- | --- | --- |
| `head` | 128.0 | `Vector2(0, 54)` | 128 |
| `torso` | 128.0 | `Vector2(0, 59)` | 128 |
| `arm_left` | 128.0 | `Vector2(-65, 159)` | 128 |
| `arm_right` | 128.0 | `Vector2(65, 159)` | 128 |
| `leg_left` | 128.0 | `Vector2(-18, 63)` | 128 |
| `leg_right` | 128.0 | `Vector2(19, 63)` | 128 |
| `hip` | **136.0** | `Vector2(0, -81)` | **136** |

O `hip` destoa porque veio de `create_8_direction_object`, cujo canvas é 136 — é exatamente
a correção da §2.1: `art_height` sai da altura do canvas daquele arquivo.

**Conferido, não presumido:** o robô foi redesenhado a partir *só* desses números, imitando
`_draw_art` e encadeando `rest_position`, e comparado com a montagem de referência —
mesmo tamanho (120×347) e 0,15% de pixels divergentes, resíduo do arredondamento do resize.

**Estes números ainda NÃO foram aplicados em `humanoid.tres`.** Aplicá-los antes da Fase 3
quebraria o visual de hoje: os mesmos campos alimentam as silhuetas procedurais e a arte
Aseprite do chassi atual. Eles entram junto com o `CharacterArt`.

Um efeito colateral: o robô montado mede **347 unidades**, não 360. `RobotSprite.HEIGHT`
só ancora VFX (`battle.gd:272`, `301-302`) — trocar 360 por 347 é cosmético e sem risco.

### 13.2 CORREÇÃO — o `target_picker` não é espacial

A §8 manda revalidar o `ui/target_picker.gd` depois de mexer em posição e escala, "senão os
toques caem fora das hitboxes", e o critério 6 da §10 repete isso. **A premissa está
errada.** O `target_picker` é uma grade de `Button` com rótulo e porcentagem
(`_make_button`, `refresh`); ele nunca lê geometria de sprite. Mudar posição, escala,
`art_height` ou `art_offset` não tem como desalinhar alvo nenhum. Some um risco da Fase 5.

### 13.3 CORREÇÃO — o cenário não pode ser 360×640

O gerador de imagem do PixelLab limita **cada lado a 400 px**, então 640 de altura é
irrecusável. **216×384 × 5 = 1080×1920** chega no mesmo alvo com escala inteira, e com
pixel maior — mais pixel art, não menos. É o que está em `scenarios/neon_grid/`.

Duas armadilhas na geração de fundo: `no_background: true` **não é respeitado** (as três
camadas voltaram 100% opacas e foram recortadas por chroma-key), e o gerador inventa
conteúdo fora do pedido — o skyline veio com um reflexo espelhado embaixo, removido no
recorte. O horizonte do piso caiu em `y=151` (39%), perto dos 42% do `arena_background.gd`.

### 13.4 Ressalva aberta — a resolução do herói não casa com a do inimigo

A composição da §8 põe herói e inimigo no mesmo quadro. Só que a arte fullbody tem ~96 px
de conteúdo num canvas de 128, enquanto a montada tem 347 px de altura. Para o herói
aparecer grande em primeiro plano ele precisa de ~8×, contra 2× do inimigo — **pixels 4
vezes maiores no mesmo quadro**, e isso salta aos olhos na maquete.

**CORREÇÃO — `size` é consultivo quando há imagem de referência.** Tentei subir a fullbody
para 256 px com `mode="v3"` + `reference_image_url`: voltou 128, herdando as dimensões da
referência. Para sair de 128 é preciso gerar **do zero** em 256 — o que custa a identidade.

Gerei assim mesmo, e está em `characters/mk1/full_hires/` (246 px de conteúdo contra 96 da
`full/`). O que ela resolve e o que não resolve, medido nas maquetes:

| herói | densidade vs inimigo @2× | leitura |
| --- | --- | --- |
| `full` 128px @8× | 4:1 | pixel gritantemente maior; parece outro jogo |
| `full_hires` 256px @2× | 1:1 | densidade perfeita, mas o herói fica **pequeno demais** para ser moldura |
| `full_hires` 256px @4× | 2:1 | **o melhor acordo** — herói presente no canto, diferença discreta |

Ou seja: densidade igual e herói grande em primeiro plano são **objetivos incompatíveis**
aqui, porque a fullbody é uma imagem só e a montada é a soma de sete. O 4× é o meio-termo
que funciona.

#### O que falta, concretamente

Três coisas, e só a primeira é decisão:

**1. Escolher entre as três linhas da tabela** (ou a opção 4 abaixo). Maquetes em
`botbattle_assets/_reference/`.

**2. Se a escolha for `full_hires`: gerar a pose de ataque.** A `full_hires/` tem **só
`Idle`** — não tem `fighting_pose_flexe`. Sem ela a §6.5 não tem para onde trocar a pose no
turno, e o herói ataca parado. É um `create_character_state` sobre
`80f7782d-2531-4b0a-bcb2-52772729dc1b` com `edit_description` de pose de luta: 20–40
gerações, e sobraram 253.

**3. Se a escolha for `full_hires`: resolver a diferença de proporção.** Aqui uma correção
do que este plano dizia antes — **a `full_hires` TEM o visor ciano** (dá para ver em
`_reference/`; a afirmação anterior veio de miniatura e estava errada). A diferença real é
outra e é mais séria: a `full_hires` é um mecha de proporção realista (~6 cabeças de
altura), enquanto a `full/` e **a montada inteira** são atarracadas e semi-deformadas (~3,5
cabeças, cabeça grande). Herói e inimigo passam a parecer de duas famílias de design
diferentes — o que é pior do que a diferença de densidade que ela veio resolver. Paleta
(`recolor.py`) não conserta proporção; só regerar com prompt de proporção casada.

#### Opção 4 — usar a montada de perfil, testada e reprovada como está

Os sete ossos têm as 8 direções, então o herói poderia ser a **mesma montagem** em
`east`/`west`: mesma densidade, mesma linguagem de design, estados de dano de graça, zero
geração nova, e a §6.5 volta a ser o `AnimationPlayer` de sempre em vez de um caso especial.

**Testei. Não funciona com a calibração de hoje** — veja `_reference/`: em `east` a cabeça,
o tórax e as pernas viram três blocos soltos com vão entre eles. O motivo é que a §13.1
resolveu os offsets contra os bboxes de **`south`**, e em `east` cada peça ocupa outra
região do próprio canvas.

Cuidado com um falso positivo aqui: o **bbox do conjunto** fica estável nas 8 direções
(117–120 × 340–347), que é a §11.1 funcionando. Estabilidade de bbox **não** quer dizer
montagem correta — foi o que me enganou na primeira leitura.

Para essa opção viver, `art_offset` teria de virar **por direção** (`Dictionary` em
`BoneDef`, ou um `.tres` de calibração por direção), com o `PartNode` escolhendo pela
`direction`. O pipeline de `tools/` já sabe medir isso — é rodar por direção. É a opção
mais barata em arte e a mais cara em código.

### 13.5 Onde estão as coisas

Arte instalada em `botbattle_assets/`:

```
characters/mk1/<osso>/<Pose>/rotations/<dir>.png   7 ossos, metadata.json por osso
parts/<peca>/Idle/rotations/<dir>.png             as 11 peças
scenarios/neon_grid/{sky,backdrop,floor}.png      + metadata.json
```

Nada disso foi commitado ainda, e `characters/` segue *untracked* no repo de assets.

Os scripts que produziram tudo isso estão versionados em **`botbattle_assets/tools/`**
(`partlib.py`, `assemble.py`, `calibrate.py`, `verify.py`, `recolor.py`, `install*.py`),
com um `README.md` que explica como baixar as rotações e como refazer a calibração. Se uma
peça for regerada o bbox muda e **os números da §13.1 mudam junto** — rode `calibrate.py`
de novo em vez de editar `humanoid.tres` à mão.

Uma pegadinha anotada lá: as URLs de rotação do PixelLab são previsíveis e abertas, mas o
servidor **bloqueia o User-Agent do `urllib`** (403). Baixe com `curl`.

### 13.6 Sobrou na conta do PixelLab

Duas gerações descartadas ficaram lá, e é melhor apagar do que reaproveitar por engano:
o "mk1 hip" feito com `create_character` (virou um robô inteiro com uma caixa na cabeça) e
o primeiro `agile_leg`, que saiu com **duas** pernas em vez de uma.

Custo da sessão: **695 gerações** (de 948 disponíveis; sobraram 253 até 2026-10-03).
Objeto de 8 direções custa 40 e é o grosso da conta — as 11 peças mais o quadril, com as
duas refações, deram 520. Fundo com `create_image_pixflux` custa **1**.

### 13.7 O que esta sessão NÃO fez

Para não haver dúvida sobre o estado do repo:

- **`humanoid.tres` não foi tocado** — os números da §13.1 estão documentados, não aplicados
  (o porquê está na §13.1);
- **nenhum `.tres` de peça recebeu `art_id`** — é trabalho da Fase 3, junto do `CharacterArt`;
- **nada foi commitado** no repo de assets: `characters/`, `parts/`, `scenarios/`,
  `tools/` e `_reference/` seguem *untracked* em `botbattle_assets`. **Commite isso antes
  da Fase 1** — o submódulo só serve o que estiver no remoto, e um `git submodule add`
  apontando para um remoto sem essa arte deixa o jogo sem textura nenhuma;
- as Fases 0 a 7 continuam por fazer — isto aqui destravou a §2, não a implementação. O
  roteiro do que falta é a **§0**.

### 13.8 Uma pegadinha que muda entre sessões

Este plano cita linha de arquivo (`robot_sprite.gd:334`, `battle.gd:230`…). Todas foram
conferidas em 2026-09-03 e batiam. **Confira antes de confiar** — `grep -n` no símbolo é
mais barato que depurar a edição errada:

```bash
grep -n "_bone_art_resolver\|_mount_art_resolver\|play_body\|back_view" actors/robot_sprite.gd
```

O mesmo vale para o git: a §3.1 já teve de ser reescrita porque um commit entrou no meio
da sessão e transformou "nada foi commitado" em falso. Rode `git log --oneline -1` e
`git status --short` antes de seguir qualquer instrução de git deste documento.

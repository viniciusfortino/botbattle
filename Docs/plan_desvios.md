# Plano de execução: fechar os desvios do plano da anatomia

As nove fases do [plan_anatomy.md](plan_anatomy.md) estão implementadas e verificadas.
A validação encontrou quatro desvios que sobraram. Este documento fecha os quatro.

Cada tarefa é fechada e independente das outras — podem ser feitas em qualquer ordem.

---

## Regras válidas para todas as tarefas

Valem as mesmas do [plan_anatomy.md](plan_anatomy.md) ("Regras válidas para todas as
fases"), com destaque para três:

1. **Uma tarefa por vez.** Termine, verifique, pare e reporte.
2. **Não faça commit** a menos que o usuário peça.
3. **Estilo da casa.** Comentários em português, indentação com **tabs**, e todo
   `class_name` e função pública com um `##` que explica *por que* aquilo existe.

### As verificações

**Simulador** — nada aqui pode mexer no modelo:

```
BOTBATTLE_SEED=1 /Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/simulate.gd
```

A linha-base, que tem que sair idêntica caractere a caractere:

```
jogador sem_mira  | vitórias  20% | por desarme  90% | rodadas médias  4.6
jogador aleatoria | vitórias  28% | por desarme  94% | rodadas médias  4.2
jogador desarmar  | vitórias  82% | por desarme  99% | rodadas médias  2.7
```

**Smoke test** — a batalha inteira ainda termina:

```
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . -s tools/smoke_test.gd 2>&1 | grep "Fim da batalha"
```

Em headless as capturas falham com `Cannot call method 'save_png' on a null value` —
**é esperado e não é falha**. Não confie no código de saída depois de um pipe.

**Banco de sprites** — a referência visual, determinística (sem respiração):

```
/Applications/Godot.app/Contents/MacOS/Godot --path . -s tools/sprite_bench.gd
```

Antes de mexer em qualquer coisa visual, rode-o e guarde `.captures/bench.png` fora do
projeto. Depois, compare: a Tarefa 1 tem que dar **diferença de zero pixel**.

---

## Tarefa 1 — `PartNode` assume a própria condição e a própria arte

**O desvio.** A Fase 7 pedia que o `PartNode` expusesse `set_condition(cond)`. Ele
expõe `set_art(texture)`: quem decide o estado de dano e resolve a textura é o
`RobotSprite`, e o nó só recebe o resultado pronto. Funciona hoje, mas os VFX do
[feature_parts.md](feature_parts.md) §4.2 (faísca em `damaged`, fumaça em `critical`) e
o shader de dano precisam que o **nó** saiba em que estado está.

**Objetivo.** Mover para o `PartNode` a pergunta "em que estado eu estou" e a resolução
da arte que sai dela. O `RobotSprite` passa a dizer *de onde* vem a arte, não *qual* é.

**Arquivos.** `actors/part_node.gd`, `actors/robot_sprite.gd`

**Passos.**

1. Em `PartNode`, trocar `set_art(value: Texture2D)` por três membros:

```gdscript
## Como este pedaço resolve a própria arte: recebe a condição e devolve a textura, ou
## null quando não há arte para aquele estado. Vazio = só desenho procedural.
var art_resolver := Callable()

## Em que estado este pedaço está. É daqui que sai a variante da arte, e é onde os VFX
## de faísca e fumaça vão se pendurar (ver feature_parts.md §4.2).
func set_condition(value: BodyPart.Condition) -> void

func condition() -> BodyPart.Condition

## Troca a fonte da arte — muda quando a peça montada no encaixe muda.
func set_art_resolver(resolver: Callable) -> void
```

   Os dois setters chamam um `_refresh_art()` privado que faz
   `art_resolver.call(_condition)`, guarda o resultado e só chama `queue_redraw()` se a
   textura mudou de verdade. `has_art()` e `_draw()` continuam como estão.

2. Em `RobotSprite`, trocar `_bone_art()` e `_mount_art()` por
   `_bone_art_resolver(bone) -> Callable` e `_mount_art_resolver(slot_key, piece) -> Callable`.
   Cada um devolve uma `Callable` que recebe a condição e chama a `ArtLibrary`. **A
   lógica de escolha não muda** — só passa a ser decidida uma vez, ao montar a
   `Callable`, em vez de a cada consulta:
   - peça que substitui o osso e tem `art_id` → `ArtLibrary.part_texture(art_id, cond)`;
   - senão → `ArtLibrary.bone_texture(chassis_id, bone.key, cond)`;
   - `Engine.is_editor_hint()` ou `back_view` → `Callable()` vazia (sem arte).

   Capture `art_id`, `chassis_id` e a chave em variáveis locais antes de montar a
   lambda — não leia `self` de dentro dela.

3. Em `RobotSprite._sync()`, as duas chamadas a `node.set_art(...)` viram um par:

```gdscript
		node.set_art_resolver(_bone_art_resolver(bone))
		node.set_condition(_condition(bone.key))
```

   e o equivalente para os encaixes, usando a condição da hitbox da peça.

4. `_condition(key)` continua onde está. O helper que hoje só existe dentro de
   `_mount_art` (a condição da hitbox de uma peça montada) vira uma função nomeada.

**Invariantes.**

- **Zero pixel de diferença** no banco de sprites, antes e depois.
- Peça sem `art_id` e osso sem `.aseprite` continuam caindo no desenho procedural.
- No editor a pré-visualização continua sendo só a silhueta procedural.
- `queue_redraw()` só quando a textura realmente mudou — senão o `_sync()` redesenha o
  robô inteiro a cada golpe sem necessidade.

**O que esta tarefa NÃO faz.** O `actors/part_node.tscn` que a Fase 7 também pedia
**não será criado**. A cena do [feature_parts.md](feature_parts.md) §5 é um
`AnimatedSprite2D` com `SpriteFrames`, um `ShaderMaterial` de dano e três
`GPUParticles2D` — e nenhum desses recursos existe no projeto. Criar a cena agora seria
andaime vazio. Ela nasce junto com os VFX, no trabalho do `feature_parts.md`, e o
`set_condition()` desta tarefa é justamente o gancho que ela vai usar.

**Verificação.** Banco de sprites com diferença zero. Simulador = linha-base. Smoke test
completa.

**Pronto quando.** `grep -n "set_art\b" actors/` não acha mais nada, e o banco de
sprites é idêntico ao de antes.

---

## Tarefa 2 — a animação de corpo deixa de ser truncada

**O desvio.** A Fase 8 pedia que o dano esperasse o fim da animação. Não foi feito:
`scenes/battle/battle.gd:225` dispara e segue.

**Mas o requisito original estava errado**, e não deve ser implementado como escrito.
Esperar o fim da animação para só então aplicar o dano faria o alvo piscar *depois* de o
atacante terminar de recuar — o golpe e o impacto ficariam em momentos separados. O
impacto tem que cair **durante** a animação, e é o que já acontece hoje (0,22s no avanço
corpo a corpo, ~0,30s no feixe).

O defeito real é outro: **o turno pode avançar com a animação ainda tocando.** A espera
de fim de ação é fixa em 0,75s (`battle.gd`, logo antes de `manager.next_turn()`), então
`recoil` (0,42s) cabe, mas `crouch_fire` (0,8s) é cortada no meio quando a ação seguinte
chama `play_body()`.

> **Correção, medida depois de implementar.** O parágrafo acima está errado: os 0,75s não
> são o orçamento todo. Eles vêm **depois** da animação da ação, que já é awaitada:
> `lunge` = 0,16+0,06+0,28 = 0,50s (o `await tween.finished` espera o tween inteiro),
> `_play_beam` = 0,16+0,14 = 0,30s, `brace` = 0,14+0,22 = 0,36s. O orçamento real é
> **1,05s** no caminho mais curto (o feixe), 1,11s na guarda e 1,25s no corpo a corpo — e
> ainda mais quando quem age em seguida é a IA, que espera 0,5s antes de posar. Como cada
> combatente tem o **próprio** `AnimationPlayer`, só o mesmo ator agindo duas vezes
> seguidas (possível no empate de `speed`, na virada de rodada) poderia se cortar, e aí o
> intervalo mínimo é 1,05s (jogador) ou 1,55s (IA).
>
> Ou seja: `crouch_fire` (0,8s) **já cabia**, e nenhuma animação de hoje é cortada.
> A tarefa foi implementada mesmo assim, e deve continuar: ela é a guarda que passa a
> valer quando alguma animação ultrapassar ~1,05s. Mas a justificativa é **preventiva**,
> não corretiva — não espere ver diferença no jogo atual.

**Objetivo.** Nenhuma animação de corpo é interrompida pela troca de turno, sem mexer no
momento em que o dano cai.

**Arquivos.** `actors/robot_sprite.gd`, `combat/combatant.gd`, `scenes/battle/battle.gd`

**Passos.**

1. `RobotSprite.play_body(anim: String) -> float` passa a devolver a **duração** da
   animação que começou, ou `0.0` quando não tocou nada (nome vazio, animação
   inexistente, ou sem `AnimationPlayer`). A duração sai de
   `_player.get_animation(anim).length`.

2. `Combatant.play_body_animation(action_id: String) -> float` repassa esse número.

3. Em `battle.gd._on_action_performed`:
   - a chamada da linha 225 guarda o resultado e o instante em que a pose termina:

```gdscript
	# A pose entra junto com o avanço ou o recuo, não no lugar deles. O turno não pode
	# virar antes de ela acabar, senão a ação seguinte a corta no meio.
	var pose_seconds := actor.play_body_animation(String(result["action_id"]))
	var pose_ends_at := Time.get_ticks_msec() + int(pose_seconds * 1000.0)
```

   - e a espera do fim da ação (o `await get_tree().create_timer(0.75).timeout` logo
     antes de `if not manager.finished:`) ganha o resto da pose depois dela:

```gdscript
	await get_tree().create_timer(0.75).timeout
	var pose_left := float(pose_ends_at - Time.get_ticks_msec()) / 1000.0
	if pose_left > 0.0:
		await get_tree().create_timer(pose_left).timeout
```

**Invariantes.**

- Ação sem `body_animation` devolve `0.0`, `pose_left` fica negativo e **o ritmo é
  exatamente o de hoje** — vale para `attack` e `guard`.
- `recoil` dura 0,42s, menos que os 0,75s de sempre: plasma e laser também não mudam de
  ritmo.
- O momento em que `manager.commit(result)` é chamado **não muda em nenhum caso**.

**Verificação.** Simulador = linha-base (o modelo não é tocado). Smoke test completa.
Depois, uma sonda descartável que:
- confirme que `play_body("recoil")` devolve `0.42` e `play_body("crouch_fire")` `0.8`;
- confirme que `play_body("")` e `play_body("inexistente")` devolvem `0.0`;
- equipe uma peça com `body_animation = "crouch_fire"`, rode uma ação, e confirme que o
  `AnimationPlayer` ainda está em `crouch_fire` 0,7s depois do disparo.

> **Correção.** O terceiro item passa de graça: com 1,05s de orçamento, nada ia cortar a
> pose aos 0,7s de qualquer forma. Ele prova que `play_body` devolve a duração certa, não
> que o turno espera. Para provar a espera de verdade é preciso uma animação **maior que
> 1,05s** — só aí `pose_left` fica positivo.

**Pronto quando.** Uma ação sem animação tem o mesmo ritmo de antes, e `play_body`
devolve a duração de quem tocou (`0.0` para quem não tocou). O efeito de segurar o turno
só é observável com uma animação acima de ~1,05s, que ainda não existe.

---

## Tarefa 3 — as nove funções públicas sem `##`

**O desvio.** A regra 4 do plano manda um `##` em toda função pública. Nove ficaram sem.

**Arquivos e funções.**

| Arquivo | Funções |
| --- | --- |
| `combat/anatomy.gd` | `bone`, `slot`, `slot_keys` |
| `combat/stat_schema.gd` | `stat`, `keys` |
| `combat/chassis_catalog.gd` | `all`, `get_chassis`, `default_chassis` |
| `actors/part_node.gd` | `has_art` |

**Passos.** Acrescentar o `##` em cada uma. Explique **por que** ela existe, não o que a
linha faz — leia `combat/body.gd` e `combat/loadout.gd` como referência de tom. Uma
linha basta; duas quando houver uma decisão embutida (por que `slot_keys()` sai da
anatomia e não de uma constante, por que o catálogo é lista explícita).

**Invariantes.** Nenhuma mudança de comportamento. Só comentário.

**Verificação.** Simulador = linha-base. Smoke test completa.

**Pronto quando.** Este script não imprime nenhum nome:

```
python3 - <<'PY'
import re
for f in ["combat/anatomy.gd","combat/stat_schema.gd","combat/chassis_catalog.gd","actors/part_node.gd"]:
    lines = open(f).read().split("\n")
    for i, l in enumerate(lines):
        m = re.match(r'^(static )?func ([a-z]\w*)', l)
        if not m:
            continue
        j = i - 1
        while j >= 0 and lines[j].strip() == "":
            j -= 1
        if j < 0 or not lines[j].lstrip().startswith("##"):
            print(f, m.group(2))
PY
```

---

## Tarefa 4 — devolver o save do jogador ao estado de fábrica

**O desvio.** Uma sonda de verificação da Fase 9 gravou por cima de
`user://loadout.json`, que guardava a montagem real do usuário. O arquivo hoje tem uma
montagem de teste (MK-III Strider, plasma, espada curta, duas pernas ágeis). O conteúdo
original não é recuperável: pelas capturas sabe-se que era **MK-I** com **canhão laser
CL-1** no topo da cabeça, e nada além disso.

**Objetivo.** Não deixar um estado inventado no lugar do estado perdido.

**Passos.**

1. Apagar o arquivo:

```
rm ~/Library/Application\ Support/Godot/app_userdata/BotBattle/loadout.json
```

2. Não recriá-lo. `PlayerLoadout.load_saved()` (`globals/player_loadout.gd`) já cai em
   `res://units/r7.tres` quando o arquivo não existe — que é MK-I, o exoesqueleto certo.
   O jogador remonta no hangar e o arquivo volta a existir no primeiro BATALHAR.

**Invariantes.** Não escrever um `loadout.json` novo por script. Um save fabricado é
pior que save nenhum: parece o do jogador e não é.

**Verificação.** Abrir o hangar e confirmar que ele carrega no MK-I sem aviso no console.

**Pronto quando.** O arquivo não existe e o hangar abre na montagem padrão.

---

## Relatório ao fim de cada tarefa

```
Tarefa N — <nome>

Placar (BOTBATTLE_SEED=1):
  <as três linhas>
  → idêntico à linha-base | DIVERGIU: <o quê>

Smoke test: <a linha "Fim da batalha">
Banco de sprites: <diferença em pixels, quando a tarefa for visual>

Arquivos: criados <n>, editados <n>, apagados <n>

Fora do plano: <o que você encontrou e não consertou, ou "nada">
Decisões: <o que o plano não dizia e você teve que escolher, ou "nenhuma">
```

---

## O que este plano deliberadamente não cobre

A validação também encontrou pendências que **não** são desvios do plano da anatomia —
são dívidas anteriores ou decisões em aberto. Ficam para depois, cada uma com o seu
próprio escopo:

- `chassis/mk1_standard.tres` — duplicado vazio do MK-I, fora do catálogo. Provavelmente
  é para apagar, mas é decisão do usuário.
- O estado de sobrecarga é código morto desde o commit `ed125f0`: `is_valid()` nunca é
  falso, então a barra vermelha e o "CARGA EXCEDIDA" do hangar são inalcançáveis.
- `scenes/battle/battle.gd:229` ainda escolhe o feixe comparando
  `action_id == "plasma"` — é o mesmo cheiro de comparação por id que o refactor tirou
  dos outros lugares, e é por isso que o laser não desenha feixe nenhum. O conserto
  natural é um campo de VFX na ação, no mesmo molde do `body_animation`.
- Nenhum `.tres` de chassi aponta `anatomy`; todos caem no padrão. Só passa a importar
  quando existir uma segunda forma de robô.

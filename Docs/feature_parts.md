# Feature: Sprites das peças (visual modular com Aseprite)

Documento que descreve como trocar o corpo desenhado por código (`_draw()`) por sprites
reais, editáveis no Aseprite e importados pelo **AsepriteWizard** (já instalado no
projeto). Cada peça do catálogo ganha uma representação visual própria, com estados de
integridade e animações por tag.

---

## 1. Por que Aseprite

O corpo do robô hoje é desenhado inteiramente por código em
`actors/robot_sprite.gd` — retângulos arredondados, círculos, elipses. Funciona
como placeholder, mas não escala: cada variação visual exige dezenas de linhas de
`_draw()`, e não há como um artista iterar sem abrir o código.

**Aseprite** é o padrão da indústria para pixel art e sprite animation. Para o
BotBattle, as vantagens são:

| Problema atual | Como o Aseprite resolve |
| --- | --- |
| Variações de peça exigem mudar código GDScript | O artista edita o `.aseprite` e salva; o AsepriteWizard reimporta automaticamente |
| Não há estados visuais (peça nova vs. degradada vs. destruída) | **Tags** dentro do mesmo arquivo: `idle`, `damaged`, `critical` — o Godot recebe como animações separadas num `SpriteFrames` |
| Sem camadas — tudo é flat | O Aseprite mantém camadas (estrutura, blindagem, efeito, glow) editáveis separadamente |
| Não há animação de peça | Frames por tag: idle com respiração, disparo, impacto — tudo no mesmo `.aseprite` |
| Colorização por `body_color` é limitada | Paletas indexadas no Aseprite permitem trocar esquemas de cor por script sem perder detalhe |

O projeto já tem o addon **AsepriteWizard v9.8.0** em `addons/AsepriteWizard/`. Ele
importa `.aseprite` direto para `SpriteFrames`, `AnimatedSprite2D` ou spritesheets,
sem pipeline manual.

---

## 2. O que muda e o que não muda

A troca é **só visual**. Toda a mecânica de combate — hitboxes, transbordo, degradação
de arma, requisitos de mobilidade — continua exatamente como está. O que muda:

| Camada | Antes | Depois |
| --- | --- | --- |
| `Part` (`combat/part.gd`) | Só atributos numéricos | Ganha um campo `sprite_frames: SpriteFrames` |
| `RobotSprite` (`actors/robot_sprite.gd`) | `_draw()` com formas geométricas | Composição de `AnimatedSprite2D` por slot |
| `Combatant` | Chama `flash()`, `set_loadout()` | Mesma interface; passa a tocar animações de peça |
| `Loadout` | Monta a ficha e resolve stats | Sem mudança — já entrega as peças para o `RobotSprite` |

---

## 3. Estrutura dos arquivos de sprite

```
assets/
  sprites/
    chassis/
      mk1/
        torso_front.aseprite
        torso_back.aseprite
        head_front.aseprite
        head_back.aseprite
        shoulder_front.aseprite     ← coto do ombro (sempre visível)
        shoulder_back.aseprite
        hip_front.aseprite          ← quadril (sempre visível)
        hip_back.aseprite
    parts/
      legs/
        agile_leg_front.aseprite
        agile_leg_back.aseprite
        heavy_leg_front.aseprite
        heavy_leg_back.aseprite
      arms/
        short_sword_front.aseprite
        short_sword_back.aseprite
        plasma_cannon_front.aseprite
        plasma_cannon_back.aseprite
        blade_forearm_front.aseprite
        blade_forearm_back.aseprite
        heavy_arm_front.aseprite
        heavy_arm_back.aseprite
      back/
        turbo.aseprite
        dorsal_armor.aseprite
      chest/
        chest_plate.aseprite
        power_cell.aseprite
        generator.aseprite
      head/
        sensor.aseprite
        laser_cannon_head.aseprite
```

### Por que `_front` e `_back`

O jogo mostra o R-7 **de costas** e o oponente **de frente**. O `RobotSprite` já tem
`back_view: bool` para lidar com isso. Cada peça que muda de aparência entre frente e
costas precisa de dois arquivos. Peças que ficam iguais dos dois lados (costas, topo
da cabeça) têm só um.

### Por que separar chassis e parts

O **chassis** é o exoesqueleto base — tórax, cabeça, ombros e quadril. Ele está sempre
presente (todo robô tem um `Chassis`). As **peças** são montadas nos encaixes e podem
ser trocadas. O chassis define a silhueta base; as peças se encaixam nela.

---

## 4. Estados visuais e Efeitos Genéricos (VFX)

A estratégia visual será uma composição **Híbrida**: a peça desenha a *estrutura* do dano e da ação (amassados, peças abrindo, canos esquentando), enquanto o motor do jogo injeta os *efeitos dinâmicos* por cima (partículas de fumaça, faíscas e chamas).

O `.aseprite` de cada peça será focado na **estrutura mecânica e no desgaste físico**. O fogo volumoso e a fumaça rodopiante ficam de fora do sprite para serem instanciados como partículas genéricas (VFX).

### 4.1 O que fica no arquivo `.aseprite` da peça (Tags)
Cada peça terá as seguintes tags que alteram o seu *chassi*:
- **`idle`**: A pose padrão, intacta.
- **`damaged`**: Marcas de dano estrutural leve (arranhões profundos, chapa amassada, fio partido). Sem faíscas voando ou fumaça animada no pixel art.
- **`critical`**: Dano estrutural severo (armadura arrancada, esqueleto interno exposto, cano torto).
- **`action`** (ex: `fire` ou `attack`): A animação mecânica da ação. No caso do lança-chamas, os canos ficam vermelhos incandescentes e recuam levemente, mas a *chama em si* não é desenhada no sprite. No caso de uma lâmina, o braço avança.

### 4.2 O que vira Efeito Visual Genérico (VFX) no Godot
Uma pasta separada `assets/sprites/vfx/` guardará os sistemas de partículas universais do jogo, que são "ancorados" sobre a peça:
- **`FireVFX`**: Partículas ou sprite genérico de chamas. Quando a tag `fire` da peça toca, instanciamos essa animação saindo da boca da arma.
- **`SparksVFX`**: Partículas de faísca. Ativadas por cima do sprite quando ele está na tag `damaged` ou `critical`.
- **`SmokeVFX`**: Partículas de fumaça escura. Instanciadas ancoradas ao sprite quando ele está na tag `critical`.
- **`Hit Flash Shader`**: O piscar em branco/ciano quando atingido será um Shader no Godot, dispensando a necessidade de uma tag `hit` desenhada à mão em toda peça.

### 4.3 Vantagens da Composição Híbrida
- **Detalhe sob medida**: A peça realmente parece quebrada estruturalmente (buracos, rachaduras), o que não dá para simular só com shaders.
- **VFX Dinâmicos**: A fumaça e as faíscas via `GPUParticles2D` dão um visual muito mais fluido, orgânico e aleatório do que fumaça em pixel art loopada, enchendo mais a tela.
- **Desacoplamento**: A chama do lança-chamas não cobre metade da tela no arquivo da arma, mantendo o canvas limpo e focado no design da peça; e usamos o mesmo VFX de chama para várias armas.

---

## 5. Anatomia do `RobotSprite` novo

O `RobotSprite` deixa de ser um `Node2D` com `_draw()` e passa a ser uma **cena (`.tscn`)** contendo uma série de nós customizados `PartNode` em vez de simples `AnimatedSprite2D`.

O `PartNode` será uma cena filha que encapsula o Sprite da peça + seus efeitos visuais.

```
RobotSprite (Node2D)
  ├── Shadow
  ├── BackLayer (Node2D)
  │   ├── Back1 (PartNode)
  │   └── Back2 (PartNode)
  ├── LegLeft (PartNode)
  ├── LegRight (PartNode)
  ├── Hip (PartNode)          ← chassis
  ├── Torso (PartNode)        ← chassis
  ├── ChestLayer (Node2D)
  │   ├── Chest1 (PartNode)
  │   └── Chest2 (PartNode)
  ├── ShoulderLeft (PartNode) ← chassis
  ├── ArmLeft (PartNode)      ← braço
  ├── ShoulderRight (PartNode)
  ├── ArmRight (PartNode)
  ├── Neck (PartNode)         ← chassis
  ├── Head (PartNode)         ← chassis
  └── HeadTop (PartNode)      ← topo da cabeça
```

**Anatomia interna de cada `PartNode.tscn`:**
```
PartNode (Node2D)
  ├── Sprite (AnimatedSprite2D)       ← Aqui vai o SpriteFrames da peça (idle/action)
  │   └── ShaderMaterial              ← Lida com a colorização do player e o "Damage Shader"
  ├── VFXAnchor (Marker2D)            ← Onde centralizamos as faíscas/fogo
  │   ├── FireVFX (GPUParticles2D ou AnimatedSprite2D genérico)
  │   ├── SparksVFX (GPUParticles2D)
  │   └── SmokeVFX (GPUParticles2D)
```

A ordem dos nós na árvore define o Z-order (quem desenha na frente de quem). A
árvore acima garante que:
- Peças das costas ficam atrás do corpo.
- Pernas ficam atrás do tórax.
- Ombros ficam na frente do tórax, braços na frente dos ombros.
- Cabeça no topo.

Para a vista de costas (`back_view = true`), o `RobotSprite` troca o `SpriteFrames`
de cada nó para a variante `_back`, e inverte a ordem dos braços (o braço esquerdo do
robô aparece à esquerda da tela de costas, mas à direita de frente).

---

## 6. Mudanças no `Part` (`combat/part.gd`)

Dois campos novos:

```gdscript
@export_group("Visual")
## SpriteFrames gerado pelo AsepriteWizard a partir do .aseprite (visão frontal).
@export var sprite_front: SpriteFrames = null
## SpriteFrames para a visão de costas (null = mesma da frente).
@export var sprite_back: SpriteFrames = null
```

Cada `.tres` em `parts/` passará a referenciar os `SpriteFrames` importados. O
Inspetor do Godot permite arrastar o recurso direto.

---

## 7. Mudanças no `RobotSprite`

### 7.1 `set_loadout(loadout, body)`

Continua sendo o ponto de entrada. A lógica nova:

```gdscript
func set_loadout(loadout: Loadout, body: Body = null) -> void:
    _loadout = loadout
    _body = body

    # Chassis
    _apply_chassis(loadout.chassis)

    # Peças nos encaixes
    for key in Loadout.SLOT_KEYS:
        var part := loadout.get_part(key)
        var sprite_node := _sprite_for(key)
        if sprite_node == null:
            continue
        if part == null or part.sprite_front == null:
            sprite_node.visible = false
            continue

        var frames := part.sprite_back if back_view and part.sprite_back else part.sprite_front
        sprite_node.sprite_frames = frames
        sprite_node.visible = true
        _update_part_state(key, sprite_node)
```

### 7.2 `_update_part_state(key, part_node)`

Agora, a função gerencia tanto a troca de tag estrutural no Sprite quanto a ativação dos emissores de VFX:

```gdscript
func _update_part_state(key: String, part_node: Node2D) -> void:
    if _body == null:
        part_node.set_state("idle", 0.0)
        return

    var hitbox = _body.part_by_key("part:%s" % key)
    if hitbox == null:
        hitbox = _body.part_by_key(key)
    if hitbox == null:
        return

    if not hitbox.is_intact():
        part_node.visible = false    # destruída — some do desenho
        return

    var ratio := float(hitbox.current_hp) / float(hitbox.max_hp)
    
    var state = "idle"
    if ratio <= 0.2:
        state = "critical"
    elif ratio <= 0.5:
        state = "damaged"
        
    part_node.set_state(state, ratio)
```

No `PartNode`, o método `set_state(tag, ratio)` cuidaria de:
1. Mudar a animação do `AnimatedSprite2D` para a tag estrutural (`idle`, `damaged`, ou `critical`).
2. Passar `ratio` para o Shader, para pequenos ajustes finos (se necessário).
3. Se `state == "damaged"`, ativar a emissão de partículas do `SparksVFX`.
4. Se `state == "critical"`, manter o `SparksVFX` ligado e ativar também a emissão pesada do `SmokeVFX`.

### 7.3 `on_part_hit(key)` e Ações

O hit passará a ser resolvido em um piscar via Shader e um efeito de impacto instanciado na coordenada global da peça:

```gdscript
func on_part_hit(key: String) -> void:
    var part_node := _part_for(key)
    if part_node == null or not part_node.visible:
        return
    part_node.flash_hit() # Dispara um Tween temporário no Hit Flash Shader
    VFXManager.spawn_hit_spark(part_node.global_position)
```

**Para ações como atacar (fogo):**
O manager mandaria o `PartNode` tocar a tag `fire` (no Aseprite isso faria o cano esquentar e avermelhar) e ligaria o emissor de partículas `FireVFX` simultaneamente. Ao fim do ataque, o `FireVFX` é desligado e o sprite volta para a tag estrutural atual (`idle`, `damaged`, etc).

### 7.4 Compatibilidade com o `_draw()` existente

O `_draw()` **não será apagado imediatamente**. Ele fica como fallback: se uma peça
não tiver `sprite_front`, o `RobotSprite` desenha a silhueta geométrica antiga para
aquele slot. Isso permite migrar peça a peça, sem precisar ter todos os sprites prontos
de uma vez.

```gdscript
func _draw() -> void:
    if _all_parts_have_sprites():
        return    # tudo por sprite, nada para desenhar
    _draw_fallback()  # o código geométrico antigo, só para peças sem sprite
```

---

## 8. Convenções para os arquivos `.aseprite`

Para que o AsepriteWizard importe corretamente e o código funcione sem surpresas:

| Regra | Motivo |
| --- | --- |
| Canvas de **128×256 px** para braços e pernas, **192×256 px** para tórax | Proporção consistente; escala definida no nó, não no pixel |
| Origem (pivot) no **centro inferior** do canvas | Compatível com a origem nos "pés" do `RobotSprite` |
| Nomes de tag em **snake_case minúsculo**: `idle`, `damaged`, `critical`, `hit`, `attack`, `fire` | O código busca por essas strings exatas |
| Tag `idle` é **obrigatória** em todo `.aseprite` | É o fallback; sem ela o sprite não toca nada |
| Loop: `idle`, `damaged`, `critical` em **loop infinito**; `hit`, `attack`, `fire` em **one-shot** | One-shot termina e emite `animation_finished`, que o código usa para voltar ao estado |
| Paleta indexada com no máximo **32 cores** | Permite recoloração programática para variantes de cor |

---

## 9. Pipeline de trabalho do artista

```
1. Abre o Aseprite
2. Cria ou edita o .aseprite em assets/sprites/parts/<categoria>/
3. Define as tags (idle, damaged, critical, hit…)
4. Salva o arquivo
5. O AsepriteWizard detecta a mudança e reimporta → gera o SpriteFrames
6. No Godot, arrasta o SpriteFrames para o campo sprite_front do .tres da peça
7. Roda o jogo e vê o resultado
```

Não há passo de exportação manual. O `.aseprite` é o arquivo-fonte, vive no
repositório, e o addon cuida do resto.

---

## 10. Colorização por script

Hoje cada robô tem `body_color` e `accent_color` que pintam as formas do `_draw()`.
Com sprites, a recoloração funciona assim:

**Opção escolhida: paleta indexada + shader.**

Cada `.aseprite` usa uma paleta padronizada onde as primeiras cores são "variáveis":

| Índice | Significado | Valor padrão |
| --- | --- | --- |
| 0 | Transparente | — |
| 1 | `body_primary` | azul médio |
| 2 | `body_shadow` | azul escuro |
| 3 | `body_highlight` | azul claro |
| 4 | `accent` | ciano |
| 5 | `accent_glow` | ciano claro |
| 6–31 | Cores fixas (metal, preto, branco…) | não mudam |

Um `ShaderMaterial` no `AnimatedSprite2D` recebe `body_color` e `accent_color` e
substitui os índices 1–5 pelas variantes calculadas (darkened, lightened). Resultado:
a mesma perna ágil aparece azul no R-7 e vermelha na Sentinela, sem duplicar sprites.

---

## 11. Inventário das peças atuais

Peças que existem em `parts/` e precisarão de sprites:

| Peça | Slot | Arquivo | Concede ação | Precisa de `_front` + `_back` |
| --- | --- | --- | --- | --- |
| Perna ágil AL-1 | `LEG_FULL` | `agile_leg.tres` | — | sim |
| Perna pesada PB-2 | `LEG_FULL` | `heavy_leg.tres` | — | sim |
| Espada curta | `ARM_MOUNT` | `short_sword.tres` | `attack` | sim |
| Antebraço-lâmina | `FOREARM` | `blade_forearm.tres` | `attack` | sim |
| Canhão de plasma | `ARM_MOUNT` | `plasma_cannon.tres` | `plasma` | sim |
| Braço pesado | `ARM_FULL` | `heavy_arm.tres` | — | sim |
| Canhão laser | `ARM_MOUNT` | `laser_cannon.tres` | `laser` | sim |
| Turbo T-3 | `BACK` | `turbo.tres` | — | não (só nas costas) |
| Armadura dorsal | `BACK` | `dorsal_armor.tres` | — | não |
| Placa de peito | `CHEST` | `chest_plate.tres` | — | só `_front` |
| Célula de energia | `CHEST` | `power_cell.tres` | — | só `_front` |
| Gerador | `CHEST` | `generator.tres` | — | só `_front` |
| Sensor | `HEAD_TOP` | `sensor.tres` | — | não (simétrico) |

Além das peças, o chassis MK-I precisa de sprites para: tórax, cabeça, ombros,
quadril e pescoço (frente e costas).

**Total estimado: ~30 arquivos `.aseprite`.**

---

## 12. O que falta definir

Questões abertas para resolver antes de implementar:

1. **Resolução dos sprites.** O canvas sugerido (128×256 para membros) é adequado
   para a resolução do viewport (1080×1920)? Precisamos prototipar uma peça e ver a
   escala no jogo antes de definir.

2. **Animações de ataque.** O avanço do corpo a corpo hoje é uma animação do
   `Combatant` inteiro (o nó se desloca). As peças de braço devem ter animação de
   golpe interna (frames no `.aseprite`) ou o movimento continua sendo posicional
   (tween no nó)?

3. **Braço de fábrica.** Quando o encaixe do braço é `ARM_MOUNT` (peça acoplada ao
   antebraço do exoesqueleto), o braço de fábrica do chassis aparece + a peça por cima.
   Precisamos de um sprite separado para o "braço nu" do chassis, e a peça ARM_MOUNT
   se desenha **em cima** dele. Para `FOREARM` e `ARM_FULL`, a peça substitui o braço.

4. **Perna de fábrica.** Quando `leg_left_part` é `null`, o robô usa a perna do
   exoesqueleto. Precisamos de sprite da perna de fábrica no chassis.

5. **Grau de detalhe por estado.** `damaged` e `critical` são suficientes, ou
   queremos mais granularidade (ex.: `damaged_light`, `damaged_heavy`)?

6. **Prioridade de produção.** Começar pelos membros (braços e pernas) que já têm
   mecânica de destruição, ou pelo chassis que é a base visual?

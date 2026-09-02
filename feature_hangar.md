# Feature: Hangar e sistema de peças

O robô não vem pronto: ele é montado. Este documento cobre a tela inicial onde isso
acontece e o modelo de peças que a alimenta. O que essas escolhas causam dentro da
batalha está em [feature_battle.md](feature_battle.md).

---

## 1. A tela

O jogo abre no hangar. De cima para baixo:

| Região | Conteúdo |
| --- | --- |
| Topo | Nome do robô (editável), atributos resolvidos e a barra de carga |
| Meio | O robô, desenhado com as peças que estão montadas |
| Base | Abas **Peças** / **Cores**, e o botão **BATALHAR** |

Tudo é ao vivo: trocar uma peça recalcula os atributos, a carga e o desenho no mesmo
frame. Se a carga passar da capacidade do exoesqueleto, a barra fica vermelha e o botão
vira **CARGA EXCEDIDA**, desabilitado — a montagem inválida não entra em campo.

O que você escolhe aqui vale para a batalha inteira. **Não há troca de peça no meio do
combate**; o que quebrar, quebrou.

---

## 2. Os cinco atributos

| Atributo | O que faz |
| --- | --- |
| **Força** | Base do dano causado. |
| **Agilidade** | Ordem dos turnos — quem tem mais age primeiro. |
| **Resistência** | A vida da hitbox daquela peça. Uma perna resistente aguenta mais golpes antes de cair. |
| **Defesa** | Soma no robô inteiro e reduz o dano de cada golpe recebido. |
| **Peso** | O custo. Ocupa carga no exoesqueleto e, passando da metade dela, come agilidade. |

### O peso é o orçamento

O exoesqueleto MK-I carrega **120**. Metade disso é grátis; daí em diante a agilidade
cai progressivamente:

```
fator = 1 − 0,3 × clamp((carga/capacidade − 0,5) / 0,5 , 0 , 1)

 48/120 (40%) → ×1,00     90/120 (75%) → ×0,85
 72/120 (60%) → ×0,94    120/120 (100%) → ×0,70
```

Passar de 120 não é uma penalidade maior: é montagem inválida. Isso força a decisão que
dá graça ao sistema — blindar custa mobilidade, e mobilidade decide quem bate primeiro.

---

## 3. Os encaixes

```
Topo da cabeça  ×1     canhão laser, sensor
Costas          ×2     turbos, gerador, blindagem
Peito           ×2     placas, célula de energia
Braços          ×1 cada, em um de três modos
Pernas          ×1 cada, troca total
```

### Os três modos de braço

O modo não é escolhido separadamente: **a peça que você encaixa é que define o modo**.
A lista do braço mostra as opções dos três tipos de uma vez, cada uma marcada com o modo
em que entra.

| Modo | O que sobra do exoesqueleto | O que entra |
| --- | --- | --- |
| Braço de fábrica | o braço inteiro | uma peça **acoplada** ao antebraço (espada, canhão de plasma) |
| Antebraço trocado | só o braço superior | uma peça de **antebraço**, que substitui o antebraço |
| Braço completo | nada | uma peça de **braço inteiro** |

Quantidade de hitboxes muda junto: nos dois primeiros modos o braço são **duas** hitboxes
(o membro e a peça); no terceiro, a peça **é** o braço, numa hitbox só.

As pernas hoje só têm troca total. A estrutura já comporta um modo parcial sem
refatoração — é o mesmo desenho dos braços.

---

## 4. O catálogo

| Encaixe | Peça | FOR | AGI | RES | DEF | PESO | Concede |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Cabeça | Canhão laser CL-1 | 6 | — | 14 | — | 14 | **Laser** |
| Cabeça | Sensor tático | — | 4 | 10 | — | 6 | — |
| Costas | Turbo T-3 | — | 6 | 10 | — | 10 | — |
| Costas | Gerador GX | — | — | 8 | — | 12 | +12 energia |
| Costas | Blindagem dorsal | — | −2 | 12 | 3 | 16 | — |
| Peito | Placa reforçada | — | −1 | 14 | 4 | 18 | — |
| Peito | Célula de energia | — | — | 10 | — | 8 | +10 energia |
| Acoplamento | Espada curta | 4 | — | 14 | — | 8 | **Atacar** |
| Acoplamento | Canhão de plasma | 6 | — | 16 | — | 12 | **Plasma** |
| Antebraço | Antebraço-lâmina | 5 | 1 | 16 | 1 | 12 | **Atacar** |
| Braço completo | Braço pesado HB-2 | 8 | −2 | 30 | 2 | 26 | **Atacar** |
| Perna | Perna ágil AL-1 | — | 4 | 16 | — | 12 | — |
| Perna | Perna pesada PB-2 | — | −2 | 26 | 2 | 24 | — |

Exoesqueleto MK-I: força 12, agilidade 10, defesa 4, energia 18, capacidade 120, e
resistência de fábrica 14 (cabeça) / 34 (tórax) / 20 (braço) / 18 (perna).

O **canhão laser** é o único armamento que não depende de braço nem de perna: montado na
cabeça, ele continua disparando com o robô imobilizado e desarmado. É a arma de último
recurso — e por isso o alvo preferido de quem sabe mirar.

Escolher uma peça mostra o **delta** antes de confirmar (`FOR +2  AGI −1  PESO +4  RES 16
→ Plasma`), o que transforma a montagem em decisão em vez de tentativa e erro.

---

## 5. Cores e nome

A aba **Cores** tem duas paletas de oito: corpo e detalhe. O detalhe é o que brilha nos
núcleos, visores e bocas de canhão. O robô ao lado atualiza no mesmo toque.

O nome aceita 18 caracteres e aparece no HUD e em todas as linhas do log de combate.

---

## 6. Persistência

A montagem é gravada em `user://loadout.json` ao tocar em BATALHAR, e recarregada quando
o jogo abre. O save guarda **ids de peça**, não recursos serializados:

```json
{
  "pilot_name": "R-7",
  "body_color": "4f9dde",
  "accent_color": "8ef0ff",
  "arm_left_mode": 0,
  "arm_right_mode": 0,
  "slots": { "arm_right": "short_sword", "leg_left": "agile_leg", "...": "" }
}
```

Assim mexer nos `.tres` do catálogo nunca corrompe um save antigo: uma peça cujo id
sumiu vira encaixe vazio, com aviso no log em vez de erro.

O autoload `PlayerLoadout` (`globals/player_loadout.gd`) é quem guarda a montagem atual
e faz load/save. A batalha lê dele em `_enter_tree()` — antes do `_ready()` do
combatente, que é onde o corpo é construído.

---

## 7. Onde cada coisa mora

| Arquivo | Responsabilidade |
| --- | --- |
| `combat/part.gd` | Uma peça: encaixe, atributos, ação concedida, dados de hitbox. |
| `combat/chassis.gd` | O exoesqueleto: atributos base, capacidade, resistência de fábrica. |
| `combat/loadout.gd` | A montagem, `resolve()` para atributos, `equip()` e a penalidade de carga. |
| `combat/part_catalog.gd` | Índice das peças por id e por encaixe. |
| `parts/*.tres`, `chassis/mk1.tres` | O catálogo. |
| `scenes/hangar/hangar.gd` | A tela: atributos ao vivo, listas, cores, ida para a batalha. |
| `globals/player_loadout.gd` | Autoload: montagem atual e persistência. |

A ponte com o combate é uma função só: **`Loadout.resolve()` devolve um `UnitStats`**,
que é o formato que a batalha já sabia ler. Foi isso que permitiu trocar fichas fixas
por montagem sem reescrever o combate.

---

## 8. Como estender

**Nova peça.** Crie o `.tres` em `parts/` e acrescente o id em `PartCatalog.IDS` (a lista
é explícita porque varrer diretórios não é confiável dentro do `.pck` exportado). Se ela
concede uma ação, aponte `grants_action` para um id de `Actions.LIST`.

**Nova arma.** Defina a ação em `Actions.LIST` (dano, custo, precisão, `needs_legs`) e
crie a peça que a concede. Requisitos, botão, filtro da IA e aviso de perda no log
passam a funcionar sem mais nenhuma linha.

**Novo exoesqueleto.** Duplique `chassis/mk1.tres` com outra capacidade e outras
resistências de fábrica — um chassi leve e um pesado já mudariam completamente as
montagens viáveis.

**Modo parcial de perna.** `Loadout.ArmMode` e `accepted_slot()` mostram o padrão a
seguir; hoje a perna só tem troca total.

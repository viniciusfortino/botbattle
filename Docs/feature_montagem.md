# Feature: Montagem — esqueleto, ossos, peças e acoplamentos

Documento de desenho. Descreve o modelo de composição do robô: o que é uma peça, onde
ela encaixa, quem decide se ela cabe, o que ela soma e o que acontece quando ela cai.

É o documento fundador da dinâmica do jogo — **o robô é o que está montado nele**. Os
outros documentos descrevem partes dessa ideia com o vocabulário antigo: o
[feature_anatomy.md](feature_anatomy.md) tirou a forma do código e a pôs em recurso, e o
[feature_parts.md](feature_parts.md) descreve como a peça aparece. Este redefine o que a
peça *é*, e por isso substitui o modelo de dados dos dois.

---

## 1. O problema

O modelo de hoje descreve um robô com peças **penduradas** num corpo fixo. O jogo que
queremos é um robô **feito** de peças. As cinco consequências disso são todas concretas.

**"Osso" significa duas coisas ao mesmo tempo.** `BoneDef` é o segmento estrutural, mas
`arm_left` também é o braço em si. Quando a peça troca o braço inteiro, ela vira a
hitbox do osso (`MountDef.replaces_host` → `body_part.gd:88 adopt()`) — e aí não dá mais
para dizer se `arm_left` é a estrutura ou a peça.

**Estrutura e peça são duas classes que não se falam.** `BoneDef` (`combat/bone_def.gd`)
existe sempre e vem da anatomia; `Part` (`combat/part.gd`) entra num encaixe. As duas têm
vida, posição e arte — e ainda assim nenhuma linha de código é compartilhada.

**Só a peça altera atributo.** `Part` tem `modifiers` e `scalers`; `BoneDef` não tem
nenhum dos dois. Os números do robô vêm de `Chassis.base_stats` como bloco monolítico
(mk1: `agility 10, capacity 120, defense 4…`). O efeito prático: **arrancar o torso não
tira atributo nenhum**, só baixa a vida. O braço direito não *dá* força — a força é do
chassi inteiro.

**A compatibilidade está do lado errado.** Hoje quem decide é o anfitrião:
`SlotDef.mounts[].accepts == part.slot` (a anatomia lista o que aceita) e
`Chassis.restricted_tags` (o chassi recusa `HEAVY`). Para um jogo de muitas peças isso
inverte o trabalho: cada esqueleto novo teria que ser reescrito para conhecer as peças
que ainda não existem.

**`Part.Slot` é um enum fechado no código.** Sete valores em `part.gd:9-17`. Um tipo de
encaixe novo é mudança de GDScript — o único lugar do projeto onde acrescentar conteúdo
ainda exige recompilar.

E uma sexta, herdada: **`hp` total não descreve um robô que se desmonta.**
`combatant.gd:58` é `hp > 0` sobre a soma de todas as hitboxes. Arrancar a cabeça não
mata, arrancar as duas pernas não impede de atacar, e um robô desarmado continua lutando.

---

## 2. A ideia

Uma coisa monta na outra, **recursivamente**, e o convidado é quem declara onde cabe.

```
Esqueleto  "mk"                       ← fabricado; modelo e revisão
└── osso  arm_left                    ← vida própria; alvo quando exposto
    │                                   publica o socket MK-A1
    └── peça  mk1_arm_left            ← declara: encaixo em MK-A1
        │                               publica os sockets RAIL-1, MK-A1
        └── acoplamento  bracelete_plasma   ← declara: encaixo em RAIL-1
            └── acoplamento  mira_termica   ← e assim por diante, sem limite
```

Três regras sustentam o modelo inteiro:

1. **Tudo que está montado tem vida e atributos.** Osso, peça e acoplamento — a mesma
   mecânica nos três níveis. O que muda é só o conteúdo.
2. **O anfitrião publica, o convidado escolhe.** O osso não sabe o que aceita; ele expõe
   um socket. A peça é que diz em qual socket entra. Vale igual entre peça e acoplamento.
3. **Nada é obrigatório.** Jogar sem cabeça é escolha válida: fica mais leve, e o osso
   fica exposto.

---

## 3. O vocabulário

Era aqui que estava a confusão. Cada palavra passa a significar uma coisa só:

| Termo | O que é | Exemplos |
| --- | --- | --- |
| **Forma** | O desenho do corpo: que ossos existem, quem pendura em quem, e as animações. | humanoide, quadrúpede |
| **Esqueleto** | Um modelo fabricado de uma forma. É o fio condutor. | `mk`, `tk`, `mk3` |
| **Osso** | Segmento do esqueleto. Publica sockets; exposto, vira alvo. | `arm_left`, `torso` |
| **Peça** | Monta num socket de osso. | braço mk1, capacete submarino |
| **Acoplamento** | Monta num socket de peça. Mecanicamente **é uma peça**. | visão noturna, propulsor |
| **Kit** | Um lançamento: esqueleto + conjunto de peças de fábrica. | `mk1`, `mk2`, `mk1.5-submarino` |

Duas observações que evitam recaída:

**"Osso" não é mais o braço.** É a estrutura por baixo do braço. O braço é peça.

**"Acoplamento" é vocabulário, não classe.** No código é a mesma `Peça` — a distinção
existe só para conversar sobre conteúdo. É o que a recursão significa.

---

## 4. O socket

O encaixe é nomeado como socket de processador: **o padrão, nunca a posição**.

Um socket `LGA1700` não se chama "encaixe de cima da placa" — ele se chama pelo padrão
mecânico, e qualquer processador daquele padrão entra em qualquer placa que o publique.
Aqui é igual: o osso do braço esquerdo e o do direito publicam **o mesmo** `MK-A1`, e uma
peça `MK-A1` entra nos dois. É isso que faz as combinações explodirem — que é o objetivo.

| Padrão | Onde vive | O que entra |
| --- | --- | --- |
| `MK-A1` | ossos de membro do esqueleto `mk` | braços e pernas da família mk |
| `MK-B1` | osso do tronco do esqueleto `mk` | carcaças, mochilas |
| `MK-C1` | osso da cabeça do esqueleto `mk` | capacetes |
| `MK3-A1` | ossos de membro do esqueleto `mk3` | só peças mk3 |
| `RAIL-1` | publicado **por peças** | acessórios universais |

### Por que isso resolve o mk35 sozinho

O `mk35` publica `MK3-A1` nos ossos de membro. Uma peça da família mk declara
`fits: ["MK-A1"]`. Ela não encontra onde entrar — e **ninguém precisou recusá-la**. Some
a lista de exceções, some o `restricted_tags`, some o enum. A incompatibilidade vira
consequência do padrão, não uma regra escrita à mão.

### Dois tipos de padrão, e é de propósito

- **Proprietário** (`MK-A1`): amarrado à família do esqueleto. É o que dá identidade a um
  fabricante e o que torna a peça de outro modelo cobiçada.
- **Universal** (`RAIL-1`): o trilho de acessório. Publicado por peças de famílias
  diferentes, aceita o mesmo acessório em todas.

São dois botões de balanceamento na mão do designer: quanto do catálogo é exclusivo e
quanto é universal. A visão noturna do `mk1.5-submarino` serve no capacete do `mk2`
porque os dois publicam `RAIL-1`; o braço dele não serve no `mk35` porque o padrão do
socket é outro.

### O nome do padrão é contrato

`<FAMÍLIA>-<CLASSE><REVISÃO>` — família do esqueleto, classe de encaixe, revisão. Uma vez
publicado, **o nome não muda**: toda peça que declara `fits: ["MK-A1"]` depende dele.
Esqueleto novo que queira herdar o catálogo publica o padrão existente; esqueleto que
queira um catálogo próprio publica um padrão novo. É essa escolha — e não uma lista de
exceções — que decide o que conversa com o quê.

---

## 5. O modelo

Cinco recursos. Os três primeiros são a novidade; os dois últimos existem hoje e
sobrevivem quase intactos.

```gdscript
## Um ponto de encaixe. Vive num osso ou numa peça — é o que torna o modelo recursivo.
class_name SocketDef
## Identidade dentro do anfitrião: "main", "rail_1", "dorsal_2".
@export var key: String = ""
## O padrão mecânico: "MK-A1", "RAIL-1". A compatibilidade se resolve por aqui, e só.
@export var standard: String = ""
## Pose de quem entrar: onde a arte assenta, para onde ela aponta, em que profundidade.
@export var rest_position: Vector2
@export var art_offset: Vector2
@export var z_index: int
```

```gdscript
## Qualquer coisa montável: peça de membro, capacete, propulsor, mira. Uma classe só —
## "acoplamento" é como o conteúdo chama uma peça montada em outra peça.
class_name Part
@export var id: String = ""
## Os padrões em que esta peça entra. É a peça que decide, nunca o anfitrião.
@export var fits: Array[String] = []
## Onde ela deixa outras peças entrarem. Vazio = peça folha.
@export var sockets: Array[SocketDef] = []

## Atributos de desempenho: força, ataque, agilidade, defesa…
@export var modifiers: Dictionary[String, int] = {}
@export var scalers: Dictionary[String, float] = {}

@export var resistance: int = 6      ## vida própria
@export var weight: int = 8          ## consome carga do esqueleto
@export var grants_actions: Array[String] = []
```

```gdscript
## Um segmento do esqueleto. Tem vida e atributos como qualquer peça — o que muda é a
## natureza deles: o osso carrega, a peça desempenha.
class_name BoneDef
@export var key: String = ""
@export var parent: String = ""      ## pai de transformação e de cascata
## Atributos estruturais: carga e estrutura. Nunca força ou ataque.
@export var modifiers: Dictionary[String, int] = {}
@export var resistance: int = 20     ## a vida que fica exposta quando o socket esvazia
## Onde as peças entram neste osso.
@export var sockets: Array[SocketDef] = []
```

```gdscript
## Um esqueleto fabricado: uma forma, com números e padrões próprios.
class_name Skeleton
@export var id: String = "mk"
@export var form: Form               ## humanoide, quadrúpede
@export var bones: Array[BoneDef] = []
```

```gdscript
## Um lançamento: o esqueleto e as peças que vêm nele de fábrica. Não tem atributo
## próprio — os números saem do que está montado.
class_name Kit
@export var id: String = "mk1"
@export var skeleton: Skeleton
## Socket → peça, o mesmo formato da montagem que o jogador edita.
@export var factory_parts: Dictionary[String, Part] = {}
```

```gdscript
## O desenho do corpo, e o contrato contra o qual as animações são escritas. Não tem
## número nem socket: é a forma, não o produto.
class_name Form
@export var id: String = "humanoid"
## As chaves de osso que todo esqueleto desta forma tem que ter, e quem pendura em quem.
@export var bone_keys: Array[String] = []
@export var parents: Dictionary[String, String] = {}
## Escritas contra os caminhos de nó que saem das chaves acima.
@export var animations: AnimationLibrary
```

A divisão entre **Forma** e **Esqueleto** é onde mora o reúso: a forma diz *quais ossos
existem e como se encadeiam* — o contrato que as animações assumem; o esqueleto diz
*quanto cada osso aguenta, onde ele fica e que padrão publica*. `mk` e `tk`, ambos
humanoides, compartilham a biblioteca de animação e podem ter proporções e resistências
diferentes. Um quadrúpede é outra forma, com outras animações.

A regra que amarra os dois: **as chaves de osso do esqueleto têm que cobrir exatamente as
da forma.** Um osso a mais ou a menos e a animação passa a escrever em nó que não existe
— falha silenciosa, do tipo que só aparece em batalha.

### O endereço de uma peça montada

Com recursão, `Loadout.slots` deixa de ser encaixe → peça e passa a ser **caminho de
socket** → peça:

```
"arm_left/main"                    → mk1_arm_left
"arm_left/main/rail_1"             → bracelete_plasma
"arm_left/main/rail_1/rail_1"      → mira_termica
```

Chave achatada, e não árvore aninhada: serializa em `.tres` sem esforço, e a hierarquia
continua legível na própria chave.

---

## 6. Os atributos

**O osso carrega. A peça desempenha.**

| Camada | Atributos | Por quê |
| --- | --- | --- |
| Osso | carga, estrutura | O esqueleto é o que sustenta — quanto ele aguenta é a pergunta dele. |
| Peça | força, ataque, agilidade, defesa… | O desempenho é do que está montado. |

O `StatSchema`/`StatDef` de hoje continua valendo inteiro: atributo novo segue sendo um
`.tres`, não um refactor.

**`Chassis.base_stats` morre.** Os números do robô passam a ser a soma do que está
montado — ossos do esqueleto mais todas as peças, em qualquer profundidade. `mk1` não tem
ficha própria; ele é o esqueleto `mk` com um conjunto de peças instaladas.

**A carga deixa de ser um laço.** O
[feature_anatomy.md §10.3](feature_anatomy.md) registra o problema: se uma peça pode somar
carga, a capacidade passa a depender das peças que ela mesma limita. Com carga sendo
atributo **do osso**, a circularidade some por construção — o esqueleto oferece, as peças
consomem. A regra especial de `loadout.gd:236-242` pode ser apagada.

**Perder peça passa a custar atributo.** É a consequência mais importante do modelo:
arrancar o braço tira a força daquele braço. Desmontar o inimigo vira estratégia, não
só dano.

---

## 7. O dano

**Camadas.** O golpe acerta a peça de fora. O osso só é alvo quando o socket dele está
vazio — porque a peça saiu na montagem, ou porque foi destruída em batalha.

**A peça blinda.** Um golpe maior que a vida da peça a destrói e **para ali**: o
excedente não respinga no osso. Enquanto houver peça em pé, o osso está protegido. É o
que dá sentido a montar blindagem — e o que torna a decisão de jogar sem capacete uma
troca de verdade, e não só menos peso.

**Estouro.** A exceção à blindagem: se o dano de um golpe supera a vida da **pilha
inteira** — o osso mais tudo que está montado nele — a pilha cai de uma vez. É o golpe
catastrófico, o único que alcança o osso sem antes descascá-lo.

**Não existe HP total.** Cada peça tem a sua vida e é isso. `Body.total_hp()`,
`Body.max_total_hp()` e as propriedades `Combatant.hp`/`max_hp` que leem delas
(`combatant.gd:28-34`) deixam de descrever alguma coisa real: um robô com 80% de vida
distribuída em peças inúteis está pior do que um com 40% nas peças certas.

---

## 8. A derrota

Não existe peça-núcleo. **O robô luta até não conseguir mais lutar**: sem nenhuma ação
que alcance o inimigo à distância, e sem conseguir se deslocar para o corpo a corpo.

Isso é derrota **funcional**, e substitui o `hp > 0` de `combatant.gd:58`. As ações já
vêm das peças (`combatant.gd:66 available_actions()`), então a informação para decidir
isso já existe — falta escrever a regra.

---

## 9. O que muda no código

| Hoje | Vira |
| --- | --- |
| `BoneDef` | sobrevive, ganha `modifiers` e `sockets`, perde a ambiguidade de nome |
| `Part` | sobrevive, ganha `fits` e `sockets`, perde `slot` (o enum) |
| `SlotDef` + `MountDef` | viram `SocketDef` — some `accepts`, some `replaces_host` |
| `Part.Slot` (enum) | some; vira o `standard` do socket, que é dado |
| `Chassis` | vira `Kit`; `base_stats` e `bone_resistance` somem |
| `Chassis.restricted_tags` / `disabled_slots` | somem — o padrão do socket já resolve |
| `Anatomy` | vira `Form` (layout + hierarquia + animações) e `Skeleton` (modelo fabricado) |
| `Loadout.slots` | chaveado por caminho de socket, não por encaixe |
| `Body` / `BodyPart` | a árvore do que está montado; sem HP total |
| `Combatant.hp` / `is_alive()` | derrota funcional |
| `StatDef` / `StatSchema` | intactos |
| `Actions` | intacto |
| `CharacterArt` | intacto — ele já trata osso e peça igual |

### E a bagunça de `assets/` se resolve sozinha

Hoje `assets/source/characters/mk1/arm_left/` e `assets/source/parts/agile_leg/` guardam
exatamente a mesma coisa — o sprite de 8 direções de um pedaço de robô — separados só
porque o código tinha dois conceitos. Com um conceito só, some a separação: **peça é peça,
e a arte dela mora em um lugar só.** A confusão era sintoma do modelo, não desorganização
de pasta.

---

## 10. O que isso destrava

**Uma peça nova.** Um `.tres` com `fits: ["MK-A1"]`. Ela aparece em todo socket daquele
padrão, no braço esquerdo e no direito, em qualquer esqueleto da família — sem tocar em
código nem em nenhum esqueleto existente.

**Um esqueleto novo.** Publica os padrões que quiser reaproveitar. Publicou `MK-A1`,
herdou o catálogo inteiro da família mk. Publicou `TK-A1`, começa do zero — e isso é
escolha de design, não limitação.

**Um lançamento novo.** `mk1.5-submarino` é um `Kit`: mesmo esqueleto, peças novas. As
peças dele servem no `mk1` no dia em que forem publicadas.

**Acessório sobre acessório.** A mira que monta no canhão que monta no bracelete que monta
no antebraço. A recursão não tem caso especial.

**Jogar sem cabeça.** Já é válido pelo modelo: menos peso, menos atributo, osso exposto.

**Uma peça cobiçada.** O capacete do submarino no mk2, porque o padrão bate e o atributo
compensa. É a economia do jogo saindo do modelo de dados, e não de uma tabela de exceções.

---

## 11. O que falta definir

1. **Espelhamento.** Se o mesmo `MK-A1` está no braço esquerdo e no direito, a mesma arte
   serve nos dois lados espelhada. `robot_sprite.gd:421-423` já tem a mecânica para o caso
   de hoje; falta decidir se o espelho é do socket, da peça, ou de nenhum dos dois (arte
   dedicada por lado).

2. **Empate.** Se derrota é "não consegue mais lutar", dois robôs desarmados e imóveis
   empatam — por tempo, por rendição, ou a luta simplesmente não termina?

3. **Ordem de resolução dos atributos.** Hoje `loadout.gd:225-265` soma, depois multiplica,
   depois aplica piso. Com atributos vindo de ossos e de peças em profundidade arbitrária,
   falta decidir se a ordem é por camada (osso → peça → acoplamento) ou tudo achatado numa
   soma só.

A migração do conteúdo de hoje — as 11 peças e os 3 chassis de `content/catalog/` — está
resolvida no [plan_montagem.md](plan_montagem.md), que também fecha as decisões de
estrutura que este documento deixou implícitas.

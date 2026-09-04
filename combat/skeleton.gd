## Um esqueleto fabricado: uma forma, com números e padrões próprios.
##
## É o fio condutor entre lançamentos: `mk1`, `mk2` e `mk1.5-submarino` podem reaproveitar
## o mesmo esqueleto `mk` — mesma forma, mesmos ossos, mesmos padrões de socket — e por
## isso as peças de um servem nos outros.
##
## Ver Docs/feature_montagem.md §5.
@tool
class_name Skeleton
extends Resource

@export var id: String = "mk"
## Humanoide, quadrúpede — o contrato de ossos e animações que este esqueleto preenche.
@export var form: Form
@export var bones: Array[BoneDef] = []


## O osso de uma chave — RobotSprite usa para montar o pai de cada nó (Docs/plan_montagem.md,
## Fase 5). Mesmo molde de `Anatomy.bone()`.
func bone(key: String) -> BoneDef:
	for b in bones:
		if b.key == key:
			return b
	return null


## Os ossos em ordem de hierarquia (pai antes de filho) — é a ordem que a árvore de nós
## do RobotSprite precisa para poder criar cada nó já dentro do pai certo. Mesmo
## algoritmo de `Anatomy.bones_in_order()`.
func bones_in_order() -> Array[BoneDef]:
	var by_key := {}
	for b in bones:
		by_key[b.key] = b

	var result: Array[BoneDef] = []
	var visited := {}
	var visit: Callable
	visit = func(b: BoneDef, self_ref: Callable) -> void:
		if visited.has(b.key):
			return
		visited[b.key] = true
		if not b.parent.is_empty() and by_key.has(b.parent):
			self_ref.call(by_key[b.parent], self_ref)
		result.append(b)
	for b in bones:
		visit.call(b, visit)
	return result

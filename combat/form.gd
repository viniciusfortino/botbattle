## O desenho do corpo, e o contrato contra o qual as animações são escritas. Não tem
## número nem socket: é a forma, não o produto.
##
## `mk` e `tk`, ambos humanoides, compartilham esta mesma forma — e por isso a mesma
## biblioteca de animação — mesmo tendo esqueletos com proporções e resistências
## diferentes. Um quadrúpede é outra forma, com outras animações.
##
## Ver Docs/feature_montagem.md §5.
@tool
class_name Form
extends Resource

@export var id: String = "humanoid"
## As chaves de osso que todo esqueleto desta forma tem que ter. Um esqueleto com osso a
## mais ou a menos quebra a regra: a animação passa a escrever em nó que não existe.
@export var bone_keys: Array[String] = []
## Osso → osso pai, para a hierarquia de transformação e de cascata de dano.
@export var parents: Dictionary[String, String] = {}
## Animações de corpo, escritas contra os caminhos de nó que saem das chaves acima.
@export var animations: AnimationLibrary

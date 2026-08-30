extends Node2D

## 縦スクロールする背景。同じテクスチャを縦に2枚並べ、画面外に出たら
## 反対側へ送り直すことで、途切れなくスクロールし続けているように見せる。

@export var scroll_speed: float = 80.0

@onready var tiles: Array[Sprite2D] = [$Tile1, $Tile2]

var tile_height: float


func _ready() -> void:
	tile_height = tiles[0].texture.get_height() * tiles[0].scale.y


func _process(delta: float) -> void:
	for tile in tiles:
		tile.position.y += scroll_speed * delta
		if tile.position.y >= tile_height:
			tile.position.y -= tile_height * tiles.size()

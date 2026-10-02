extends SceneTree
## 부팅 화면 그림을 만들어 assets/ui/splash.png로 저장한다. project.godot의 application/boot_splash/image가 이 파일을 쓴다.
##
##   godot --headless --path . --script tools/make_splash.gd
##
## 용사와 동료 넷을 한 줄로 세운 그림이다. 원본은 assets/sprites/의 SVG이고 이 PNG는 손으로 고치지 않는다.
## 바탕은 투명이고 바탕색은 boot_splash/bg_color(테마의 BACKGROUND)가 칠한다.

const OUT_PATH := "res://assets/ui/splash.png"
const SPRITES: PackedStringArray = [
	"res://assets/sprites/cleric.svg",
	"res://assets/sprites/mage.svg",
	"res://assets/sprites/hero.svg",
	"res://assets/sprites/archer.svg",
	"res://assets/sprites/warrior.svg",
]
const HERO_INDEX: int = 2
const SPRITE_SCALE: float = 0.55   # 256px 캔버스 → 141px. 다섯이 720px 폭에 들어가게
const HERO_SCALE: float = 0.8      # 가운데 용사만 크게
const GAP: int = -16               # 캔버스 여백이 있어 조금 겹쳐 세운다
const SIZE := Vector2i(720, 300)


func _init() -> void:
	var canvas := Image.create_empty(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	var images: Array[Image] = []
	var total := 0
	for i in SPRITES.size():
		var image := Image.new()
		var text := FileAccess.get_file_as_string(SPRITES[i])
		image.load_svg_from_string(text, HERO_SCALE if i == HERO_INDEX else SPRITE_SCALE)
		image.convert(Image.FORMAT_RGBA8)
		images.append(image)
		total += image.get_width() + (GAP if i > 0 else 0)
	var x := (SIZE.x - total) / 2
	for image in images:
		var y := SIZE.y - image.get_height()  # 발끝을 아래 가장자리에 맞춘다
		canvas.blend_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), Vector2i(x, y))
		x += image.get_width() + GAP
	var err := canvas.save_png(OUT_PATH)
	print("splash ", OUT_PATH, " ", error_string(err))
	quit(0 if err == OK else 1)

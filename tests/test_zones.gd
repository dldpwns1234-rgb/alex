extends "res://tests/test_case.gd"
## 스테이지에 따른 몬스터 종류·색조·배경(Zones)과 전투 인물 연출(Actor)이 깨지지 않는지 본다.

const Zones := preload("res://scenes/battle/zones.gd")
const Actor := preload("res://scenes/battle/actor.gd")
const SlashFx := preload("res://scenes/battle/slash_fx.gd")


func run() -> void:
	_zones()
	await _actor()


func _zones() -> void:
	_equal(Zones.zone(1), 0, "1스테이지는 첫 몬스터")
	_equal(Zones.zone(10), 0, "10스테이지(보스)까지 같은 몬스터")
	_equal(Zones.zone(11), 1, "11스테이지부터 다음 몬스터")
	_equal(Zones.zone(60), 5, "60스테이지는 여섯째 몬스터")
	_equal(Zones.zone(61), 0, "61스테이지에서 처음으로 돌아온다")
	_equal(Zones.lap(60), 0, "첫 바퀴")
	_equal(Zones.lap(61), 1, "둘째 바퀴")
	_equal(Zones.lap(121), 2, "셋째 바퀴")
	_equal(Zones.monster_name(5, true), "슬라임 두목", "보스 이름")
	_equal(Zones.monster_name(37, false), "해골", "일반 몬스터 이름")
	_equal(Zones.monster_tint(1), Color.WHITE, "첫 바퀴는 원래 색")
	_equal(Zones.monster_tint(61) != Color.WHITE, true, "둘째 바퀴는 색이 다르다")
	_equal(Zones.monster_tint(61) == Zones.monster_tint(70), true, "같은 바퀴는 같은 색")
	_equal(Zones.MONSTER_TEXTURES.size(), Zones.MONSTER_NAMES.size(), "몬스터마다 그림")
	_equal(Zones.HEAD_TOPS.size(), Zones.MONSTER_NAMES.size(), "몬스터마다 왕관 자리")
	_equal(Zones.PALETTES.size(), Zones.MONSTER_NAMES.size(), "몬스터마다 배경")
	for stage: int in [1, 11, 21, 31, 41, 51]:
		_equal(Zones.monster_texture(stage) != null, true, "%d스테이지 그림이 있다" % stage)
		_equal(Zones.palette(stage).size(), 4, "%d스테이지 배경 색 4개" % stage)
		_equal(Zones.head_top(stage) > 0.0 and Zones.head_top(stage) < 1.0, true, "%d스테이지 왕관 자리" % stage)


## 연출 함수들을 차례로 불러도 오류 없이 프레임이 흐르는지 본다
func _actor() -> void:
	var actor := Actor.new(Zones.monster_texture(1), Vector2(100, 100), false)
	add_child(actor)
	actor.spawn()
	actor.attack()
	actor.strike()
	actor.hit(true)
	actor.hit(true, 1.8)
	actor.hit(false)
	actor.set_overlay(Zones.monster_texture(2), Vector2(40, 20), Vector2.ZERO)
	actor.set_overlay(null, Vector2(40, 20), Vector2.ZERO)
	actor.set_locked(true)
	actor.set_locked(false)
	actor.die(0.05)
	await get_tree().process_frame
	await get_tree().process_frame
	actor.vanish(0.05)
	actor.spawn()
	await get_tree().process_frame
	_equal(actor.pop > 0.0, true, "등장 연출 배율은 양수")
	actor.queue_free()
	for downward: bool in [true, false]:
		var slash := SlashFx.new(Vector2(50, 50), downward, not downward)
		add_child(slash)
		_equal(slash.material != null, true, "베기 자국은 훑기 셰이더를 쓴다")
	await get_tree().process_frame
	await get_tree().process_frame
	passed += 1

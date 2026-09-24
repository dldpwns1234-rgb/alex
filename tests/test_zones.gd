extends "res://tests/test_case.gd"
## 스테이지에 따른 몬스터 종류·색조·배경(Zones)과 전투 인물 연출(Actor)이 깨지지 않는지 본다.

const Zones := preload("res://scenes/battle/zones.gd")
const Actor := preload("res://scenes/battle/actor.gd")
const Stage := preload("res://scenes/battle/stage.gd")


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
		_equal(Zones.palette(stage).size(), 5, "%d스테이지 배경 색 5개" % stage)
		_equal(Zones.head_top(stage) > 0.0 and Zones.head_top(stage) < 1.0, true, "%d스테이지 왕관 자리" % stage)


	# 마왕성 (GDD 7.8절): 600부터 몬스터 3종이 10 스테이지마다 바뀌고, 1000의 배수는 마왕
	var castle: int = Balance.CASTLE_STAGE
	_equal(Zones.is_castle(castle - 1), false, "599는 아직 마왕성이 아니다")
	_equal(Zones.is_castle(castle), true, "600부터 마왕성")
	_equal(Zones.castle_zone(castle), 0, "600은 첫 마왕성 몬스터")
	_equal(Zones.castle_zone(castle + 10), 1, "610은 둘째")
	_equal(Zones.castle_zone(castle + 30), 0, "셋을 돌면 처음으로")
	_equal(Zones.castle_lap(castle + 30), 1, "둘째 바퀴")
	_equal(Zones.monster_name(castle, false), "임프", "마왕성 첫 몬스터")
	_equal(Zones.monster_name(castle + 25, true), "흑기사 두목", "마왕성 보스 이름")
	_equal(Zones.monster_name(1000, true), "마왕", "마왕은 두목을 붙이지 않는다")
	_equal(Zones.is_demon_king(2000), true, "2000도 마왕")
	_equal(Zones.is_demon_king(1500), false, "1500은 보통 보스")
	_equal(Zones.monster_texture(1000) == Zones.DEMON_KING_TEXTURE, true, "마왕 그림")
	_equal(Zones.monster_texture(castle) == Zones.CASTLE_TEXTURES[0], true, "임프 그림")
	_equal(Zones.monster_tint(castle), Color.WHITE, "마왕성 첫 바퀴는 원래 색")
	_equal(Zones.monster_tint(castle + 30) != Color.WHITE, true, "둘째 바퀴는 색이 다르다")
	_equal(Zones.monster_tint(1000), Color.WHITE, "마왕은 원래 색")
	_equal(Zones.palette(castle) == Zones.CASTLE_PALETTE, true, "마왕성 팔레트")
	_equal(Zones.palette(castle).size(), 5, "마왕성 배경 색 5개")
	_equal(Zones.head_top(castle + 20) > 0.0, true, "흑기사 왕관 자리")
	_equal(Zones.CASTLE_TEXTURES.size(), Zones.CASTLE_NAMES.size(), "마왕성 몬스터마다 그림")
	_equal(Zones.CASTLE_HEAD_TOPS.size(), Zones.CASTLE_NAMES.size(), "마왕성 몬스터마다 왕관 자리")


## 연출 함수들을 차례로 불러도 오류 없이 프레임이 흐르는지 본다
func _actor() -> void:
	var actor := Actor.new(Zones.monster_texture(1), Vector2(100, 100), false)
	add_child(actor)
	actor.spawn()
	actor.attack()
	actor.strike()
	actor.swing(1.0)
	actor.hit(true)
	actor.hit(true, 1.8)
	actor.hit(true, 1.0, true)
	actor.hit(false)
	_equal(actor.sprite() != null, true, "그림 노드를 내준다")
	actor.set_locked(true)
	actor.set_locked(false)
	actor.die(0.05)
	await get_tree().process_frame
	await get_tree().process_frame
	actor.die(0.05, false)
	actor.spawn()
	await get_tree().process_frame
	_equal(actor.pop > 0.0, true, "등장 연출 배율은 양수")
	actor.queue_free()
	var stage := Stage.new()
	add_child(stage)
	stage.slash(Vector2(100, 100), true, false, false)
	stage.slash(Vector2(100, 100), false, true, true)
	stage.impact(Vector2(200, 100), true, false)
	stage.impact(Vector2(200, 100), false, true)
	stage.shake(8.0)
	_equal(stage.get_child_count(), 4, "궤적 둘과 섬광 둘이 무대에 붙는다")
	await get_tree().create_timer(0.6).timeout  # 가장 긴 연출(처치 고리 0.3초)보다 길게
	await get_tree().process_frame  # queue_free가 실제로 지워지도록 한 프레임
	_equal(stage.get_child_count(), 0, "연출이 끝나면 스스로 사라진다")
	for i in Stage.MAX_FX + 3:  # 사라진 연출의 참조가 남아 있어도, 상한을 넘어도 문제없이 붙는다
		stage.impact(Vector2(200, 100), false, false)
	await get_tree().process_frame  # 상한 때문에 지운 것들이 실제로 사라지도록
	_equal(stage.get_child_count(), Stage.MAX_FX, "동시에 남는 연출은 상한까지")
	stage.queue_free()
	passed += 1

extends "res://autoload/abyss/run.gd"
## Abyss 2부: 심연석과 심연 각인(상점), 그리고 별도 모드의 틀(dungeon.gd)에 답하는 조회 (GDD 7.13절).
## 입장·층·보상·저장은 abyss.gd에 있다 (이 스크립트를 상속한다). 바깥에서는 Abyss.만 쓴다.

signal stones_changed(stones: float)
signal mark_changed(index: int, level: int)

var stones: float = 0.0        # 심연석
var marks: Array[int] = []     # 심연 각인 레벨 (Balance.Mark 순서). 폭풍 베기 둘은 Skills가 본편에서도 묻는다


func time_limit() -> float:
	return Balance.abyss_time_limit(level(Balance.Mark.TIME), time_blessings, curses.has(Balance.Curse.SHORT))


# 별도 모드의 틀 (dungeon.gd)

func mode_name() -> String:
	return "심연"


func monster_hp() -> float:
	return Balance.abyss_monster_hp(base_damage, floor, level(Balance.Mark.POWER), curses.has(Balance.Curse.TOUGH), is_boss_floor())


func visual_stage() -> int:
	return Balance.abyss_visual_stage(floor)


func kills_needed() -> int:
	return 1 if is_boss_floor() else Balance.ABYSS_MONSTERS


func is_boss_floor() -> bool:
	return Balance.abyss_is_boss_floor(floor)


func paused() -> bool:
	return not offers.is_empty()


# 심연 각인

func level(index: int) -> int:
	return marks[index] if index < marks.size() else 0


func is_maxed(index: int) -> bool:
	var cap := Balance.mark_max_level(index)
	return cap > 0 and marks[index] >= cap


func mark_cost(index: int) -> float:
	return Balance.mark_cost(index, marks[index])


func can_buy(index: int) -> bool:
	return not is_maxed(index) and stones >= mark_cost(index)


func buy(index: int) -> bool:
	if not can_buy(index):
		return false
	stones -= mark_cost(index)
	marks[index] += 1
	stones_changed.emit(stones)
	mark_changed.emit(index, marks[index])
	return true


func _cap(index: int) -> int:
	var cap := Balance.mark_max_level(index)
	return cap if cap > 0 else 1000000

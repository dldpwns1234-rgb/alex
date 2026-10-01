extends "res://tests/test_case.gd"
## 연쇄 처치 (GDD 3절): 넘친 피해로 같은 스테이지의 다음 몬스터를 연달아 잡는다. 스테이지를 넘지 않고, 보스는 없고, 처치 수·골드·통계에 든다

var _chains: Array[Array] = []  # chain_killed로 받은 [count, reward]


func run() -> void:
	_fresh_run()
	Game.chain_killed.connect(_on_chain_killed)
	var hp := Game.monster_max_hp  # 1스테이지 10
	var per_kill := Balance.kill_gold(hp) * Game.gold_multiplier()
	var kills_before := Achievements.value(Balance.Stat.KILLS)
	Game._damage_monster(hp * 3.5)
	_equal(Game.kills, 3, "체력 3.5배 피해: 한 마리 + 연쇄 두 마리 (반 마리는 버린다)")
	_close(Game.gold, per_kill * 3.0, "세 마리 골드")
	_equal(_chains.size(), 1, "연쇄 알림 한 번")
	_equal(_chains.back()[0], 2, "연쇄 두 마리")
	_close(_chains.back()[1], per_kill * 2.0, "연쇄 두 마리의 골드")
	_equal(Game.is_monster_alive(), false, "재등장 대기는 한 번")
	_equal(Game.stage, 1, "스테이지 그대로")
	_advance(Game.respawn_delay() + 0.01)
	_equal(Game.is_monster_alive(), true, "다음 몬스터 등장")
	_equal(Game.kills, 3, "처치 수 이어진다")
	Game._damage_monster(hp * 100.0)
	_equal(Game.stage, 2, "남은 일곱 마리를 연쇄로 잡고 다음 스테이지로")
	_equal(Game.kills, 0, "처치 수 0")
	_equal(_chains.back()[0], 6, "연쇄 여섯 마리 (넘친 피해는 스테이지를 넘지 않는다)")
	_close(Achievements.value(Balance.Stat.KILLS) - kills_before, 10.0, "통계에 열 마리")
	_close(Game.gold, per_kill * 10.0, "열 마리 골드")
	_advance(Game.respawn_delay() + 0.01)
	_equal(Game.is_monster_alive(), true, "2스테이지 몬스터 등장")
	_equal(Game.monster_hp > hp, true, "2스테이지 체력")

	Game.stage = 5
	Game.highest_stage = 5
	Game.kills = 0
	Game._spawn_monster()
	var chains_before := _chains.size()
	Game._damage_monster(Game.monster_max_hp * 1000.0)
	_equal(Game.stage, 6, "보스를 잡고 다음 스테이지")
	_equal(_chains.size(), chains_before, "보스는 연쇄가 없다")
	_equal(Game.kills, 0, "보스 뒤 처치 수 0")
	Game.chain_killed.disconnect(_on_chain_killed)
	_fresh_run()


func _on_chain_killed(count: int, reward: float) -> void:
	_chains.append([count, reward])

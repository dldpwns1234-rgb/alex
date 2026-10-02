extends Node
## 별도 모드(시련의 탑, 심연)의 공통 틀. Game은 별도 모드 안(in_tower)이면 들어온 모드(Game.dungeon)의 이 함수들만 부른다:
## 층 제한 시간(tick), 몬스터 체력, 그림 스테이지, 층을 넘기는 처치 수, 두목 층인지, 멈춤(심연의 축복 고르기), 층 돌파.
## 탑(tower.gd)과 심연(abyss.gd)이 상속해 채운다. 상태 변경은 각 오토로드의 함수로만 하고 UI는 표시만 한다.

signal timer_changed(seconds_left: float)

var floor: int = 0         # 도전 중인 층. 모드 밖에서는 0
var time_left: float = 0.0


## 상단 바와 알림에 붙이는 짧은 이름 ("탑 12층")
func mode_name() -> String:
	return ""


func monster_hp() -> float:
	return 1.0


## 그림과 배경에 쓰는 스테이지
func visual_stage() -> int:
	return 1


## 이 층을 넘기는 처치 수
func kills_needed() -> int:
	return Balance.MONSTERS_PER_STAGE


func is_boss_floor() -> bool:
	return false


## 참이면 Game이 이 프레임의 전투와 제한 시간을 멈춘다
func paused() -> bool:
	return false


## 제한 시간. Game이 모드 안에서 매 프레임 부른다
func tick(dt: float) -> void:
	time_left -= dt
	timer_changed.emit(maxf(time_left, 0.0))
	if time_left <= 0.0:
		fail()


func fail() -> void:
	pass


## 이 층의 몬스터를 다 잡았다 (Game이 부른다)
func clear_floor() -> void:
	pass

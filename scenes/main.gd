extends Control
## 세로 화면 전체 (GDD 9절). 상단 바, 전투 화면, 스킬 바, 구매 배수, 탭 내비게이션과 패널을 위에서부터 쌓는다.
## 내비게이션이 고른 패널만 보이고, 강화할 수 있는 장비가 있으면 용사 탭에, 승급할 수 있는 동료가 있으면 동료 탭에,
## 살 수 있는 단련이 있으면 단련 탭에, 아직 안 본 업적 달성이 있으면 업적 탭에 점을 찍는다.
## 업적 달성, 승급, 장비 획득, 환생은 전투 화면 아래에 알림을 띄운다. 마왕을 처음 잡으면 엔딩 창을 띄운다 (GDD 7.8절).

const Toast := preload("res://scenes/toast.gd")

const HERO_TAB: int = 0
const PARTY_TAB: int = 1
const TRAINING_TAB: int = 2
const ACHIEVEMENTS_TAB: int = 4
const OFFLINE_POPUP_SIZE := Vector2i(600, 320)
const ENDING_POPUP_SIZE := Vector2i(600, 420)

@onready var _nav: HBoxContainer = $Layout/Nav
@onready var _panels: MarginContainer = $Layout/Panels
@onready var _battle: Control = $Layout/Battle

var _offline_dialog: AcceptDialog
var _ending_dialog: AcceptDialog
var _toast: Toast


func _ready() -> void:
	_offline_dialog = AcceptDialog.new()
	_offline_dialog.title = "오프라인 보상"
	_offline_dialog.ok_button_text = "확인"
	add_child(_offline_dialog)
	_ending_dialog = AcceptDialog.new()
	_ending_dialog.title = "마왕 토벌"
	_ending_dialog.ok_button_text = "계속하기"
	_ending_dialog.dialog_autowrap = true
	add_child(_ending_dialog)
	_toast = Toast.new()
	_battle.add_child(_toast)
	Game.demon_king_defeated.connect(_on_demon_king_defeated)
	Challenges.completed.connect(_on_challenge_completed)
	Tower.floor_cleared.connect(_on_floor_cleared)
	Tower.failed.connect(_on_tower_failed)
	Save.offline_reward.connect(_on_offline_reward)
	_nav.tab_selected.connect(_show_panel)
	_nav.select(0)
	Game.gold_changed.connect(_refresh_badges.unbind(1))
	Training.training_changed.connect(_refresh_badges.unbind(2))
	Party.hero_changed.connect(_refresh_badges.unbind(1))
	Party.companion_changed.connect(_refresh_badges.unbind(2))
	Promotions.promotion_changed.connect(_refresh_badges.unbind(2))
	Promotions.promoted.connect(_on_promoted)
	Equipment.equipment_changed.connect(_refresh_badges.unbind(1))
	Equipment.stones_changed.connect(_refresh_badges.unbind(1))
	Equipment.item_dropped.connect(_on_item_dropped)
	Rebirth.reborn.connect(_on_reborn)
	Achievements.unlocked.connect(_on_achievement_unlocked)
	Achievements.seen_changed.connect(_refresh_achievement_badge)
	_refresh_badges()
	_refresh_achievement_badge()


func _show_panel(index: int) -> void:
	for i in _panels.get_child_count():
		(_panels.get_child(i) as Control).visible = i == index


## 골드, 레벨, 강화석이 바뀔 때마다: 강화할 수 있는 장비, 승급할 수 있는 동료, 살 수 있는 단련
func _refresh_badges() -> void:
	_nav.set_badge(HERO_TAB, Equipment.any_enhanceable())
	_nav.set_badge(PARTY_TAB, Promotions.any_affordable())
	_nav.set_badge(TRAINING_TAB, Training.any_affordable())


func _refresh_achievement_badge() -> void:
	_nav.set_badge(ACHIEVEMENTS_TAB, Achievements.has_unseen())


func _on_achievement_unlocked(index: int) -> void:
	_toast.show_message("업적 달성 · %s" % Balance.achievement_name(index))
	_refresh_achievement_badge()


func _on_promoted(index: int, rank: int) -> void:
	_toast.show_message("%s 승급 · %s" % [Balance.companion_name(index), Balance.promotion_stars(rank)])


## 장비 알림: 등급 색으로 이름을 보이고, 장착했는지 분해했는지 적는다
func _on_item_dropped(slot: int, grade: int, _stage: int, equipped: bool) -> void:
	var outcome := "장착" if equipped else "분해 · 강화석 +%s" % Num.format(Balance.dismantle_stones(grade))
	_toast.show_message("%s 획득 · %s" % [Balance.item_name(slot, grade), outcome], Balance.grade_color(grade))


## 돌아오면 비운 시간과 받은 골드를 먼저 보여준다 (GDD 8·9절). 동료가 없어 받을 게 없으면 띄우지 않는다
func _on_offline_reward(seconds: float, gold: float) -> void:
	if gold <= 0.0:
		return
	_offline_dialog.dialog_text = "자리를 비운 %s 동안\n동료들이 골드 %s을 모았습니다" % [
		Num.format_duration(seconds), Num.format(gold)]
	_offline_dialog.popup_centered(OFFLINE_POPUP_SIZE)


func _on_reborn(reward: float) -> void:
	var opened := " · 도전 판이 열렸다" if Rebirth.rebirth_count == Balance.CHALLENGE_UNLOCK_REBIRTHS else ""
	_toast.show_message("환생 · 운명의 실 +%s%s" % [Num.format(reward), opened])


func _on_challenge_completed(index: int) -> void:
	_toast.show_message("도전 달성 · %s" % Balance.challenge_name(index))


## 탑: 첫 돌파면 보상을, 다시 오른 층이면 돌파만 알린다
func _on_floor_cleared(floor: int, stones: float, threads: float) -> void:
	var reward := ""
	if stones > 0.0:
		reward += " · 강화석 +%s" % Num.format(stones)
	if threads > 0.0:
		reward += " · 운명의 실 +%s" % Num.format(threads)
	_toast.show_message("시련의 탑 %d층 돌파%s" % [floor, reward])


func _on_tower_failed(floor: int) -> void:
	_toast.show_message("시련의 탑 %d층 실패" % floor)


## 마왕을 처음 잡았을 때만 엔딩: 기록을 보이고 무한 모드로 이어진다 (통계는 Achievements가 먼저 올린다)
func _on_demon_king_defeated() -> void:
	if Achievements.value(Balance.Stat.DEMON_KING) > 1.0:
		_toast.show_message("마왕 토벌 · %s번째" % Num.format(Achievements.value(Balance.Stat.DEMON_KING)))
		return
	_ending_dialog.dialog_text = "마왕을 쓰러뜨렸다.\n\n회귀 %s회 · 환생 %s회 · 처치 %s마리 · 탭 %s번\n\n그러나 마왕성 너머의 어둠은 끝이 없다.\n스테이지는 계속되고, 마왕은 %s마다 다시 나타난다." % [
		Num.format(Achievements.value(Balance.Stat.PRESTIGES)), Num.format(Achievements.value(Balance.Stat.REBIRTHS)),
		Num.format(Achievements.value(Balance.Stat.KILLS)), Num.format(Achievements.value(Balance.Stat.TAPS)),
		Num.format(Balance.DEMON_KING_INTERVAL)]
	_ending_dialog.popup_centered(ENDING_POPUP_SIZE)

extends Control
## 세로 화면 전체 (GDD 9절). 상단 바, 전투 화면, 그리고 하단 메뉴 시트(스킬 바, 구매 배수, 탭 내비게이션, 패널)를 위에서부터 쌓는다.
## 시트(sheet.gd)는 접힌 높이만큼 Layout에 자리를 두고(SheetSpace), 펼치면 전투 화면 위로 올라온다. 알림은 시트 바로 위에 뜬다.
## 내비게이션이 고른 패널만 보이고, 강화할 수 있는 장비가 있으면 용사 탭에, 승급할 수 있는 동료가 있으면 동료 탭에,
## 살 수 있는 단련이 있으면 단련 탭에, 아직 안 본 업적 달성이 있으면 업적 탭에 점을 찍는다.
## 업적 달성, 승급, 장비 획득, 환생, 보물 요정 보상은 전투 화면 아래에 알림을 띄운다. 보물 요정은 전투 화면 맨 위에 얹는다. 마왕을 처음 잡으면 엔딩 창을 띄운다 (GDD 7.8절).

const Toast := preload("res://scenes/toast.gd")
const TreasureView := preload("res://scenes/battle/treasure_view.gd")

const HERO_TAB: int = 0
const PARTY_TAB: int = 1
const TRAINING_TAB: int = 2
const PRESTIGE_TAB: int = 3
const ACHIEVEMENTS_TAB: int = 4
const OFFLINE_POPUP_SIZE := Vector2i(600, 320)
const ENDING_POPUP_SIZE := Vector2i(600, 420)
const TREASURE_TOAST_COLOR := Color("ffd23f")  # 보물 요정 보상 알림 (요정 그림의 금빛)

@onready var _top_bar: Control = $Layout/TopBar
@onready var _sheet_space: Control = $Layout/SheetSpace
@onready var _sheet: PanelContainer = $Sheet
@onready var _nav: HBoxContainer = $Sheet/Column/Nav
@onready var _panels: MarginContainer = $Sheet/Column/Panels

var _offline_dialog: AcceptDialog
var _ending_dialog: AcceptDialog
var _toast: Toast


func _ready() -> void:
	$Layout/Battle.add_child(TreasureView.new())  # 전투 화면의 다른 그림보다 위에 (탭을 먼저 받는다)
	Treasure.caught.connect(_on_treasure_caught)
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
	add_child(_toast)  # 시트보다 뒤에 더해 펼친 시트 위에도 그려진다
	_sheet_space.custom_minimum_size = Vector2(0.0, _sheet.collapsed_height())
	_sheet.height_changed.connect(_on_sheet_height_changed)
	_sheet.set_top_inset(_top_bar.get_combined_minimum_size().y)
	_toast.top_inset = _top_bar.get_combined_minimum_size().y
	_on_sheet_height_changed(_sheet.current_height())
	Game.demon_king_defeated.connect(_on_demon_king_defeated)
	Challenges.completed.connect(_on_challenge_completed)
	Trials.completed.connect(func(index: int, tier: int) -> void: _toast.show_message("별자리 시련 · %s %d단계" % [Balance.trial_name(index), tier]))
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
	Prestige.crystals_changed.connect(_refresh_badges.unbind(1))
	Game.stage_changed.connect(_on_stage_changed)
	Equipment.item_dropped.connect(_on_item_received.bind("획득"))
	Equipment.item_crafted.connect(_on_item_received.bind("제작"))
	Rebirth.reborn.connect(_on_reborn)
	Transcend.transcended.connect(func(reward: float) -> void: _toast.show_message("초월 · 별의 파편 +%s" % Num.format(reward)))
	Achievements.unlocked.connect(_on_achievement_unlocked)
	Achievements.seen_changed.connect(_refresh_achievement_badge)
	_refresh_badges()
	_refresh_achievement_badge()


## 시트가 늘고 줄면 알림 자리도 따라간다 (시트 바로 위)
func _on_sheet_height_changed(height: float) -> void:
	_toast.bottom_inset = height


func _show_panel(index: int) -> void:
	for i in _panels.get_child_count():
		(_panels.get_child(i) as Control).visible = i == index


## 골드, 레벨, 강화석, 결정이 바뀔 때마다: 강화할 수 있는 장비, 고용·승급할 수 있는 동료, 살 수 있는 단련,
## 회귀 탭은 처음 회귀할 수 있게 됐을 때와 기억의 상점에서 살 것이 있을 때 (첫 경험 안내, 2026-10-02)
func _refresh_badges() -> void:
	_nav.set_badge(HERO_TAB, Equipment.any_enhanceable())
	_nav.set_badge(PARTY_TAB, Promotions.any_affordable() or _any_hire_affordable())
	_nav.set_badge(TRAINING_TAB, Training.any_affordable())
	var first_prestige := Prestige.can_prestige() and Prestige.prestige_count == 0 and Rebirth.rebirth_count == 0
	_nav.set_badge(PRESTIGE_TAB, first_prestige or Prestige.any_affordable())


func _any_hire_affordable() -> bool:
	for i in Balance.COMPANIONS.size():
		if Party.is_companion_unlocked(i) and not Party.is_companion_hired(i) and Party.companion_purchase(i).affordable:
			return true
	return false


## 처음으로 회귀 조건에 닿으면 한 번 알린다. 회귀 버튼이 탭 안에 있어 모르고 지나치기 쉽다
func _on_stage_changed(_stage: int) -> void:
	if Game.highest_stage == Balance.PRESTIGE_MIN_STAGE and Prestige.prestige_count == 0 and Rebirth.rebirth_count == 0:
		_toast.show_message("회귀가 열렸다 · 회귀 탭에서 기억을 가져오자")
	_refresh_badges()


func _refresh_achievement_badge() -> void:
	_nav.set_badge(ACHIEVEMENTS_TAB, Achievements.has_unseen())


func _on_achievement_unlocked(index: int) -> void:
	_toast.show_message("업적 달성 · %s" % Balance.achievement_name(index))
	_refresh_achievement_badge()


func _on_promoted(index: int, rank: int) -> void:
	_toast.show_message("%s 승급 · %s" % [Balance.companion_name(index), Balance.promotion_stars(rank)])


## 장비 알림: 등급 색으로 이름을 보이고, 획득(드롭)인지 제작인지, 장착했는지 분해했는지 적는다
func _on_item_received(slot: int, grade: int, _stage: int, equipped: bool, verb: String) -> void:
	var outcome := "장착" if equipped else "분해 · 강화석 +%s" % Num.format(Balance.dismantle_stones(grade) * Challenges.stone_multiplier())
	_toast.show_message("%s %s · %s" % [Balance.item_name(slot, grade), verb, outcome], Balance.grade_color(grade))


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


func _on_treasure_caught(reward: Treasure.Reward, amount: float) -> void:
	match reward:
		Treasure.Reward.GOLD:
			_toast.show_message("보물 요정 · 골드 +%s" % Num.format(amount), TREASURE_TOAST_COLOR)
		Treasure.Reward.COOLDOWN:
			_toast.show_message("보물 요정 · 스킬 쿨타임 초기화", TREASURE_TOAST_COLOR)
		Treasure.Reward.BLESSING:
			_toast.show_message("보물 요정 · %d초 동안 처치 골드 ×%s" % [roundi(amount), Num.format(Balance.TREASURE_BLESSING_MULTIPLIER)], TREASURE_TOAST_COLOR)


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


## 마왕을 처음 잡았을 때만 엔딩: 기록을 보이고 무한 모드로 이어진다 (통계는 Achievements가 먼저 올린다). 최종 스테이지의 마왕은 진정한 엔딩
func _on_demon_king_defeated() -> void:
	if Game.stage >= Balance.FINAL_STAGE:
		_on_final_boss_defeated()
		return
	if Achievements.value(Balance.Stat.DEMON_KING) > 1.0:
		_toast.show_message("마왕 토벌 · %s번째" % Num.format(Achievements.value(Balance.Stat.DEMON_KING)))
		return
	_ending_dialog.dialog_text = "마왕을 쓰러뜨렸다.\n\n회귀 %s회 · 환생 %s회 · 처치 %s마리 · 탭 %s번\n\n그러나 마왕성 너머의 어둠은 끝이 없다.\n스테이지는 계속되고, 마왕은 %s마다 다시 나타난다." % [
		Num.format(Achievements.value(Balance.Stat.PRESTIGES)), Num.format(Achievements.value(Balance.Stat.REBIRTHS)),
		Num.format(Achievements.value(Balance.Stat.KILLS)), Num.format(Achievements.value(Balance.Stat.TAPS)),
		Num.format(Balance.DEMON_KING_INTERVAL)]
	_ending_dialog.popup_centered(ENDING_POPUP_SIZE)


## 최종 스테이지(마왕성 최심부)의 마왕: 처음이면 진정한 엔딩 창, 그 뒤로는 알림. 더 나아갈 곳이 없어 회귀·환생으로만 이어진다 (GDD 7.8절)
func _on_final_boss_defeated() -> void:
	if Achievements.value(Balance.Stat.FINAL) > 1.0:
		_toast.show_message("어둠의 끝 · %s번째" % Num.format(Achievements.value(Balance.Stat.FINAL)))
		return
	_ending_dialog.dialog_text = "마왕성 최심부, 스테이지 %d의 마왕을 쓰러뜨렸다.\n\n회귀 %s회 · 환생 %s회 · 처치 %s마리 · 탭 %s번\n\n어둠의 근원은 사라졌고 이 세계에 더 나아갈 곳은 없다.\n회귀와 환생으로 새 삶을 시작할 수 있다. 기록은 남는다." % [
		Balance.FINAL_STAGE,
		Num.format(Achievements.value(Balance.Stat.PRESTIGES)), Num.format(Achievements.value(Balance.Stat.REBIRTHS)),
		Num.format(Achievements.value(Balance.Stat.KILLS)), Num.format(Achievements.value(Balance.Stat.TAPS))]
	_ending_dialog.popup_centered(ENDING_POPUP_SIZE)

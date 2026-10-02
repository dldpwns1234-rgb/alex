extends RefCounted
## Save 3부: 저장 데이터의 절(오토로드)과 불러오기·초기화 순서. 새 오토로드를 저장에 넣으면 세 곳을 함께 고친다.
## 순서에 뜻이 있다: 도전 판을 맨 앞에(가져온 스테이지를 지금 세션의 도전으로 판정하지 않게), 초월은 승급(상한)보다 앞에,
## 업적은 회귀 기록(Prestige) 뒤·통계를 시그널로 받는 Party·Game 앞에, 기억 조각은 업적 뒤에


static func to_dict() -> Dictionary:
	return {
		"game": Game.to_dict(),
		"rebirth": Rebirth.to_dict(),
		"party": Party.to_dict(),
		"skills": Skills.to_dict(),
		"training": Training.to_dict(),
		"promotions": Promotions.to_dict(),
		"prestige": Prestige.to_dict(),
		"achievements": Achievements.to_dict(),
		"equipment": Equipment.to_dict(),
		"automation": Automation.to_dict(),
		"challenges": Challenges.to_dict(),
		"tower": Tower.to_dict(),
		"treasure": Treasure.to_dict(),
		"fragments": Fragments.to_dict(),
		"transcend": Transcend.to_dict(),
		"prefs": Prefs.to_dict(),
	}


static func from_dict(data: Dictionary) -> void:
	Challenges.from_dict(_section(data, "challenges"))  # 맨 앞: 지금 세션의 도전으로 가져온 스테이지를 달성 판정하지 않게
	Transcend.from_dict(_section(data, "transcend"))  # 승급 상한(동료 각성)과 환생 조건(지름길)이 묻는다
	Rebirth.from_dict(_section(data, "rebirth"))
	Prestige.from_dict(_section(data, "prestige"))
	Achievements.from_dict(_section(data, "achievements"))
	Party.from_dict(_section(data, "party"))
	Promotions.from_dict(_section(data, "promotions"))
	Equipment.from_dict(_section(data, "equipment"))
	Skills.from_dict(_section(data, "skills"))
	Training.from_dict(_section(data, "training"))
	Game.from_dict(_section(data, "game"))
	Automation.from_dict(_section(data, "automation"))  # 정체 시계가 이번 판 최고에서 시작하도록 Game 뒤에
	Tower.from_dict(_section(data, "tower"))
	Treasure.from_dict(_section(data, "treasure"))
	Fragments.from_dict(_section(data, "fragments"))  # 업적(통계) 뒤에
	Prefs.from_dict(_section(data, "prefs"))


## 데이터 초기화: 모든 오토로드를 기본값으로
static func reset_all() -> void:
	Transcend.reset()
	Rebirth.reset()
	Prestige.reset()
	Achievements.reset()
	Equipment.reset()
	Party.reset()
	Skills.reset()
	Training.reset()
	Promotions.reset()
	Game.reset()
	Game.set_auto_retry(true)  # 회귀가 지우지 않는 화면 설정도 기본값으로 ("모든 데이터를 지운다")
	Party.set_buy_mode(Party.BuyMode.ONE)
	Automation.reset()
	Challenges.reset()
	Tower.reset()
	Treasure.reset()
	Fragments.reset()
	Prefs.reset()


## 저장 데이터의 한 부분. 없거나 딕셔너리가 아니면 빈 딕셔너리 (각 오토로드가 기본값으로 채운다)
static func _section(data: Dictionary, key: String) -> Dictionary:
	var part: Variant = data.get(key, {})
	return part if part is Dictionary else {}

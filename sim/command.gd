class_name SimCommand
extends RefCounted

## 플레이어 입력이 시뮬레이션에 닿는 유일한 통로 (ARCHITECTURE §2 규칙 4).
##
## game 계층은 sim의 상태를 직접 바꾸지 않는다. 커맨드를 만들어 world에 넘긴다.
## 이 우회가 값을 하는 곳:
##   - 헤드리스 밸런싱(§8)이 UI 없이 같은 경로로 게임을 조작할 수 있다
##   - 나중에 리플레이·되돌리기를 붙일 자리가 이미 있다
##   - "어디서 상태가 바뀌었는가"의 답이 항상 커맨드 하나다
##
## 실행 결과는 오류 코드 문자열이다. 성공이면 OK(빈 문자열).
## **한글 문구를 반환하지 않는다** — 문구는 표현이고 game 계층의 몫이다.

const OK := ""


## 서브클래스가 구현한다. 성공 시 OK, 실패 시 오류 코드.
func execute(_world: SimWorld) -> String:
	push_error("SimCommand.execute()가 구현되지 않았습니다: %s" % self)
	return "not_implemented"

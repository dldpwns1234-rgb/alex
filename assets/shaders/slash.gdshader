shader_type canvas_item;
// 베기 자국을 칼이 지나는 방향으로 훑어 보인다 (GDD 11절). SlashFx가 Tween으로 움직인다.
// head가 앞머리, tail이 꼬리. 그림 세로 좌표 0(시작 끝)~1(반대 끝)에서 tail보다 뒤이고 head보다 앞인 부분만 보인다

uniform float head : hint_range(-0.5, 1.5) = 1.0;
uniform float tail : hint_range(-0.5, 1.5) = 0.0;
uniform float head_soft : hint_range(0.0, 0.5) = 0.04;  // 앞머리는 날카롭게
uniform float tail_soft : hint_range(0.0, 0.5) = 0.25;  // 꼬리는 길게 흐리게
uniform float downward = 1.0;  // 1이면 위에서 아래로, -1이면 아래에서 위로

void fragment() {
	float y = downward > 0.0 ? UV.y : 1.0 - UV.y;
	float front = 1.0 - smoothstep(head - head_soft, head, y);
	float back = smoothstep(tail, tail + tail_soft, y);
	COLOR.a *= front * back;
}

shader_type canvas_item;
// 피격 번쩍임 (GDD 11절). flash가 1이면 그림이 흰색으로, 0이면 원래 색으로 보인다. Actor가 Tween으로 움직인다

uniform float flash : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	COLOR.rgb = mix(COLOR.rgb, vec3(1.0), flash);
}

#ifndef COLOR_FUNC
#define COLOR_FUNC

float3 RGB2HSV(float3 c) {
	float4 K = float4(0.0, -1.0/3.0, 2.0/3.0, -1.0);
	float4 p = lerp(float4(c.b, c.g, K.w, K.z), float4(c.g, c.b, K.x, K.y), step(c.b, c.g));
	float4 q = lerp(float4(p.x, p.y, p.w, c.r), float4(c.r, p.y, p.z, p.x), step(p.x, c.r));

	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 HSV2RGB(float3 c){
	float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
	return c.z * lerp(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

float3 HSVShift(float3 baseColor, float3 shift)
{
    float3 hsv = RGB2HSV(baseColor);
    hsv = hsv + shift.xyz;
    hsv.yz = saturate(hsv.yz);
    return HSV2RGB(hsv);
}

float3 HSVShift(float3 baseColor, float4 shift)
{
    return lerp(baseColor, HSVShift(baseColor, shift.rgb), shift.a);
}

float3 HSVMult(float3 baseColor, float3 hsvMult)
{
    float3 hsv = RGB2HSV(baseColor);
    hsv *= hsvMult.xyz;
    hsv.yz = saturate(hsv.yz);
    return HSV2RGB(hsv);
}

float3 HSVMult(float3 baseColor, float4 hsvMult)
{
    return lerp(baseColor, HSVMult(baseColor, hsvMult.xyz), hsvMult.w);
}

float3 HSVAdjust(float3 baseCol, float hueShift, float2 svMult)
{
    float3 hsv = RGB2HSV(baseCol);
    hsv.x += hueShift;
    hsv.yz *= svMult.xy;
    hsv.yz = saturate(hsv.yz);
    return lerp(baseCol, HSV2RGB(hsv), 1);
}

float3 HSVAdjust(float3 baseColor, float4 adjust)
{
    return lerp(baseColor, HSVAdjust(baseColor, adjust.x, adjust.yz), adjust.a);
}
	
float3 HSVPowerAdjust(float3 blurCol, float3 power)
{
    float3 hsv = RGB2HSV(blurCol);
    hsv = saturate(hsv);
    hsv = pow(hsv, power);
    return HSV2RGB(hsv);
}

float3 HSVClamp(float3 col, float3 max)
{
    float3 hsv = RGB2HSV(col);
    hsv = saturate(hsv);
    hsv = min(max, hsv);
    return HSV2RGB(hsv);
}
#endif
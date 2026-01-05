#ifndef _TRANSFORM_HLSL
#define _TRANSFORM_HLSL

#include "Quaternion.hlsl"

#ifndef MATRIX4x4_IDENTITY
#define MATRIX4x4_IDENTITY  float4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
#endif

float3 MultiplyPoint3x4(float4x4 martix, float3 vec)
{
	float4 v = float4(vec, 1);
	v = mul(martix, v);
    v /= v.w;
    return v.xyz;
}
float3 TransformVector(float4x4 martix, float3 vec)
{
    float4 v = float4(vec, 0);
    v = mul(martix, v);
    return v.xyz;
}

float3 WorldPosToLocal(float4x4 martix, float3 pos)
{
    float3 uv = MultiplyPoint3x4(martix, pos);
    return uv + 0.5f;
}

float3 LocalPosToWorld(float4x4 martix, float3 pos)
{
    float3 wPos = MultiplyPoint3x4(martix, pos - 0.5f);
    return wPos;
}

float ConvertDegToRad(float degrees)
{
    return (3.141592 / 180.0) * degrees;
}

float4x4 TransformationMatrix(float3 pos)
{
	return float4x4(1, 0, 0, pos.x,
		0, 1, 0, pos.y,
		0, 0, 1, pos.z,
		0, 0, 0, 1);
}

float4x4 RotationMatrix(float3 anglesDeg)
{
    float3 radian = float3(ConvertDegToRad(anglesDeg.x), ConvertDegToRad(anglesDeg.y), ConvertDegToRad(anglesDeg.z));

    float4x4 rotationX = float4x4(1.0, 0.0, 0.0, 0.0,
        0.0, cos(radian.x), -sin(radian.x), 0.0,
        0.0, sin(radian.x), cos(radian.x), 0.0,
        0.0, 0.0, 0.0, 1.0);

    float4x4 rotationY = float4x4(cos(radian.y), 0.0, sin(radian.y), 0.0,
        0.0, 1.0, 0.0, 0.0,
        -sin(radian.y), 0.0, cos(radian.y), 0.0,
        0.0, 0.0, 0.0, 1.0);

    float4x4 rotationZ = float4x4(cos(radian.z), -sin(radian.z), 0.0, 0.0,
        sin(radian.z), cos(radian.z), 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        0.0, 0.0, 0.0, 1.0);

    return mul(mul(rotationX, rotationY), rotationZ);
}

// Unity's rotation order is ZXY
float4 eulerToQuaternion(float3 rad)
{
    rad = rad*0.5;
    return float4(cos(rad.x)*cos(rad.y)*cos(rad.z) + sin(rad.x)*sin(rad.y)*sin(rad.z),
                  sin(rad.x)*cos(rad.y)*cos(rad.z) + cos(rad.x)*sin(rad.y)*sin(rad.z),
                  cos(rad.x)*sin(rad.y)*cos(rad.z) - sin(rad.x)*cos(rad.y)*sin(rad.z),
                  cos(rad.x)*cos(rad.y)*sin(rad.z) - sin(rad.x)*sin(rad.y)*cos(rad.z));
}

float4x4 ScaleMatrix(float3 scale)
{
    return float4x4(scale.x, 0.0, 0.0, 0.0,
        0.0, scale.y, 0.0, 0.0,
        0.0, 0.0, scale.z, 0.0,
        0.0, 0.0, 0.0, 1.0);
}

float4x4 TRS(float3 pos, float3 rotationAng, float3 scale)
{
    float4x4 translation = TransformationMatrix(pos);
    float4x4 rotation = RotationMatrix(rotationAng);
    return mul(mul(translation, rotation), ScaleMatrix(scale));
}

float4x4 TRS(float3 pos, float4 quaternion, float3 scale)
{
    float4x4 translation = TransformationMatrix(pos);
    float4x4 rotation = quaternion_to_matrix(quaternion);
    return mul(mul(translation, rotation), ScaleMatrix(scale));
}

float4x4 Translate(float4x4 trs, float4x4 transformMatrix)
{
	return mul(transformMatrix, trs);
}

float4x4 TBNRotate(float3 normal)
{
    float3 n = normalize(normal);
    float3 t = float3(1, 0, 0);
    float3 b = normalize(cross(n, t));
    t = cross(b, n);
    return float4x4(t.x, b.x, n.x, 0,
                    t.y, b.y, n.y, 0,
                    t.z, b.z, n.z, 0,
                    0, 0, 0, 1);
}

float4x4 TNBRotate(float3 normal)
{
    float3 n = normalize(float3(normal.x, normal.y, -normal.z));
    float3 t = float3(1, 0, 0);
    float3 b = normalize(cross(n, t));
    t = cross(b, n);
    return float4x4(t.x, n.x, b.x, 0,
                    t.y, n.y, b.y, 0,
                    t.z, n.z, b.z, 0,
                    0, 0, 0, 1);
}

float4x4 TRS(float3 pos, float4 quaternion, float3 tilt, float3 scale)
{
    float4x4 translation = TransformationMatrix(pos);
    float4x4 tbn = TNBRotate(tilt);
    float4x4 rotation = mul(tbn, quaternion_to_matrix(quaternion));
    return mul(mul(translation, rotation), ScaleMatrix(scale));
}

bool AABB(float2 uv)
{
    uv += (0.5 - uv) * 1e-6;
    return uv.x > 0 && uv.x < 1 && uv.y > 0 && uv.y < 1;
}

float Sign (float2 p1, float2 p2, float2 p3)
{
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
}

bool PointInTriangle (float2 pt, float2 v1, float2 v2, float2 v3)
{
    float d1 = Sign(pt, v1, v2);
    float d2 = Sign(pt, v2, v3);
    float d3 = Sign(pt, v3, v1);

    bool has_neg = (d1 < 0) || (d2 < 0) || (d3 < 0);
    bool has_pos = (d1 > 0) || (d2 > 0) || (d3 > 0);

    return !(has_neg && has_pos);
}

float2 InvQuadrilateralUV(float2 pt, float2 bottomLeft, float2 bottomRight, float2 topLeft)
{
    float2 vec0 = (bottomRight - bottomLeft);
    float2 vec1 = (topLeft - bottomLeft);
    float2 vec2 = (pt - bottomLeft);
    float dot00 = dot(vec0, vec0);
    float dot01 = dot(vec0, vec1);
    float dot02 = dot(vec0, vec2);
    float dot11 = dot(vec1, vec1);
    float dot12 = dot(vec1, vec2);

    float denom = dot00 * dot11 - dot01 * dot01;
    // if (abs(denom) < 1e-6)
    //     return float2(-1,-1);
    float invDenom = 1.0 / denom;
    float u = (dot11 * dot02 - dot01 * dot12) * invDenom;
    float v = (dot00 * dot12 - dot01 * dot02) * invDenom;
    return float2(u, v);
}

float2 BilinearUV(float2 uv, float2 leftBottom, float2 rightBottom, float2 leftTop, float2 rightTop)
{
    uv = saturate(uv);
    float2 bottom = lerp(leftBottom, rightBottom, uv.x);
    float2 top = lerp(leftTop, rightTop, uv.x);
    return lerp(bottom, top, uv.y);
}

#endif
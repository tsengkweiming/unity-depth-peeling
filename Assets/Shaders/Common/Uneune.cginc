#ifndef UNEUNE_INCLUDE
#define UNEUNE_INCLUDE

#include "Assets/FlowerPeople/Shaders/CGIncludes/Noise.hlsl"

#ifdef UNEUNE_SIMPLEX_NOISE
#define NOISE_FUNC(coord) snoise(coord)
#else
#define NOISE_FUNC(coord) ClassicNoise(coord)
#endif

float4 _DateTime;

float4 _GroundUvStepSize;
float  _UneuneHeight;
float2 _UneuneTexScale;
float2 _GroundTexelSize;
float  _GroundScale;
float4 _Size;
float4 _Amplitude;
float4 _Power;
float4 _Gain;
float4 _Crop;
float4 _Direction;
float _Speed;


inline float ComputeUneuneHeightOld(float2 uv)
{
	uv *= _UneuneTexScale.xy;
			
	float3 pos = float3(uv, 0) + _DateTime.xyz;
	float3 p0 = float3(_Size.x, _Size.x, _Speed) * pos;
	float3 p1 = float3(_Size.y, _Size.y, _Speed) * pos;
	float3 p2 = float3(_Size.z, _Size.z, _Speed) * pos;
	float3 p3 = float3(_Size.w, _Size.w, _Speed) * pos;

	#ifdef UNEUNE_SIMPLEX_NOISE
	float4 c = float4(snoise(p0), snoise(p1), snoise(p2), snoise(p3));
	#else
	float4 c = float4(ClassicNoise(p0), ClassicNoise(p1), ClassicNoise(p2), ClassicNoise(p3));
	#endif

	float  crop = 1 - step(uv.x, _Crop.z) * step(_Crop.x, uv.x) * step(uv.y, _Crop.w) * step(_Crop.y, uv.y);
	
	#if UNEUNE_DEBUG
	return crop * dot(c, _Gain);
	#else
	return dot(c, _Gain);
	#endif
}

inline float ComputeUneuneHeight(float3 uvw, float time)
{
    float t = time * _Speed;
    float3 pos = uvw + _Direction.xyz * t;
	
    half4 noise4;
    noise4.x = _Amplitude.x * NOISE_FUNC(pos * _Size.x);
    noise4.y = _Amplitude.y * NOISE_FUNC(pos * _Size.y);
    noise4.z = _Amplitude.z * NOISE_FUNC(pos * _Size.z);
    noise4.w = _Amplitude.w * NOISE_FUNC(pos * _Size.w);

    return dot(noise4, _Gain);
}

float3 ComputeUneUneNormal(float2 uv, float time, float groundScale)
{
	float groundHeight[9];

	[unroll]
	for (int y = 0; y < 3; y++) 
	{
		[unroll]
		for (int x = 0; x < 3; x++)
		{
            float2 uvw = uv + float2((x - 1) * _GroundUvStepSize.x,
									 (y - 1) * _GroundUvStepSize.y);

			//uv2.x = clamp(uv2.x, 0.0, 1.0 );
			//uv2.y = clamp(uv2.y, 0.0, 1.0 );

            groundHeight[y * 3 + x] = ComputeUneuneHeight(float3(uvw * _UneuneTexScale, 0), time);
        }
	}

    float dx = groundScale * _UneuneHeight * _GroundTexelSize.x * (0.125 * (groundHeight[8] + groundHeight[2] - (groundHeight[6] + groundHeight[0])) + 0.25 * (groundHeight[5] - groundHeight[3]));
    float dy = groundScale * _UneuneHeight * _GroundTexelSize.y * (0.125 * (groundHeight[6] + groundHeight[8] - (groundHeight[0] + groundHeight[2])) + 0.25 * (groundHeight[7] - groundHeight[1]));

    return float3(dx, dy, 1);
}

float3 ComputeUneUneNormal(float2 uv, float time)
{
	return ComputeUneUneNormal(uv, time, _GroundScale);
}

#endif
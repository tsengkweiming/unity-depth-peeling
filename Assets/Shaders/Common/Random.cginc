
#ifndef RANDOM_INCLUDE
#define RANDOM_INCLUDE

// Wang Hash Random
#define UINT_MAX 4294967295
#define INV_UINT_MAX 2.3283064e-10

inline uint wang_hash(uint seed)
{
    seed = (seed ^ 61) ^ (seed >> 16);
    seed *= 9;
    seed = seed ^ (seed >> 4);
    seed *= 0x27d4eb2d;
    seed = seed ^ (seed >> 15);
    return seed;
}

float wang_hash01(uint seed)
{
    return wang_hash(seed) * INV_UINT_MAX;
}

float random(float t)
{
    return frac(sin(t * 12345.564) * 7658.76);
}

uint pcg(uint v)
{
    uint state = v * 747796405u + 2891336453u;
    uint word = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
    return (word >> 22u) ^ word;
}

float pcg01(uint v)
{
    return pcg(v) / float(0xffffffffu);
}

inline float random1dto1d(uint seed)
{
  return saturate(wang_hash(seed) * INV_UINT_MAX);
}

inline float random2dto1d(uint2 seed)
{
    return saturate(wang_hash(wang_hash(seed.x) ^ seed.y) * INV_UINT_MAX);
}

inline float random3dto1d(uint3 seed)
{
    return saturate(wang_hash(wang_hash(wang_hash(seed.x) ^ seed.y) ^ seed.z) * INV_UINT_MAX);
}

#endif
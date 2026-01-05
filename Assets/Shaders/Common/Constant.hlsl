#ifndef _SHADERS_CS_CONSTANT_HLSL
#define _SHADERS_CS_CONSTANT_HLSL

//WarpType
static const int WT_None = 0;
static const int WT_Copy = 1;
static const int WT_Blend = 2;

//BackgroundFractal
static const int BF_Legacy = 0;
static const int BF_New = 1;

//FlowerFader
static const int FFM_OFF = 0;
static const int FFM_ON = 1;

//Fractal Type
static const int FractalType_SIMPLEX = 0;
static const int FractalType_PERLIN = 1;

//Fractal Sample Type
static const int FRACTAL_ST_NOISE2D = 0;
static const int FRACTAL_ST_UVMAP = 1;

//Fractal Loop
static const int FRACTAL_WARPX = 1;

//Fractal Debug
static const int FD_SHOW_UV = 1;
static const int FD_SHOW_FADE = 2;
static const int FD_SHOW_ADD = 3;

// Alpha Channel Debug
static const int SHOW_PRE_BLUR_ALPHA = 1;
static const int SHOW_BLUR_ALPHA = 2;

#endif
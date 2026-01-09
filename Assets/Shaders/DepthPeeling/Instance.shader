// Upgrade NOTE: replaced 'UNITY_INSTANCE_ID' with 'UNITY_VERTEX_INPUT_INSTANCE_ID'
// Upgrade NOTE: upgraded instancing buffer 'MyProperties' to new syntax.
Shader "Hidden/Instanced_DepthPeeling"
{
    Properties
    {
		[Enum(UnityEngine.Rendering.CullMode)] _CullMode("Cull Mode", Float) = 0
        _MainTex           ("Texture",         2D) = "white" {}
        _Alpha			   ("Alpha",           Range(0,1)) = 1

        _Color        ("Color",        Color) = (1,1,1,1)
		[Enum(Off, 0, On, 1)] _ZWrite ("ZWrite",         Float) = 1
		[Enum(UnityEngine.Rendering.CompareFunction)]_ZTest("ZTest", Float) = 4
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcFactor0 ("Src Blend Factor 0", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstFactor0 ("Dst Blend Factor 0", Float) = 0
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcFactor1 ("Src Blend Factor 1", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstFactor1 ("Dst Blend Factor 1", Float) = 0
        [Enum(UnityEngine.Rendering.BlendOp)] _BlendOp1 ("Blend Operation 1", Float) = 0
        [Enum(UnityEngine.Rendering.BlendOp)] _BlendOp2 ("Blend Operation 2", Float) = 0
    }
	CGINCLUDE
    #include "UnityCG.cginc"
    #include "Assets/Shaders/Common/InstanceStruct.cginc"
    #include "Assets/Shaders/Common/InstanceUtils.hlsl"
    #include "Assets/Shaders/Common/Color.cginc"
    #include "Assets/Shaders/Common/Random.cginc"
	#include "Assets/Shaders/Common/OIT.hlsl"
    #include "Assets/Shaders/Common/Transform.hlsl"
    #include "Assets/Shaders/Common/Constant.hlsl"

	#ifndef PI
	#define PI 3.14159265359f
	#endif 
	#ifndef TAU
	#define TAU 6.28318530718
	#endif 
    #define IDENTITY_MATRIX float4x4(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
    
    struct vsin {
        uint   vid: SV_VertexID;
        float4 vertex : POSITION;
        float2 texcoord : TEXCOORD0;
        uint instanceID: SV_InstanceID;
    };

    struct v2f {
        uint   bufferID : SV_InstanceID;
        float4 vertex : SV_POSITION;
        float  depth : DEPTH;
        float2 uv : TEXCOORD0;
        float4 worldPos : TEXCOORD1;
        float4 screenPos : TEXCOORD2;
		float z : TEXCOORD3;
    };
    
    struct f2s
    {
        fixed4 color : COLOR0;
        float4 depth : COLOR1;
    	#if defined(DUAL_PEELING)
        float4 depth1 : COLOR2;
    	#endif
    	
    };
    StructuredBuffer<InstanceData> _InstanceBuffer      : register(t0);

    sampler2D _MainTex;
    sampler2D _AlphaTex;
    float  _Scale;
    float  _Alpha;
    float4  _Color;
	sampler2D _PrevDepthTex;
	sampler2D _PrevDepthTex1;

    v2f vert(vsin v) 
    {
        v2f OUT;

    	OUT.bufferID = v.instanceID;
        InstanceData instanceData = _InstanceBuffer[v.instanceID];

    	float4 quaternion = eulerToQuaternion(instanceData.rotation);
    	float4x4 trs = TRS(instanceData.position, quaternion, instanceData.scale * _Scale);
        float4 pos = mul(trs, v.vertex);
    	
        // model to world
		float4 worldPos  = mul(unity_ObjectToWorld, pos);

        // world to screen
        OUT.vertex = mul(UNITY_MATRIX_VP, worldPos);
        OUT.worldPos = worldPos;
        OUT.uv = v.texcoord;
        // screen
    	OUT.screenPos = ComputeScreenPos(UnityWorldToClipPos(worldPos));
        OUT.depth = -mul(UNITY_MATRIX_V, worldPos).z * _ProjectionParams.w;
		// OUT.depth = COMPUTE_DEPTH_01;//OUT.vertex.z / OUT.vertex.w;

		// Camera-space depth
		OUT.z = abs(mul(UNITY_MATRIX_V, worldPos).z);
        return OUT;
    }

    f2s frag(v2f IN) : SV_Target
    {
		float depth = IN.depth;
    	#if defined(FRONT_BACK)
			float prevDepth = DecodeFloatRGBA(tex2Dproj(_PrevDepthTex, UNITY_PROJ_COORD(IN.screenPos)));
			// float prevDepth = DecodeFloatRGBA(tex2D(_PrevDepthTex, UNITY_PROJ_COORD(IN.screenPos.xy / IN.screenPos.w))).r;
			clip(depth - (prevDepth + 0.00001));
    	
    	#elif defined(DUAL_PEELING)
			// ---------------------------------------------------------
	        // 1. Fetch Previous Min/Max
	        // ---------------------------------------------------------
	        // Note: For Dual Peeling, _PrevDepthTex MUST be an RGFloat texture.
	        // Standard DDP stores: R = -NearestDepth, G = FarthestDepth
	        // This allows using the hardware 'MAX' blend op for both.
	        
	        float prevMin = DecodeFloatRGBA(tex2Dproj(_PrevDepthTex, UNITY_PROJ_COORD(IN.screenPos)));
	        float prevMax = DecodeFloatRGBA(tex2Dproj(_PrevDepthTex1, UNITY_PROJ_COORD(IN.screenPos)));

	        // ---------------------------------------------------------
	        // 2. The "Inside" Check
	        // ---------------------------------------------------------
	        // We discard if the current fragment is:
	        // A) "Outside" the range (closer than prevMin or further than prevMax)
	        // B) "On" the previous layers (equal to prevMin or prevMax)
	        // C) The previous range was invalid (prevMin >= prevMax)
	        
	        // Using a small epsilon (0.00001) to handle floating point imprecision
	        if (depth <= (prevMin + 0.00001) || depth >= (prevMax - 0.00001) || prevMin >= prevMax)
	            discard;
    	#endif
    	
    	InstanceData instanceData = _InstanceBuffer[IN.bufferID];
		float4 mainTex = tex2D(_MainTex, IN.uv);
        float4 color = mainTex;// * instanceData.color;
    	color.a *= _Alpha;
    	
    	f2s colOut;
    	colOut.color = color;

    	#if defined(DUAL_PEELING)
	        // For Dual Peeling, we need to write the NEW depths for the next pass.
	        // We write -depth to R (so MAX blend becomes MIN logic)
	        // We write  depth to G (so MAX blend finds the furthest)
	        // NOTE: This requires your render target to be floating point (RGFloat)!
	        colOut.depth = EncodeFloatRGBA(IN.depth); 
	        colOut.depth1 = EncodeFloatRGBA(IN.depth); 
	    #else
	        // Fallback for standard methods
			colOut.depth = EncodeFloatRGBA(IN.depth);
	    #endif
        return colOut;
    }
    ENDCG

	SubShader
	{
		Tags {"Queue"="Geometry" "IgnoreProjector"="True" "RenderType"="Transparent"}
		Cull[_CullMode]
        LOD 700

		Pass 
		{
			Name "Forward_Pass"
            ZWrite [_ZWrite]
			ZTest  [_ZTest]
            Blend 0 [_SrcFactor0] [_DstFactor0]
			// Blend 0 SrcAlpha OneMinusSrcAlpha
            Blend 1 [_SrcFactor1] [_DstFactor1]
            Blend 2 [_SrcFactor1] [_DstFactor1]
            BlendOp 0 Add
            BlendOp 1 [_BlendOp1]
            BlendOp 2 [_BlendOp2]
			CGPROGRAM
                #pragma target 5.0
                #pragma multi_compile_instancing
                #pragma multi_compile __ FRONT_BACK DUAL_PEELING // why cannot comment out __
				#pragma vertex vert
				#pragma fragment frag
			ENDCG
		}
	}
}

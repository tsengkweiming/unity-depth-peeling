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
		[Enum(UnityEngine.Rendering.BlendMode)] _SrcFactor ("Src Blend Factor", Float) = 1
        [Enum(UnityEngine.Rendering.BlendMode)] _DstFactor ("Dst Blend Factor", Float) = 0
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
    	// float  clipD0 : SV_ClipDistance0;
        float2 uv : TEXCOORD0;
        float4 worldPos : TEXCOORD1;
        float4 screenPos : TEXCOORD2;
		float z : TEXCOORD3;
    };
            
    struct f2s
    {
        fixed4 color : COLOR0;
        fixed4 depth : COLOR1;
    };
    StructuredBuffer<InstanceData> _InstanceBuffer      : register(t0);

    sampler2D _MainTex;
    sampler2D _AlphaTex;
    float  _Scale;
    float  _Alpha;
    float4  _Color;
	sampler2D _PrevDepthTex;

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
        // OUT.depth = -mul(UNITY_MATRIX_V, worldPos).z * _ProjectionParams.w;
		OUT.depth = COMPUTE_DEPTH_01;//OUT.vertex.z / OUT.vertex.w;

		// Camera-space depth
		OUT.z = abs(mul(UNITY_MATRIX_V, worldPos).z);
        return OUT;
    }

    f2s frag(v2f IN) : SV_Target
    {
    	#ifdef DEPTH_PEELING
		float depth = i.depth;
		float prevDepth = DecodeFloatRGBA(tex2Dproj(_PrevDepthTex, UNITY_PROJ_COORD(IN.screenPos)));

		clip(depth - (prevDepth + 0.00001));
    	#endif
    	
    	InstanceData instanceData = _InstanceBuffer[IN.bufferID];
		float4 mainTex = tex2D(_MainTex, IN.uv);
        float4 color = mainTex * instanceData.color;
    	color.a *= _Alpha;
    	
    	f2s colOut;
    	colOut.color = color;
		colOut.depth = EncodeFloatRGBA(IN.depth);
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
            Blend 0 One Zero
            Blend 1 One Zero
			CGPROGRAM
                #pragma target 5.0
                #pragma multi_compile_instancing
                #pragma multi_compile __ DEPTH_PEELING
				#pragma vertex vert
				#pragma fragment frag
			ENDCG
		}
	}
}

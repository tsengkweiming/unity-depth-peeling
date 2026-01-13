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
        [Enum(UnityEngine.Rendering.BlendOp)] _BlendOpDepth ("Blend Operation in Depth", Float) = 0
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
    #define EPSILON 0.00001
    
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
        float4 depth : COLOR0;
        fixed4 color : COLOR1;
    	#if defined(DUAL_PEELING)
        fixed4 backColor : COLOR2;
    	#endif
    };
    struct f2s2
    {
        float4 depth : COLOR0;
        fixed4 color : COLOR1;
        fixed4 backColor : COLOR2;
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
        OUT.depth = -mul(UNITY_MATRIX_V, worldPos).z * _ProjectionParams.w;
		// OUT.depth = COMPUTE_DEPTH_01;//OUT.vertex.z / OUT.vertex.w;

		// Camera-space depth
		OUT.z = abs(mul(UNITY_MATRIX_V, worldPos).z);
        return OUT;
    }

    f2s2 fragInit(v2f IN) : SV_Target
    {
		float depth = IN.depth;
    	
    	f2s2 colOut;
        colOut.depth = float4(-depth, depth, 0, 0);
        colOut.color = float4(0,0,0,0);
        colOut.backColor = float4(0,0,0,0);
        return colOut;
    }
    f2s frag(v2f IN) : SV_Target
    {
		float depth = IN.depth;
    	#if defined(FRONT_BACK)
			float prevDepth = DecodeFloatRGBA(tex2Dproj(_PrevDepthTex, UNITY_PROJ_COORD(IN.screenPos)));
			// float prevDepth = DecodeFloatRGBA(tex2D(_PrevDepthTex, UNITY_PROJ_COORD(IN.screenPos.xy / IN.screenPos.w))).r;
			clip(depth - (prevDepth + EPSILON));
    	
    	#elif defined(DUAL_PEELING)
	        float2 prevDepth = tex2Dproj(_PrevDepthTex, UNITY_PROJ_COORD(IN.screenPos)).rg;
			float prevMin = -prevDepth.x; // negated for MAX blending
            float prevMax = prevDepth.y;

    		// if (prevMin > prevMax)
    		// 	discard;
			// // Using a small epsilon (0.00001) to handle floating point imprecision
			// if (depth < (prevMin + EPSILON) || depth > (prevMax - EPSILON))
			// 	discard;
    	
    		// 2. Discard Check
		    // We discard ONLY if we are strictly OUTSIDE the onion skin.
		    // We use '- EPSILON' for min and '+ EPSILON' for max to ENSURE we KEEP the boundary layers.
		    // If depth == prevMin, (prevMin < prevMin + Epsilon) is true, so we do NOT discard.
		    if (depth < (prevMin - EPSILON) || depth > (prevMax + EPSILON) || prevMin > prevMax)
		        discard;
    	#endif
    	
    	InstanceData instanceData = _InstanceBuffer[IN.bufferID];
		float4 mainTex = tex2D(_MainTex, IN.uv);
        float4 color = mainTex;// * instanceData.color;
    	color.a *= _Alpha;
    	
    	f2s colOut;
    	#if defined(DUAL_PEELING)
    	// 3. Identify Layer Roles
	    bool isMinLayer = (depth - prevMin) <= EPSILON;
	    bool isMaxLayer = (depth - prevMax) >= EPSILON;
	    bool isInside   = !isMinLayer && !isMaxLayer; // Strictly inside
    	// --- COLOR OUTPUT (Job A) ---
		// Only write color if we match the boundary found in the previous pass
	    colOut.color     = isMinLayer ? color : float4(0,0,0,0);
	    // Back color often requires premultiplied alpha for under-blending
	    colOut.backColor = isMaxLayer ? float4(color.rgb * color.a, color.a) : float4(0,0,0,0);
    	// --- DEPTH OUTPUT (Job B) ---
	    if (isInside)
	    {
	        // We are INSIDE. We are candidates for the NEXT layer.
	        // Write valid depths so the MAX blend op can find the new Min/Max.
	        colOut.depth = float4(-depth, depth, 0, 0);
	    }
	    else
	    {
	        // We are the current Min/Max. We have been peeled.
	        // Write GARBAGE depth so we are ignored in the next pass's depth search.
	        colOut.depth = float4(-1e20, -1e20, 0, 0);
	    }
    	  //   colOut.depth = float4(-depth, depth, 0, 0);
       //      colOut.color = float4(0,0,0,0);
       //      colOut.backColor = float4(0,0,0,0);
       //
       //      if ((depth - prevMin) <= EPSILON)
       //      {
       //          colOut.color = color;
    			// // colOut.depth = float4(-1e9, -1e9, 0, 0);
       //      }
       //
       //      if ((depth - prevMax) <= EPSILON)
       //      {
       //          // For the back layer, we premultiply alpha for Under-blending
       //          colOut.backColor = float4(color.rgb * color.a, color.a);
    			// // colOut.depth = float4(-1e9, -1e9, 0, 0);
       //      }

	    #else
	        // Fallback for standard methods
    		colOut.color = color;
			colOut.depth = EncodeFloatRGBA(depth);
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
            BlendOp 0 [_BlendOpDepth]
            Blend 0 [_SrcFactor0] [_DstFactor0]
            BlendOp 1 Add
            Blend 1 [_SrcFactor1] [_DstFactor1]
            BlendOp 2 Add
            Blend 2 OneMinusDstAlpha One
            
			CGPROGRAM
                #pragma target 5.0
                #pragma multi_compile_instancing
                #pragma multi_compile __ FRONT_BACK DUAL_PEELING
				#pragma vertex vert
				#pragma fragment frag
			ENDCG
		}

		Pass 
		{
			Name "DDP_InitPass"
			ZWrite [_ZWrite]
			ZTest  [_ZTest]
            BlendOp 0 [_BlendOpDepth]
            Blend 0 [_SrcFactor0] [_DstFactor0]
            BlendOp 1 Add
            Blend 1 [_SrcFactor1] [_DstFactor1]
            BlendOp 2 Add
            Blend 2 OneMinusDstAlpha One
            
			CGPROGRAM
                #pragma target 5.0
                #pragma multi_compile_instancing
				#pragma vertex vert
				#pragma fragment fragInit
			ENDCG
		}
	}
}

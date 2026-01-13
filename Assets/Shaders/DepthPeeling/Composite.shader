// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'
Shader "Hidden/Depth Peeling/Composite" {
	Properties {
		_MainTex ("Main Tex", 2D) = "white" {}
	}
	SubShader {
		ZTest Always Cull Off ZWrite Off Fog { Mode Off }

		Pass {
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag

			sampler2D _MainTex;

			struct a2v {
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				return fixed4(1, 1, 1, 1);
			}
			
			ENDCG
		}
		
		Pass {			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
            #pragma multi_compile ALPHA_BLEND ADDITIVE

			sampler2D _MainTex;
			sampler2D _LayerTex;
			
			struct a2v {
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;			
				return o;
			}
			
			fixed4 frag(v2f i) : SV_Target {
				fixed4 col = tex2D(_MainTex, i.uv);
				fixed4 layer = tex2D(_LayerTex, i.uv);
				#if defined(ALPHA_BLEND)
				return layer.a * layer + (1 - layer.a) * col;
				#elif defined(ADDITIVE)
				return layer * layer.a + col;
				#endif
			}
			
			ENDCG
		}
		
		Pass {			
			CGPROGRAM
			
			#pragma vertex vert
			#pragma fragment frag
            #pragma multi_compile ALPHA_BLEND ADDITIVE
			
			sampler2D _FrontTex;
			sampler2D _BackTex;
			
			struct a2v {
				float4 vertex : POSITION;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv : TEXCOORD0;
			};
			
			v2f vert(a2v v) {
				v2f o;
				o.pos = UnityObjectToClipPos(v.vertex);
				o.uv = v.texcoord;			
				return o;
			}

			fixed4 frag(v2f i) : SV_Target {
				float4 front = tex2D(_FrontTex, i.uv);
                float4 back = tex2D(_BackTex, i.uv);
				return front;
				#if defined(ALPHA_BLEND)
				return front + (1 - front.a) * back;
				#elif defined(ADDITIVE)
				return front + back;
				#endif
			}
			
			ENDCG
		}
	}
	FallBack "Diffuse/VertexLit"
}

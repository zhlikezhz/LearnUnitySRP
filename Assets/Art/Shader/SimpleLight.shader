Shader "Custom/SimpleLight"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader
    {

        Pass
        {
            Tags {"LightMode"="SRPDefaultUnlit"}

            CGPROGRAM
            #pragma multi_compile_instancing
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "UnityLightingCommon.cginc"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Shadow/ShadowSamplingTent.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                float3 shadowUV : TEXCOORD2;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            sampler2D _MainTex;
            TEXTURE2D_SHADOW(_ShadowTex);
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)	
                UNITY_DEFINE_INSTANCED_PROP(float4x4, _ShadowMatric)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

            #define SHADOW_SAMPLER sampler_linear_clamp_compare
            SAMPLER_CMP(SHADOW_SAMPLER);

            v2f vert (appdata input)
            {
                v2f output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                output.worldNormal = UnityObjectToWorldNormal(input.normal);
                output.vertex = UnityObjectToClipPos(input.vertex);
                output.uv= input.uv;
                float3 worldPos = mul(unity_ObjectToWorld, input.vertex); 
                output.shadowUV = mul(_ShadowMatric, float4(worldPos,1.0)).xyz;
                return output;
            }

            fixed4 frag (v2f input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                fixed4 col = tex2D(_MainTex, input.uv);
                float shadow = SAMPLE_TEXTURE2D_SHADOW(_ShadowTex, SHADOW_SAMPLER, input.shadowUV);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float diff = max(0, dot(input.worldNormal, lightDir));
                return col * diff;
            }
            ENDCG
        }

        Pass
        {
            Tags{"LightMode"="ShadowCaster"}

            ZWrite On 
            ColorMask 0

            CGPROGRAM
            #pragma multi_compile_instancing
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float2 uv : TEXCOORD0;
                float3 posOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f 
            {
                float2 uv : VAR_BASE_UV;
                float4 posCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            sampler2D _MainTex;
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)	
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

            v2f vert(appdata input)
            {
                v2f output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                output.posCS = UnityObjectToClipPos(input.posOS);
                output.uv = input.uv;
                return output;
            }

            void frag(v2f i)
            {

            }
            ENDCG
        }
    }
}
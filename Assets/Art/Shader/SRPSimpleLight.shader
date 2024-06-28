Shader "Custom/SRPSimpleLight"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader
    {
        HLSLINCLUDE
        #include "../../Custom RP/ShaderLibrary/Common.hlsl"
        #include "../../Custom RP/Shaders/LitInput.hlsl"
        #include "../../Custom RP/ShaderLibrary/Surface.hlsl"
        #include "../../Custom RP/ShaderLibrary/Shadows.hlsl"
        #include "../../Custom RP/ShaderLibrary/Light.hlsl"
        #include "../../Custom RP/ShaderLibrary/BRDF.hlsl"
        #include "../../Custom RP/ShaderLibrary/GI.hlsl"
        #include "../../Custom RP/ShaderLibrary/Lighting.hlsl"
        ENDHLSL

        Pass
        {
            Tags {"LightMode"="SRPDefaultUnlit"}

            HLSLPROGRAM
            #pragma multi_compile_instancing
            #pragma vertex vert
            #pragma fragment frag

            struct appdata
            {
                float4 positionOS:POSITION;
                float3 normalOS:NORMAL;
                float2 baseUV:TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 positionCS:SV_POSITION;
                float3 positionWS:VAR_POSITION;
                float3 normalWS:VAR_NORMAL;
                float2 baseUV:VAR_BASE_UV;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            TEXTURE2D_SHADOW(_ShadowMapTexture);
            CBUFFER_START(_LightAndShadow)
                float4 _MainTex_ST;
                float4 _LightColor0;
                float4 _WorldSpaceLightPos0;
                float4x4 _ShadowMatric;
            CBUFFER_END

            v2f vert (appdata input)
            {
                v2f output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                output.positionWS = TransformObjectToWorld(input.positionOS);
                output.positionCS = TransformWorldToHClip(output.positionWS);
                output.baseUV = TransformBaseUV(input.baseUV);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                return output;
            }

            float4 frag (v2f input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);
                float4 posSTS = mul(_ShadowMatric, float4(input.positionWS, 1.0));
                float atten = SAMPLE_TEXTURE2D_SHADOW(_ShadowMapTexture, SHADOW_SAMPLER, posSTS).r;
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.baseUV);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float diff = max(0, dot(input.normalWS, lightDir));
                return col * diff * atten;
            }
            ENDHLSL
        }

        Pass
        {
            Tags{"LightMode"="ShadowCaster"}

            ZWrite On 
            ColorMask 0

            HLSLPROGRAM
            #pragma multi_compile_instancing
            #pragma vertex vert
            #pragma fragment frag

            struct appdata
            {
                float3 positionOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
                float4 positionCS : SV_POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            TEXTURE2D(_MainTex);

            v2f vert(appdata input)
            {
                v2f output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                float3 positionWS = TransformObjectToWorld(input.positionOS);
                output.positionCS = TransformWorldToHClip(positionWS);
                return output;
            }

            void frag(v2f i)
            {

            }
            ENDHLSL
        }
    }
}
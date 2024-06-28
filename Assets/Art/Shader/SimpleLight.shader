Shader "Custom/SimpleLight"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }

    SubShader
    {
        HLSLINCLUDE
        // #include "../../Custom RP/ShaderLibrary/Common.hlsl"
        ENDHLSL

        Pass
        {
            Tags {"LightMode"="SRPDefaultUnlit"}

            HLSLPROGRAM
            #pragma multi_compile_instancing
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"

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
                float4 pos : SV_POSITION;
                float3 worldNormal : TEXCOORD1;
                float3 worldPos : TEXCOORD2;
                float4 _ShadowCoord : TEXCOORD3;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            sampler2D _MainTex;
            sampler2D _ShadowMapTexture;
            UNITY_INSTANCING_BUFFER_START(UnityPerMaterial)
                UNITY_DEFINE_INSTANCED_PROP(float4, _MainTex_ST)	
                UNITY_DEFINE_INSTANCED_PROP(float4x4, _ShadowMatric)
            UNITY_INSTANCING_BUFFER_END(UnityPerMaterial)

            v2f vert (appdata input)
            {
                v2f output;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_TRANSFER_INSTANCE_ID(input, output);
                output.worldNormal = UnityObjectToWorldNormal(input.normal);
                output.pos = UnityObjectToClipPos(input.vertex);
                output.uv = TRANSFORM_TEX(input.uv.xy, _MainTex);
                // output._ShadowCoord = ComputeScreenPos(input.vertex);//mul(_ShadowMatric, input.vertex);
                // TRANSFER_SHADOW(output);
                output.worldPos = mul(unity_ObjectToWorld, input.vertex);
                float4 o;
                float4 pos = mul(_ShadowMatric, mul(unity_ObjectToWorld, input.vertex));
                // output._ShadowCoord = pos;
                // float4 pos = output.pos;
                o.xy = float2(pos.x, -pos.y) * 0.5 + pos.w * 0.5;
                o.zw = pos.zw;
                output._ShadowCoord = o;
                //ComputeScreenPos(output.vertex);
                // float3 worldPos = mul(unity_ObjectToWorld, input.vertex); 
                // output.shadowUV = mul(_ShadowMatric, float4(worldPos,1.0));
                // float3 worldPos = mul(unity_ObjectToWorld, input.vertex);
                // fixed4 clipPos = mul(_ShadowMatric, float4(worldPos, 1.0));
                // float4 o = clipPos.xyzw * 0.5;
                // o.xy = float2(o.x, o.y) + o.w;
                // o.zw = clipPos.zw;
                // output._ShadowCoord = o;
                //mul(_ShadowMatric, mul(unity_ObjectToWorld, input.vertex));
                return output;
            }

            fixed4 frag (v2f input) : SV_Target
            {
                UNITY_SETUP_INSTANCE_ID(input);

                fixed atten = UnityComputeForwardShadows(0, input.worldPos, input._ShadowCoord);

                // fixed atten = tex2Dproj(_ShadowMapTexture, input._ShadowCoord).r;
                fixed4 col = tex2D(_MainTex, input.uv);
                float3 lightDir = normalize(_WorldSpaceLightPos0.xyz);
                float diff = max(0, dot(input.worldNormal, lightDir));
                return col * diff;// * atten;
                // return fixed4(atten, 0, 0, 1.0f);
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
            #include "UnityCG.cginc"

            struct appdata
            {
                float3 posOS : POSITION;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f 
            {
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
                return output;
            }

            void frag(v2f i)
            {

            }
            ENDHLSL
        }
    }
}
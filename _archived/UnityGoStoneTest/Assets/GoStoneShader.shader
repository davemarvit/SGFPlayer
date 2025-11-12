Shader "Custom/GoStoneShader"
{
    Properties
    {
        _MainTex ("Stone Texture (Top)", 2D) = "white" {}
        _BottomColor ("Bottom Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 200

        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows
        #pragma target 3.0

        sampler2D _MainTex;
        fixed4 _BottomColor;

        struct Input
        {
            float2 uv_MainTex;
            float4 color : COLOR;  // Vertex color
        };

        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            // Get texture color - apply to entire surface
            fixed4 texColor = tex2D(_MainTex, IN.uv_MainTex);

            // Just use the texture everywhere
            o.Albedo = texColor.rgb;
            o.Metallic = 0;
            o.Smoothness = 0.5;
            o.Alpha = 1;
        }
        ENDCG
    }
    FallBack "Diffuse"
}

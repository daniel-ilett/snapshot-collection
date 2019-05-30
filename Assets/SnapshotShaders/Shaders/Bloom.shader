﻿/*	This shader combines the result of a blurring operation that acts only on 
	the brightest pixels of the image, with the unblurred version of the image.

	The blurring steps are provided with UsePass, using a multi-pass Gaussian 
	blur as a basis.
*/
Shader "Snapshot/Bloom"
{
	/*	The Properties section must include anything required by UsePass passes,
		hence the inclusion of _KernelSize and _Spread.
	*/
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_KernelSize("Kernel Size (N)", Int) = 21
		_Spread("St. dev. (sigma)", Float) = 5.0
		_Threshold("Bloom Threshold", Range(0, 1)) = 0.5
    }
    SubShader
    {
        Tags { "RenderType" = "Opaque" }

		Pass
		{
			Name "ThresholdPass"

			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment frag

			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;

			float _Threshold;

			/*	Credit: http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl
				Converts an RGB vector to an HSV (hue, saturation, value) vector.
			*/
			float3 rgb2hsv(float3 c)
			{
				float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
				float4 p = c.g < c.b ? float4(c.bg, K.wz) : float4(c.gb, K.xy);
				float4 q = c.r < p.x ? float4(p.xyw, c.r) : float4(c.r, p.yzx);

				float d = q.x - min(q.w, q.y);
				float e = 1.0e-10;
				return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
			}

			/*	Credit: http://lolengine.net/blog/2013/07/27/rgb-to-hsv-in-glsl
				Converts an HSV (hue, saturation, value) vector to an RGB vector.
			*/
			float3 hsv2rgb(float3 c)
			{
				float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
				float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
				return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
			}

			float4 frag(v2f_img i) : SV_Target
			{
				float4 tex = tex2D(_MainTex, i.uv);
				float brightness = rgb2hsv(tex).y;

				return (brightness > _Threshold) ? tex : float4(0.0, 0.0, 0.0, 1.0);
			}
			ENDCG
		}

		/*	UsePass takes passes from the GaussianBlur shader file and copies 
			them into this shader file. 
			
			Passes #1 and #2 are the horizontal and vertical
			passes of a two-pass Gaussian blur respectively.
		*/

		// If using multipass blur.
		UsePass "Snapshot/GaussianBlur/HORIZONTALPASS"
		UsePass "Snapshot/GaussianBlur/VERTICALPASS"

		Pass
		{
			Name "AddPass"

			CGPROGRAM
			#pragma vertex vert_img
			#pragma fragment frag

			#include "UnityCG.cginc"

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float2 _MainTex_TexelSize;

			// Texture representing the result of the bloom blur.
			sampler2D _SrcTex;

			/*	Poll the unblurred texture (_SrcTex, passed from a C# script
				using Material.SetTexture()) and the blurred texture (_MainTex)
				and return their sum.
			*/
			float4 frag(v2f_img i) : SV_Target
			{
				float3 originalTex = tex2D(_SrcTex, i.uv);
				float3 blurredTex  = tex2D(_MainTex, i.uv);

				return float4(originalTex + blurredTex, 1.0);
			}
			ENDCG
		}
    }
}

using UnityEngine;

public class AccurateGoStone : MonoBehaviour
{
    public Texture2D stoneTexture;

    // Stone parameters (from gafferongames.com)
    public float width = 1.0f;       // Stone diameter
    public float height = 0.243f;    // Stone height (0.486 ratio of diameter / 2 for actual height)
    public float bevelHeight = 0.05f; // Bevel parameter

    public int segments = 64;
    public int rings = 32;

    void Start()
    {
        CreateAccurateStone();
    }

    void CreateAccurateStone()
    {
        Debug.Log("🔧 Creating accurate Go stone with proper geometry and UVs...");

        GameObject stone = new GameObject("AccurateGoStone");
        MeshFilter meshFilter = stone.AddComponent<MeshFilter>();
        MeshRenderer meshRenderer = stone.AddComponent<MeshRenderer>();

        // Generate mesh using proper formulas
        Mesh mesh = GenerateGoStoneMesh(width, height, bevelHeight, segments, rings);
        meshFilter.mesh = mesh;

        // Apply texture with transparency support
        if (stoneTexture != null)
        {
            stoneTexture.wrapMode = TextureWrapMode.Clamp;  // Clamp to avoid repeating edges

            // Use Standard shader with transparency
            Material material = new Material(Shader.Find("Standard"));
            material.mainTexture = stoneTexture;

            // Enable transparency if texture has alpha channel
            if (stoneTexture.format == TextureFormat.RGBA32 || stoneTexture.format == TextureFormat.ARGB32)
            {
                material.SetFloat("_Mode", 3);  // Transparent mode
                material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                material.SetInt("_ZWrite", 0);
                material.DisableKeyword("_ALPHATEST_ON");
                material.EnableKeyword("_ALPHABLEND_ON");
                material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                material.renderQueue = 3000;
                Debug.Log("✅ Transparency enabled");
            }

            material.SetInt("_Cull", 0);  // Double-sided
            meshRenderer.material = material;
            Debug.Log($"✅ Texture applied, format: {stoneTexture.format}");
        }
        else
        {
            Material material = new Material(Shader.Find("Standard"));
            material.color = Color.white;
            meshRenderer.material = material;
            Debug.Log("⚠️  No texture - using white");
        }

        // Add rotation
        stone.AddComponent<RotateStone>();

        // Adjust lighting - reduce intensity to see texture
        RenderSettings.ambientIntensity = 0.3f;
        RenderSettings.ambientLight = Color.white;
    }

    Mesh GenerateGoStoneMesh(float w, float h, float b, int segs, int rngs)
    {
        Mesh mesh = new Mesh();
        mesh.name = "AccurateGoStone";

        // Calculate biconvex parameters using formulas from gafferongames
        float actualHeight = w * h;  // h is ratio of w
        float r = (w * w + actualHeight * actualHeight) / (4 * actualHeight);
        float d = r - actualHeight / 2;

        Debug.Log($"🔧 Stone params: w={w:F3}, h={actualHeight:F3}, r={r:F3}, d={d:F3}");

        // Calculate bevel parameters
        float r1, r2;
        CalculateBevel(r, d, b, out r1, out r2);
        Debug.Log($"🔧 Bevel params: r1={r1:F3}, r2={r2:F3}");

        // For now, generate simplified geometry (we can add bevel later)
        // Focus on getting UV mapping right first

        int vertexCount = (rngs + 1) * segs;
        Vector3[] vertices = new Vector3[vertexCount];
        Vector2[] uvs = new Vector2[vertexCount];

        int vertexIndex = 0;
        for (int ring = 0; ring <= rngs; ring++)
        {
            // Parameter along the profile (0 = top, 1 = bottom)
            float t = (float)ring / rngs;

            // Y coordinate goes from +actualHeight/2 to -actualHeight/2
            float y = actualHeight / 2 - actualHeight * t;

            // Calculate radius at this y using biconvex lens formula
            // Two spheres of radius r, centers at y = +d (top) and y = -d (bottom)
            float radiusAtY = 0;

            if (y >= 0)
            {
                // Top half: sphere centered at +d
                float yFromTopCenter = y - d;
                if (r * r - yFromTopCenter * yFromTopCenter >= 0)
                {
                    radiusAtY = Mathf.Sqrt(r * r - yFromTopCenter * yFromTopCenter);
                }
            }
            else
            {
                // Bottom half: sphere centered at -d
                float yFromBottomCenter = y + d;
                if (r * r - yFromBottomCenter * yFromBottomCenter >= 0)
                {
                    radiusAtY = Mathf.Sqrt(r * r - yFromBottomCenter * yFromBottomCenter);
                }
            }

            // Generate vertices around this ring
            for (int seg = 0; seg < segs; seg++)
            {
                float angle = 2 * Mathf.PI * seg / segs;

                float x = radiusAtY * Mathf.Cos(angle);
                float z = radiusAtY * Mathf.Sin(angle);

                vertices[vertexIndex] = new Vector3(x, y, z);

                // CRITICAL: UV mapping strategy
                // Use PLANAR projection from top (like our earlier attempt)
                // Map X,Z coordinates to U,V (0 to 1 range)
                float maxRadius = w / 2;  // Maximum radius of stone
                float u = 0.5f + x / (2 * maxRadius);
                float v = 0.5f + z / (2 * maxRadius);

                // CLAMP UVs to ensure they stay in 0-1 range
                u = Mathf.Clamp01(u);
                v = Mathf.Clamp01(v);

                uvs[vertexIndex] = new Vector2(u, v);

                vertexIndex++;
            }
        }

        // Generate triangles
        int[] triangles = new int[rngs * segs * 6];
        int triIndex = 0;

        for (int ring = 0; ring < rngs; ring++)
        {
            for (int seg = 0; seg < segs; seg++)
            {
                int current = ring * segs + seg;
                int next = ring * segs + ((seg + 1) % segs);
                int below = (ring + 1) * segs + seg;
                int belowNext = (ring + 1) * segs + ((seg + 1) % segs);

                // Two triangles per quad
                triangles[triIndex++] = current;
                triangles[triIndex++] = next;
                triangles[triIndex++] = below;

                triangles[triIndex++] = next;
                triangles[triIndex++] = belowNext;
                triangles[triIndex++] = below;
            }
        }

        mesh.vertices = vertices;
        mesh.uv = uvs;
        mesh.triangles = triangles;
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();

        // Debug: Check UV range
        float minU = 1, maxU = 0, minV = 1, maxV = 0;
        for (int i = 0; i < uvs.Length; i++)
        {
            minU = Mathf.Min(minU, uvs[i].x);
            maxU = Mathf.Max(maxU, uvs[i].x);
            minV = Mathf.Min(minV, uvs[i].y);
            maxV = Mathf.Max(maxV, uvs[i].y);
        }
        Debug.Log($"🔧 UV range: U({minU:F3} to {maxU:F3}), V({minV:F3} to {maxV:F3})");

        Debug.Log($"✅ Generated {vertices.Length} vertices, {triangles.Length / 3} triangles");
        return mesh;
    }

    void CalculateBevel(float r, float d, float b, out float r1, out float r2)
    {
        float y = b / 2 + d;
        float px = Mathf.Sqrt(r * r - y * y);
        r1 = px * d / (d + b / 2);
        r2 = r - Mathf.Sqrt(d * d + r1 * r1);
    }
}

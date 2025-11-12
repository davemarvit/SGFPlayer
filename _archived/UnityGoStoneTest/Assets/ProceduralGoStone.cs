using UnityEngine;

public class ProceduralGoStone : MonoBehaviour
{
    public Texture2D stoneTexture;
    public int segments = 64;  // Segments around the circumference
    public int rings = 32;     // Rings from top to bottom
    public float radius = 0.5f;
    public float heightRatio = 0.486f;  // Traditional Go stone proportions

    void Start()
    {
        CreateProceduralStone();
    }

    void CreateProceduralStone()
    {
        Debug.Log("🔧 Generating procedural Go stone mesh...");

        GameObject stone = new GameObject("ProceduralGoStone");
        MeshFilter meshFilter = stone.AddComponent<MeshFilter>();
        MeshRenderer meshRenderer = stone.AddComponent<MeshRenderer>();

        // Generate the mesh
        Mesh mesh = GenerateBiconvexLens(radius, heightRatio, segments, rings);
        meshFilter.mesh = mesh;

        // Apply texture - use Standard shader directly for testing
        if (stoneTexture != null)
        {
            // Set texture wrap mode to Repeat
            stoneTexture.wrapMode = TextureWrapMode.Repeat;

            Material material = new Material(Shader.Find("Standard"));
            material.mainTexture = stoneTexture;
            material.color = Color.white;  // Base color white (shows through where texture doesn't reach)
            // Make it double-sided (render both sides of triangles)
            material.SetInt("_Cull", 0);  // 0 = Off (double-sided), 2 = Back (default)
            meshRenderer.material = material;
            Debug.Log($"✅ Standard shader, texture wrap mode: {stoneTexture.wrapMode}");
        }
        else
        {
            Debug.Log("❌ No texture assigned");
        }

        // Add rotation
        stone.AddComponent<RotateStone>();

        // Increase ambient light so shadows aren't so dark
        RenderSettings.ambientIntensity = 0.8f;
        RenderSettings.ambientLight = Color.white;

        Debug.Log($"✅ Generated mesh with {mesh.vertexCount} vertices, {mesh.triangles.Length / 3} triangles");
        Debug.Log("💡 Adjusted ambient lighting to reduce shadow darkness");
    }

    Mesh GenerateBiconvexLens(float stoneRadius, float heightRatio, int segs, int rngs)
    {
        Mesh mesh = new Mesh();
        mesh.name = "BiconvexLens";

        float halfHeight = stoneRadius * heightRatio;

        // Calculate vertex count
        int vertexCount = (rngs + 1) * segs;
        Vector3[] vertices = new Vector3[vertexCount];
        Vector3[] normals = new Vector3[vertexCount];
        Vector2[] uvs = new Vector2[vertexCount];
        Color[] colors = new Color[vertexCount];  // Add vertex colors

        // Generate vertices in rings from top to bottom
        int vertexIndex = 0;
        for (int ring = 0; ring <= rngs; ring++)
        {
            float v = (float)ring / rngs;  // 0 at top, 1 at bottom

            // Height varies from +halfHeight to -halfHeight
            float y = halfHeight * (1 - 2 * v);

            // Calculate radius at this height using circular profile (biconvex lens)
            // Using ellipse equation: x^2/a^2 + y^2/b^2 = 1
            float yNormalized = y / halfHeight;  // -1 to 1
            float ringRadius = stoneRadius * Mathf.Sqrt(Mathf.Max(0, 1 - yNormalized * yNormalized));

            // Generate vertices around this ring
            for (int seg = 0; seg < segs; seg++)
            {
                float u = (float)seg / segs;  // 0 to 1 around circle
                float theta = 2 * Mathf.PI * u;

                // Position
                float x = ringRadius * Mathf.Cos(theta);
                float z = ringRadius * Mathf.Sin(theta);
                vertices[vertexIndex] = new Vector3(x, y, z);

                // Normal (for ellipsoid)
                Vector3 normal = new Vector3(
                    Mathf.Cos(theta),
                    yNormalized / (heightRatio * heightRatio),
                    Mathf.Sin(theta)
                );
                normals[vertexIndex] = normal.normalized;

                // UV coordinates - PLANAR PROJECTION FROM TOP
                // This is the key: we project from above, not wrap around!
                float uvU = 0.5f + x / (2 * stoneRadius);
                float uvV = 0.5f + z / (2 * stoneRadius);
                uvs[vertexIndex] = new Vector2(uvU, uvV);

                // Vertex color: texture the entire stone (both top and bottom)
                // We'll use the same planar UV projection for everything
                colors[vertexIndex] = Color.white;  // Full texture everywhere

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

                // First triangle
                triangles[triIndex++] = current;
                triangles[triIndex++] = next;
                triangles[triIndex++] = below;

                // Second triangle
                triangles[triIndex++] = next;
                triangles[triIndex++] = belowNext;
                triangles[triIndex++] = below;
            }
        }

        mesh.vertices = vertices;
        mesh.uv = uvs;
        mesh.colors = colors;  // Assign vertex colors
        mesh.triangles = triangles;

        // Let Unity calculate normals automatically
        mesh.RecalculateNormals();

        // Recalculate bounds
        mesh.RecalculateBounds();

        Debug.Log($"🔧 Mesh stats: {vertices.Length} vertices, {triangles.Length / 3} triangles");
        Debug.Log($"🔧 UV range check - first UV: ({uvs[0].x:F3}, {uvs[0].y:F3})");

        // Count how many vertices are top vs bottom
        int topCount = 0, bottomCount = 0;
        for (int i = 0; i < colors.Length; i++)
        {
            if (colors[i].r > 0.5f) topCount++;
            else bottomCount++;
        }
        Debug.Log($"🔧 Vertex split: {topCount} top (white), {bottomCount} bottom (black)");

        // Check UV range - find min/max
        float minU = 1f, maxU = 0f, minV = 1f, maxV = 0f;
        for (int i = 0; i < uvs.Length; i++)
        {
            minU = Mathf.Min(minU, uvs[i].x);
            maxU = Mathf.Max(maxU, uvs[i].x);
            minV = Mathf.Min(minV, uvs[i].y);
            maxV = Mathf.Max(maxV, uvs[i].y);
        }
        Debug.Log($"🔧 UV range: U({minU:F3} to {maxU:F3}), V({minV:F3} to {maxV:F3})");

        return mesh;
    }
}

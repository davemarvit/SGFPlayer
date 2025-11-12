using UnityEngine;

public class GoStoneTest : MonoBehaviour
{
    public Texture2D stoneTexture;
    public Material stoneMaterial;

    void Start()
    {
        CreateTexturedStone();
    }

    void CreateTexturedStone()
    {
        // Create a sphere (Go stone shape)
        GameObject stone = GameObject.CreatePrimitive(PrimitiveType.Sphere);
        stone.name = "GoStone";
        stone.transform.position = Vector3.zero;

        // Squish it to Go stone proportions (biconvex lens)
        stone.transform.localScale = new Vector3(1.0f, 0.486f, 1.0f);

        // Apply texture
        if (stoneMaterial != null)
        {
            Renderer renderer = stone.GetComponent<Renderer>();
            renderer.material = stoneMaterial;
            Debug.Log("✅ Applied stone material");
        }
        else if (stoneTexture != null)
        {
            Renderer renderer = stone.GetComponent<Renderer>();
            renderer.material.mainTexture = stoneTexture;
            Debug.Log("✅ Applied stone texture");
        }
        else
        {
            Debug.Log("❌ No texture or material assigned - using default");
        }

        // Add slow rotation so we can see all sides
        stone.AddComponent<RotateStone>();
    }
}

// Simple rotation script
public class RotateStone : MonoBehaviour
{
    public float rotationSpeed = 20f;

    void Update()
    {
        transform.Rotate(Vector3.up, rotationSpeed * Time.deltaTime);
    }
}

import SwiftUI
import RealityKit

struct ContentView: View {
    @State private var rotation: Float = 0

    var body: some View {
        VStack {
            Text("RealityKit Stone Test - Auto-rotating")
                .font(.title)
                .padding()

            RealityView { content in
                // Create a textured stone using RealityKit
                let stone = createTexturedStone()
                stone.name = "stone"
                content.add(stone)

                // Add camera
                let camera = PerspectiveCamera()
                camera.position = [0, 0, 2]
                camera.look(at: [0, 0, 0], from: camera.position, relativeTo: nil)
                content.add(camera)

                // Add lighting
                let light = DirectionalLight()
                light.light.intensity = 5000
                light.position = [1, 2, 1]
                light.look(at: [0, 0, 0], from: light.position, relativeTo: nil)
                content.add(light)

                // Add ambient light
                let ambient = PointLight()
                ambient.light.intensity = 2000
                ambient.position = [0, 0, 0]
                content.add(ambient)
            } update: { content in
                // Update rotation
                if let stone = content.entities.first(where: { $0.name == "stone" }) {
                    stone.orientation = simd_quatf(angle: rotation, axis: [0, 1, 0])
                }
            }
            .frame(width: 600, height: 600)
            .onAppear {
                // Auto-rotate
                Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
                    rotation += 0.01
                }
            }

            Text("Check console for texture loading status")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }

    func createTexturedStone() -> ModelEntity {
        NSLog("🔍 Creating stone with textured top half...")

        // Create container entity
        let container = ModelEntity()

        // PART 1: White sphere for the 3D shape
        let sphere = MeshResource.generateSphere(radius: 0.5)
        var whiteMaterial = SimpleMaterial()
        whiteMaterial.color = .init(tint: .white)

        let sphereEntity = ModelEntity(mesh: sphere, materials: [whiteMaterial])
        sphereEntity.scale = [1.0, 0.486, 1.0]
        container.addChild(sphereEntity)

        // PART 2: Textured plane on top
        if let nsImage = NSImage(named: "clamNH_01") {
            NSLog("✅ NSImage loaded: \(nsImage.size)")
            if let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
                if let texture = try? TextureResource.generate(from: cgImage, options: .init(semantic: .color)) {
                    NSLog("✅ Texture generated from CGImage")

                    // Create a plane mesh for the top
                    let planeMesh = MeshResource.generatePlane(width: 1.0, depth: 1.0)
                    var planeMaterial = SimpleMaterial()
                    planeMaterial.color = .init(texture: .init(texture))

                    let planeEntity = ModelEntity(mesh: planeMesh, materials: [planeMaterial])

                    // Position plane on top of squished sphere
                    // Height of squished sphere = 0.5 * 0.486 = 0.243
                    // Lower it to sit on top (not float above)
                    planeEntity.position = [0, Float(0.243 * 0.5), 0]

                    // Rotate plane to face upward (90 degrees around X axis)
                    planeEntity.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])

                    container.addChild(planeEntity)
                    NSLog("✅ Textured plane added on top")
                } else {
                    NSLog("❌ Failed to generate TextureResource")
                }
            } else {
                NSLog("❌ Failed to get CGImage")
            }
        } else {
            NSLog("❌ NSImage(named:) failed")
        }

        NSLog("🔍 Hybrid stone created")
        return container
    }
}

#Preview {
    ContentView()
}

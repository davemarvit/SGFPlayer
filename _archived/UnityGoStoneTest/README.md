# Unity Go Stone Texture Test

This Unity project tests whether Unity can properly texture a squished sphere (Go stone shape).

## Setup Instructions:

1. **Open Unity Hub**
   - Click "Open" or "Add"
   - Navigate to: `/Users/Dave/Go/SGFPlayer Code/UnityGoStoneTest`
   - Select this folder and open it

2. **Wait for Unity to import assets** (first time takes a minute)

3. **Create a scene:**
   - In Unity Editor, go to File → New Scene
   - Save it as "StoneTest" in Assets folder

4. **Add the test script:**
   - Create an empty GameObject: Right-click in Hierarchy → Create Empty
   - Name it "StoneTestController"
   - Drag `GoStoneTest.cs` from Assets onto this GameObject in Inspector

5. **Assign the texture:**
   - Select the StoneTestController in Hierarchy
   - In Inspector, you'll see "Go Stone Test" component
   - Drag `Assets/Textures/clamstone.png` onto the "Stone Texture" field

6. **Add lighting:**
   - GameObject → Light → Directional Light
   - Position the camera to see the stone

7. **Press Play** to see the textured, rotating Go stone

## What to look for:

- Does the texture map correctly without gaps?
- Does it wrap from the side (like SceneKit) or properly cover the surface?
- Can we see the clamshell pattern clearly when rotating?

## Files:

- `Assets/GoStoneTest.cs` - Script that creates and textures the stone
- `Assets/Textures/clamstone.png` - The clamshell stone texture

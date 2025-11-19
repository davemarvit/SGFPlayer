from PIL import Image, ImageDraw
import math

# Create a 1024x1024 image for the icon
size = 1024
img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Modern gradient background (deep blue to black)
for y in range(size):
    t = y / size
    r = int(10 + t * 20)
    g = int(15 + t * 25)
    b = int(30 + t * 40)
    draw.rectangle([(0, y), (size, y+1)], fill=(r, g, b, 255))

cx, cy = size // 2, size // 2

# Draw abstract 3D grid lines (like a warped perspective grid)
grid_color = (100, 150, 200, 180)
line_width = 4

# Circular/radial grid representing 3D space
for i in range(5):
    radius = 100 + i * 90
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius], 
                 outline=grid_color, width=line_width)

# Radial lines for depth perspective
for angle in range(0, 360, 30):
    rad = math.radians(angle)
    x1 = cx + math.cos(rad) * 80
    y1 = cy + math.sin(rad) * 80
    x2 = cx + math.cos(rad) * 450
    y2 = cy + math.sin(rad) * 450
    draw.line([(x1, y1), (x2, y2)], fill=grid_color, width=line_width)

# Draw stylized 3D stones (layered circles for depth effect)
stones = [
    # (angle, distance_from_center, is_black, size)
    (45, 200, True, 70),
    (135, 250, False, 65),
    (225, 180, True, 60),
    (315, 230, False, 75),
    (90, 300, True, 55),
    (270, 320, False, 70),
    (0, 150, True, 65),
    (180, 280, False, 60),
]

for angle, dist, is_black, stone_size in stones:
    rad = math.radians(angle)
    sx = int(cx + math.cos(rad) * dist)
    sy = int(cy + math.sin(rad) * dist)
    
    if is_black:
        # Black stone - multiple layers for 3D depth
        for i in range(3):
            offset = i * 3
            shade = 60 - i * 20
            draw.ellipse([sx - stone_size + offset, sy - stone_size + offset, 
                         sx + stone_size - offset, sy + stone_size - offset],
                        fill=(shade, shade, shade, 255))
        # Bright highlight
        draw.ellipse([sx - 15, sy - 20, sx - 5, sy - 10],
                    fill=(150, 150, 150, 255))
    else:
        # White stone - multiple layers for 3D depth
        for i in range(3):
            offset = i * 3
            shade = 255 - i * 30
            draw.ellipse([sx - stone_size + offset, sy - stone_size + offset,
                         sx + stone_size - offset, sy + stone_size - offset],
                        fill=(shade, shade, shade, 255))
        # Bright highlight
        draw.ellipse([sx - 15, sy - 20, sx - 5, sy - 10],
                    fill=(255, 255, 255, 255))

# Add glow effect around center
glow_color = (80, 120, 180, 30)
for i in range(10, 0, -1):
    radius = 500 + i * 20
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                outline=glow_color, width=i * 3)

# Save the icon
img.save('SGFPlayer3D_Abstract_Icon.png')
print("Abstract icon created: SGFPlayer3D_Abstract_Icon.png")

from PIL import Image, ImageDraw
import math

# Create a 1024x1024 image for the icon
size = 1024
img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# Background gradient (dark space-like)
for y in range(size):
    color_val = int(20 + (y / size) * 40)
    draw.rectangle([(0, y), (size, y+1)], fill=(color_val, color_val, color_val + 10, 255))

# Draw 3D board (perspective view)
board_color = (200, 150, 100)
board_dark = (160, 120, 80)

# Board perspective (isometric-ish view)
cx, cy = size // 2, size // 2 + 50

# Board top surface (trapezoid for perspective)
board_pts = [
    (cx - 300, cy - 100),  # top left
    (cx + 300, cy - 100),  # top right
    (cx + 250, cy + 150),  # bottom right
    (cx - 250, cy + 150)   # bottom left
]
draw.polygon(board_pts, fill=board_color)

# Board front face (darker)
front_pts = [
    (cx - 250, cy + 150),
    (cx + 250, cy + 150),
    (cx + 250, cy + 200),
    (cx - 250, cy + 200)
]
draw.polygon(front_pts, fill=board_dark)

# Board right face (even darker)
right_pts = [
    (cx + 250, cy + 150),
    (cx + 300, cy - 100),
    (cx + 300, cy - 50),
    (cx + 250, cy + 200)
]
draw.polygon(right_pts, fill=(140, 100, 60))

# Draw grid lines on board top
grid_color = (50, 50, 50)
for i in range(7):
    # Horizontal lines
    x1 = cx - 220 + i * 35
    x2 = cx - 180 + i * 30
    y1 = cy - 80
    y2 = cy + 130
    draw.line([(x1, y1), (x2, y2)], fill=grid_color, width=2)
    
    # Vertical lines with perspective
    start_x = cx - 220 + (i * 73)
    end_x = cx - 180 + (i * 60)
    draw.line([(start_x, cy - 80), (end_x, cy + 130)], fill=grid_color, width=2)

# Draw 3D stones (with shading)
stones = [
    # (x_offset, y_offset, is_black)
    (-100, -40, True),
    (-30, -20, False),
    (40, -30, True),
    (100, -10, False),
    (-70, 30, False),
    (0, 40, True),
    (80, 50, False),
    (-120, 80, True),
    (50, 90, False),
]

for sx, sy, is_black in stones:
    stone_x = cx + sx
    stone_y = cy + sy
    radius = 35
    
    # Draw stone with 3D effect
    if is_black:
        # Black stone with highlight
        for r in range(radius, 0, -1):
            shade = int(255 * (r / radius) * 0.3)
            draw.ellipse([stone_x - r, stone_y - r, stone_x + r, stone_y + r], 
                        fill=(shade, shade, shade, 255))
        # Highlight
        draw.ellipse([stone_x - 15, stone_y - 20, stone_x - 5, stone_y - 10], 
                    fill=(100, 100, 100, 255))
    else:
        # White stone with shadow
        for r in range(radius, 0, -1):
            shade = int(255 - (255 * (r / radius) * 0.2))
            draw.ellipse([stone_x - r, stone_y - r, stone_x + r, stone_y + r], 
                        fill=(shade, shade, shade, 255))
        # Highlight
        draw.ellipse([stone_x - 15, stone_y - 20, stone_x - 5, stone_y - 10], 
                    fill=(255, 255, 255, 255))

# Save the icon
img.save('SGFPlayer3D_Icon.png')
print("Icon created: SGFPlayer3D_Icon.png")

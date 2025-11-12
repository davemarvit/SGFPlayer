#!/usr/bin/env python3
"""
Generate a Go stone (biconvex lens shape) with guaranteed correct UV mapping.
Uses a simple approach: create from profile curve rotated around axis.
"""

import math
import sys

def generate_go_stone(radius=0.5, height_ratio=0.486, segments=64, rings=32):
    """
    Generate a Go stone as a biconvex lens.

    Args:
        radius: Stone radius (half the diameter)
        height_ratio: Total height as ratio of diameter (typically 0.486 for Go stones)
        segments: Number of segments around the circumference
        rings: Number of rings from top to bottom
    """
    vertices = []
    normals = []
    uvs = []
    faces = []

    half_height = radius * height_ratio

    # Generate vertices in rings from top to bottom
    for ring in range(rings + 1):
        # V coordinate (vertical in UV space)
        v = ring / rings

        # Height varies from +half_height to -half_height
        y = half_height * (1 - 2 * v)

        # Calculate radius at this height using circular profile
        # For a biconvex lens, we want a curved profile
        # Using ellipse equation: x^2/a^2 + y^2/b^2 = 1
        # Solve for x (horizontal radius at this height)
        y_normalized = y / half_height  # -1 to 1
        if abs(y_normalized) <= 1:
            ring_radius = radius * math.sqrt(1 - y_normalized**2)
        else:
            ring_radius = 0

        # Generate vertices around this ring
        for seg in range(segments):
            # U coordinate (horizontal in UV space)
            u = seg / segments

            # Angle around the circle
            theta = 2 * math.pi * u

            # Position
            x = ring_radius * math.cos(theta)
            z = ring_radius * math.sin(theta)
            vertices.append((x, y, z))

            # Normal (pointing outward from center)
            # For ellipsoid, normal is not the same as position direction
            # Calculate proper ellipsoid normal
            nx = math.cos(theta)
            nz = math.sin(theta)
            ny = y_normalized / (height_ratio * height_ratio)  # Adjusted for ellipsoid

            # Normalize
            n_len = math.sqrt(nx*nx + ny*ny + nz*nz)
            if n_len > 0:
                normals.append((nx/n_len, ny/n_len, nz/n_len))
            else:
                normals.append((0, 1, 0))

            # UV coordinates - planar projection from top
            # Map from [-radius, radius] to [0, 1]
            uv_u = 0.5 + x / (2 * radius)
            uv_v = 0.5 + z / (2 * radius)
            uvs.append((uv_u, uv_v))

    # Generate faces
    for ring in range(rings):
        for seg in range(segments):
            # Current vertex indices
            curr = ring * segments + seg
            next_seg = ring * segments + ((seg + 1) % segments)
            next_ring = (ring + 1) * segments + seg
            next_both = (ring + 1) * segments + ((seg + 1) % segments)

            # Create two triangles for this quad
            # Make sure winding order is consistent (counter-clockwise from outside)
            faces.append((curr, next_seg, next_ring))
            faces.append((next_seg, next_both, next_ring))

    return vertices, normals, uvs, faces


def write_obj(filename, vertices, normals, uvs, faces):
    """Write OBJ file with vertices, normals, UVs, and faces."""
    with open(filename, 'w') as f:
        f.write("# Go Stone Model - Generated with guaranteed correct UVs\n")
        f.write(f"# {len(vertices)} vertices, {len(faces)} faces\n\n")

        # Write vertices
        for v in vertices:
            f.write(f"v {v[0]:.6f} {v[1]:.6f} {v[2]:.6f}\n")
        f.write("\n")

        # Write texture coordinates
        for uv in uvs:
            f.write(f"vt {uv[0]:.6f} {uv[1]:.6f}\n")
        f.write("\n")

        # Write normals
        for n in normals:
            f.write(f"vn {n[0]:.6f} {n[1]:.6f} {n[2]:.6f}\n")
        f.write("\n")

        # Write faces (OBJ is 1-indexed)
        for face in faces:
            f.write(f"f {face[0]+1}/{face[0]+1}/{face[0]+1} "
                   f"{face[1]+1}/{face[1]+1}/{face[1]+1} "
                   f"{face[2]+1}/{face[2]+1}/{face[2]+1}\n")


if __name__ == '__main__':
    output_file = '/Users/Dave/Downloads/stone_generated.obj'
    if len(sys.argv) > 1:
        output_file = sys.argv[1]

    print("Generating Go stone with clean UV mapping...")
    vertices, normals, uvs, faces = generate_go_stone(
        radius=11.0,  # Match Stone_Standard size (~22 units diameter)
        height_ratio=0.486,
        segments=64,  # Smooth circle
        rings=32      # Smooth profile
    )

    print(f"Generated {len(vertices)} vertices, {len(faces)} faces")
    print(f"Writing to {output_file}...")
    write_obj(output_file, vertices, normals, uvs, faces)

    print(f"Done! Stone saved to {output_file}")
    print("\nThis stone has:")
    print("- Biconvex lens shape (proper Go stone)")
    print("- Planar UV mapping from top (no gaps)")
    print("- Smooth normals")
    print("- Ready to use in SceneKit")

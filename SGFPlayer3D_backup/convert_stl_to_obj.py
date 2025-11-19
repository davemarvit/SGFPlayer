#!/usr/bin/env python3
"""
Convert STL (ASCII or binary) to OBJ format with planar UV mapping from top.
"""

import sys
import struct

def is_binary_stl(filename):
    """Check if STL is binary format."""
    with open(filename, 'rb') as f:
        header = f.read(80)
        # Binary STL shouldn't start with 'solid' in ASCII
        try:
            if header.decode('ascii', errors='ignore').strip().startswith('solid'):
                return False
        except:
            pass
        return True

def read_stl_binary(filename):
    """Read binary STL file."""
    vertices = []
    faces = []
    vertex_map = {}
    vertex_list = []

    with open(filename, 'rb') as f:
        # Skip header (80 bytes)
        f.read(80)

        # Read number of triangles
        num_triangles = struct.unpack('I', f.read(4))[0]
        print(f"Reading {num_triangles} binary triangles...")

        for i in range(num_triangles):
            # Normal vector (we'll recalculate)
            f.read(12)

            # Three vertices
            triangle = []
            for j in range(3):
                vertex_data = f.read(12)
                if len(vertex_data) < 12:
                    print(f"Warning: Incomplete vertex data at triangle {i}")
                    break
                x, y, z = struct.unpack('fff', vertex_data)

                # Round to avoid floating point issues
                vertex_key = (round(x, 6), round(y, 6), round(z, 6))

                if vertex_key not in vertex_map:
                    vertex_map[vertex_key] = len(vertex_list)
                    vertex_list.append(vertex_key)

                triangle.append(vertex_map[vertex_key])

            if len(triangle) == 3:
                faces.append(tuple(triangle))

            # Attribute byte count
            f.read(2)

    print(f"Read {len(faces)} triangles")
    print(f"Found {len(vertex_list)} unique vertices")
    return vertex_list, faces

def read_stl_ascii(filename):
    """Read ASCII STL file."""
    vertices = []
    faces = []
    vertex_map = {}
    vertex_list = []

    with open(filename, 'r') as f:
        current_triangle = []

        for line in f:
            line = line.strip()

            # Match vertex lines
            if line.startswith('vertex'):
                # Parse: vertex x y z
                parts = line.split()
                x, y, z = float(parts[1]), float(parts[2]), float(parts[3])

                # Round to avoid floating point issues
                vertex_key = (round(x, 6), round(y, 6), round(z, 6))

                if vertex_key not in vertex_map:
                    vertex_map[vertex_key] = len(vertex_list)
                    vertex_list.append(vertex_key)

                current_triangle.append(vertex_map[vertex_key])

            elif line.startswith('endfacet'):
                if len(current_triangle) == 3:
                    faces.append(tuple(current_triangle))
                current_triangle = []

    print(f"Read {len(faces)} triangles")
    print(f"Found {len(vertex_list)} unique vertices")
    return vertex_list, faces


def calculate_bounds(vertices):
    """Calculate bounding box."""
    if not vertices:
        return None

    min_x = min(v[0] for v in vertices)
    max_x = max(v[0] for v in vertices)
    min_y = min(v[1] for v in vertices)
    max_y = max(v[1] for v in vertices)
    min_z = min(v[2] for v in vertices)
    max_z = max(v[2] for v in vertices)

    return (min_x, max_x, min_y, max_y, min_z, max_z)


def calculate_planar_uvs(vertices, bounds):
    """Generate planar UV coordinates from top-down view."""
    min_x, max_x, min_y, max_y, min_z, max_z = bounds

    # Use X and Z for horizontal plane (Y is up)
    width = max_x - min_x
    depth = max_z - min_z
    max_dim = max(width, depth)

    center_x = (min_x + max_x) / 2
    center_z = (min_z + max_z) / 2

    uvs = []
    for v in vertices:
        # Project onto XZ plane, centered
        u = 0.5 + (v[0] - center_x) / max_dim
        v_coord = 0.5 + (v[2] - center_z) / max_dim
        uvs.append((u, v_coord))

    return uvs


def calculate_normals(vertices, faces):
    """Calculate vertex normals."""
    # Initialize normals
    normals = [[0.0, 0.0, 0.0] for _ in vertices]

    # Calculate face normals and accumulate
    for face in faces:
        v0 = vertices[face[0]]
        v1 = vertices[face[1]]
        v2 = vertices[face[2]]

        # Edge vectors
        e1 = (v1[0] - v0[0], v1[1] - v0[1], v1[2] - v0[2])
        e2 = (v2[0] - v0[0], v2[1] - v0[1], v2[2] - v0[2])

        # Cross product
        nx = e1[1] * e2[2] - e1[2] * e2[1]
        ny = e1[2] * e2[0] - e1[0] * e2[2]
        nz = e1[0] * e2[1] - e1[1] * e2[0]

        # Accumulate to vertices
        for idx in face:
            normals[idx][0] += nx
            normals[idx][1] += ny
            normals[idx][2] += nz

    # Normalize
    normalized = []
    for n in normals:
        length = (n[0]**2 + n[1]**2 + n[2]**2) ** 0.5
        if length > 0:
            normalized.append((n[0]/length, n[1]/length, n[2]/length))
        else:
            normalized.append((0, 1, 0))

    return normalized


def write_obj(filename, vertices, uvs, normals, faces):
    """Write OBJ file."""
    with open(filename, 'w') as f:
        f.write("# Go Stone Model\n")
        f.write("# Converted from STL with planar UV mapping\n\n")

        # Vertices
        for v in vertices:
            f.write(f"v {v[0]:.6f} {v[1]:.6f} {v[2]:.6f}\n")

        # UVs
        for uv in uvs:
            f.write(f"vt {uv[0]:.6f} {uv[1]:.6f}\n")

        # Normals
        for n in normals:
            f.write(f"vn {n[0]:.6f} {n[1]:.6f} {n[2]:.6f}\n")

        # Faces (OBJ is 1-indexed)
        for face in faces:
            f.write(f"f {face[0]+1}/{face[0]+1}/{face[0]+1} ")
            f.write(f"{face[1]+1}/{face[1]+1}/{face[1]+1} ")
            f.write(f"{face[2]+1}/{face[2]+1}/{face[2]+1}\n")


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 convert_stl_to_obj.py input.stl output.obj")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    print(f"Converting {input_file} to {output_file}...")

    # Detect format and read STL
    if is_binary_stl(input_file):
        print("Detected binary STL format")
        vertices, faces = read_stl_binary(input_file)
    else:
        print("Detected ASCII STL format")
        vertices, faces = read_stl_ascii(input_file)

    # Calculate bounds
    bounds = calculate_bounds(vertices)
    print(f"Bounds: X({bounds[0]:.2f}, {bounds[1]:.2f}) Y({bounds[2]:.2f}, {bounds[3]:.2f}) Z({bounds[4]:.2f}, {bounds[5]:.2f})")

    # Generate UVs (planar from top)
    uvs = calculate_planar_uvs(vertices, bounds)
    print(f"Generated {len(uvs)} UV coordinates")

    # Calculate normals
    normals = calculate_normals(vertices, faces)
    print(f"Calculated {len(normals)} vertex normals")

    # Write OBJ
    write_obj(output_file, vertices, uvs, normals, faces)

    print(f"\nDone! Wrote {output_file}")
    print(f"  Vertices: {len(vertices)}")
    print(f"  Faces: {len(faces)}")
    print(f"  UVs with planar top-down projection")

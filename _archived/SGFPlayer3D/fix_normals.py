#!/usr/bin/env python3
"""
Recalculate all normals to ensure they point outward consistently.
"""

import sys
import math

def read_obj_simple(filename):
    """Read OBJ file - vertices and faces only."""
    vertices = []
    faces = []

    with open(filename, 'r') as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith('#'):
                continue

            parts = line.split()
            if not parts:
                continue

            if parts[0] == 'v':
                vertices.append([float(parts[1]), float(parts[2]), float(parts[3])])
            elif parts[0] == 'f':
                # Parse face - just get vertex indices
                face = []
                for vert in parts[1:]:
                    v_idx = int(vert.split('/')[0]) - 1
                    face.append(v_idx)
                faces.append(face)

    return vertices, faces


def calculate_face_normal(vertices, face):
    """Calculate normal for a face."""
    v0 = vertices[face[0]]
    v1 = vertices[face[1]]
    v2 = vertices[face[2]]

    # Edge vectors
    e1 = [v1[0] - v0[0], v1[1] - v0[1], v1[2] - v0[2]]
    e2 = [v2[0] - v0[0], v2[1] - v0[1], v2[2] - v0[2]]

    # Cross product
    nx = e1[1] * e2[2] - e1[2] * e2[1]
    ny = e1[2] * e2[0] - e1[0] * e2[2]
    nz = e1[0] * e2[1] - e1[1] * e2[0]

    # Normalize
    length = math.sqrt(nx*nx + ny*ny + nz*nz)
    if length > 0:
        return [nx/length, ny/length, nz/length]
    else:
        return [0, 1, 0]


def calculate_centroid(vertices):
    """Calculate mesh centroid."""
    n = len(vertices)
    cx = sum(v[0] for v in vertices) / n
    cy = sum(v[1] for v in vertices) / n
    cz = sum(v[2] for v in vertices) / n
    return [cx, cy, cz]


def ensure_outward_normals(vertices, faces):
    """Flip faces so normals point outward from centroid."""
    centroid = calculate_centroid(vertices)
    flipped_count = 0

    for i, face in enumerate(faces):
        # Calculate face center
        fc = [0, 0, 0]
        for v_idx in face:
            fc[0] += vertices[v_idx][0]
            fc[1] += vertices[v_idx][1]
            fc[2] += vertices[v_idx][2]
        fc = [fc[0]/len(face), fc[1]/len(face), fc[2]/len(face)]

        # Vector from centroid to face center
        to_face = [fc[0] - centroid[0], fc[1] - centroid[1], fc[2] - centroid[2]]

        # Face normal
        normal = calculate_face_normal(vertices, face)

        # Dot product: if negative, normal points inward
        dot = to_face[0]*normal[0] + to_face[1]*normal[1] + to_face[2]*normal[2]

        if dot < 0:
            # Flip winding order
            faces[i] = list(reversed(face))
            flipped_count += 1

    return flipped_count


def calculate_vertex_normals(vertices, faces):
    """Calculate smooth vertex normals."""
    normals = [[0, 0, 0] for _ in vertices]

    # Accumulate face normals
    for face in faces:
        face_normal = calculate_face_normal(vertices, face)
        for v_idx in face:
            normals[v_idx][0] += face_normal[0]
            normals[v_idx][1] += face_normal[1]
            normals[v_idx][2] += face_normal[2]

    # Normalize
    for i, n in enumerate(normals):
        length = math.sqrt(n[0]*n[0] + n[1]*n[1] + n[2]*n[2])
        if length > 0:
            normals[i] = [n[0]/length, n[1]/length, n[2]/length]
        else:
            normals[i] = [0, 1, 0]

    return normals


def calculate_planar_uvs(vertices):
    """Generate planar UV coordinates from top-down view."""
    # Find bounds
    min_x = min(v[0] for v in vertices)
    max_x = max(v[0] for v in vertices)
    min_z = min(v[2] for v in vertices)
    max_z = max(v[2] for v in vertices)

    width = max_x - min_x
    depth = max_z - min_z
    max_dim = max(width, depth)

    center_x = (min_x + max_x) / 2
    center_z = (min_z + max_z) / 2

    uvs = []
    for v in vertices:
        u = 0.5 + (v[0] - center_x) / max_dim
        v_coord = 0.5 + (v[2] - center_z) / max_dim
        uvs.append([u, v_coord])

    return uvs


def write_obj(filename, vertices, uvs, normals, faces):
    """Write OBJ file."""
    with open(filename, 'w') as f:
        f.write("# Go Stone Model - Fixed Normals\n\n")

        for v in vertices:
            f.write(f"v {v[0]:.6f} {v[1]:.6f} {v[2]:.6f}\n")

        for uv in uvs:
            f.write(f"vt {uv[0]:.6f} {uv[1]:.6f}\n")

        for n in normals:
            f.write(f"vn {n[0]:.6f} {n[1]:.6f} {n[2]:.6f}\n")

        for face in faces:
            f.write("f")
            for v_idx in face:
                # OBJ is 1-indexed, v/vt/vn
                f.write(f" {v_idx+1}/{v_idx+1}/{v_idx+1}")
            f.write("\n")


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 fix_normals.py input.obj output.obj")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    print(f"Reading {input_file}...")
    vertices, faces = read_obj_simple(input_file)
    print(f"  Vertices: {len(vertices)}")
    print(f"  Faces: {len(faces)}")

    print("Ensuring normals point outward...")
    flipped = ensure_outward_normals(vertices, faces)
    print(f"  Flipped {flipped} faces")

    print("Calculating vertex normals...")
    normals = calculate_vertex_normals(vertices, faces)

    print("Generating UVs...")
    uvs = calculate_planar_uvs(vertices)

    print(f"Writing {output_file}...")
    write_obj(output_file, vertices, uvs, normals, faces)

    print("Done!")

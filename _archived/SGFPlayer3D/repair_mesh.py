#!/usr/bin/env python3
"""
Repair mesh by filling holes (detecting boundary edges and patching them).
"""

import sys
from collections import defaultdict

def read_obj(filename):
    """Read OBJ file."""
    vertices = []
    uvs = []
    normals = []
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
                vertices.append((float(parts[1]), float(parts[2]), float(parts[3])))
            elif parts[0] == 'vt':
                uvs.append((float(parts[1]), float(parts[2])))
            elif parts[0] == 'vn':
                normals.append((float(parts[1]), float(parts[2]), float(parts[3])))
            elif parts[0] == 'f':
                # Parse face: can be v, v/vt, v/vt/vn, or v//vn
                face = []
                for vert in parts[1:]:
                    indices = vert.split('/')
                    v_idx = int(indices[0]) - 1  # OBJ is 1-indexed
                    face.append(v_idx)
                faces.append(tuple(face))

    return vertices, uvs, normals, faces


def find_boundary_edges(faces):
    """Find edges that appear only once (boundary edges = holes)."""
    edge_count = defaultdict(int)

    for face in faces:
        num_verts = len(face)
        for i in range(num_verts):
            v1 = face[i]
            v2 = face[(i + 1) % num_verts]
            # Store edge in sorted order so direction doesn't matter
            edge = tuple(sorted([v1, v2]))
            edge_count[edge] += 1

    # Boundary edges appear exactly once
    boundary_edges = [edge for edge, count in edge_count.items() if count == 1]

    return boundary_edges


def find_holes(boundary_edges):
    """Group boundary edges into connected loops (holes)."""
    # Build adjacency list
    adjacency = defaultdict(list)
    for v1, v2 in boundary_edges:
        adjacency[v1].append(v2)
        adjacency[v2].append(v1)

    holes = []
    visited_edges = set()

    for start_v in adjacency:
        if start_v in [v for hole in holes for v in hole]:
            continue  # Already part of a hole

        # Try to trace a loop
        hole = [start_v]
        current = start_v

        while True:
            neighbors = [n for n in adjacency[current] if n not in hole]
            if not neighbors:
                # Dead end or closed loop
                if len(adjacency[current]) == 2:
                    # Might connect back to start
                    for n in adjacency[current]:
                        if n == start_v and len(hole) > 2:
                            holes.append(hole)
                            break
                break

            # Take first unvisited neighbor
            next_v = neighbors[0]
            hole.append(next_v)
            current = next_v

            if current == start_v:
                # Closed loop!
                holes.append(hole[:-1])  # Remove duplicate start
                break

            if len(hole) > 1000:
                # Safety: prevent infinite loops
                break

    return holes


def fill_hole_simple(hole, vertices):
    """Fill a hole by creating a triangle fan from centroid."""
    if len(hole) < 3:
        return []

    # Calculate centroid
    cx = sum(vertices[v][0] for v in hole) / len(hole)
    cy = sum(vertices[v][1] for v in hole) / len(hole)
    cz = sum(vertices[v][2] for v in hole) / len(hole)

    centroid_idx = len(vertices)
    vertices.append((cx, cy, cz))

    # Create triangle fan
    new_faces = []
    for i in range(len(hole)):
        v1 = hole[i]
        v2 = hole[(i + 1) % len(hole)]
        new_faces.append((v1, v2, centroid_idx))

    return new_faces


def write_obj(filename, vertices, uvs, normals, faces):
    """Write OBJ file."""
    with open(filename, 'w') as f:
        f.write("# Repaired Go Stone Model\n")
        f.write("# Holes filled automatically\n\n")

        # Vertices
        for v in vertices:
            f.write(f"v {v[0]:.6f} {v[1]:.6f} {v[2]:.6f}\n")

        # UVs
        for uv in uvs:
            f.write(f"vt {uv[0]:.6f} {uv[1]:.6f}\n")

        # Normals
        for n in normals:
            f.write(f"vn {n[0]:.6f} {n[1]:.6f} {n[2]:.6f}\n")

        # Faces
        for face in faces:
            f.write("f")
            for v_idx in face:
                f.write(f" {v_idx + 1}")  # OBJ is 1-indexed
            f.write("\n")


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: python3 repair_mesh.py input.obj output.obj")
        sys.exit(1)

    input_file = sys.argv[1]
    output_file = sys.argv[2]

    print(f"Reading {input_file}...")
    vertices, uvs, normals, faces = read_obj(input_file)

    print(f"  Vertices: {len(vertices)}")
    print(f"  Faces: {len(faces)}")

    print("Finding boundary edges (holes)...")
    boundary_edges = find_boundary_edges(faces)
    print(f"  Found {len(boundary_edges)} boundary edges")

    if boundary_edges:
        print("Grouping into holes...")
        holes = find_holes(boundary_edges)
        print(f"  Found {len(holes)} holes")

        for i, hole in enumerate(holes):
            print(f"    Hole {i+1}: {len(hole)} edges")

        print("Filling holes...")
        for hole in holes:
            new_faces = fill_hole_simple(hole, vertices)
            faces.extend(new_faces)
            print(f"  Added {len(new_faces)} triangles to fill hole")

    print(f"\nWriting {output_file}...")
    write_obj(output_file, vertices, uvs, normals, faces)

    print(f"Done!")
    print(f"  Original: {len(faces) - sum(len(fill_hole_simple(h, list(vertices))) for h in holes)} faces")
    print(f"  Repaired: {len(faces)} faces")

# Dense-mesh texture-paint performance

Measured in Godot 4.7 on July 28, 2026. Diagnostics are disabled in normal
editor use (`DEBUG_MESH_PAINT_PERFORMANCE` is `false`).

## Root causes

- Every 3D pointer event called `surface_get_arrays()` and tested every
  triangle. A successful ray hit immediately triggered another full scan for
  overlapping UVs.
- Linked 2D hover called `surface_get_arrays()` and tested every triangle in UV
  space for every mouse event.
- Fixed model-space area (`1e-7`) and determinant (`1e-6`) thresholds rejected
  valid small triangles. On a dense import at a small scale this could reject
  every ray candidate, which explains the permanently missing 3D cursor.
- The active-target poll rebuilt geometry fingerprints with
  `surface_get_arrays()` every 0.5 seconds even when nothing changed.
- The UV overlay submitted two line calls per edge and two circle calls per
  vertex on every redraw. Linked hover causes frequent redraws, multiplying
  that cost.
- `surface_get_arrays()` returns a new outer `Array`/Variant collection on
  every call. Packed array storage is copy-on-write, but repeated calls still
  create return containers and cross the engine/script boundary. Twenty calls
  took roughly 11–19 ms in the synthetic benchmark, depending on mesh size and
  run.

## Implementation

`GDDrawMeshPaintCache` is created when the 3D preview session starts. It reads
each active material surface once and stores validated, flattened triangle
records with source indices, source surface/triangle ids, positions, UVs,
normals, and 3D/UV bounds.

Two independent midpoint-partition BVHs are built:

- a local-space 3D BVH for two-sided ray picking;
- a UV-space BVH for linked hover, point-in-triangle candidates, brush-edge
  proximity, and shared-UV candidates.

UV-edge adjacency and island membership are also precomputed. Shared-UV
analysis now runs when a stroke begins rather than during ordinary hover.
Mouse motion is coalesced to one pick per rendered frame; existing canvas
stroke interpolation connects the processed samples.

Ray and degeneracy predicates use triangle-relative tolerances. Rays remain in
mesh-local space, so node transforms do not require rebuilding the index.
Normals use inverse-transpose transformation for non-uniform/negative scales.

The 2D UV overlay deduplicates numeric edge/vertex keys, filters by the active
material surfaces, culls to the visible UV rectangle, batches all edges with
`draw_multiline()`, and caches the transformed/clipped points. Vertex crosses
and shadows are progressively disabled at 5k and 25k edges.

## Cache lifecycle

The cache is built after a texture-paint target and material slot are selected.
It is discarded synchronously when the 3D preview/session is cleared.

It is invalidated and rebuilt when:

- the source `Mesh` resource emits `changed`;
- a `MeshInstance3D.mesh` reference changes;
- the selected material slot changes (new session/index);
- the target geometry/UV signature changes;
- generated CSG geometry changes (CSG retains a periodic snapshot check).

Transform-only changes update preview transforms and keep the local-space
cache. Unchanged `MeshInstance3D` targets no longer read mesh arrays every
0.5 seconds.

## Benchmarks

The naive baseline deliberately performs a full scan and one
`surface_get_arrays()` call per query. Its ray primitive uses the native
`Geometry3D` helper, so it is a conservative (faster than the former
GDScript-loop) baseline.

| Mesh | Triangles | Cache build | Naive ray | Cached ray | Avg ray candidates | Naive UV | Cached UV | Avg UV candidates |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Simple grid | 2 | 0.45 ms | 0.35 ms | 5.7 µs | 2.0 | 0.34 ms | 1.6 µs | 2.0 |
| Synthetic dense | 16,928 | 0.315 s | 1.48 ms | 25.0 µs | 4.6 | 6.69 ms | 9.9 µs | 4.6 |
| Synthetic large | 100,352 | 2.36 s | 7.22 ms | 31.7 µs | 4.4 | 38.1 ms | 13.5 µs | 4.4 |
| Imported marble-bust FBX | 17,456 | 0.362 s | — | 133.9 µs | 41.1 | — | — | — |

The imported FBX ray sample cast a 10×10 grid over the mesh bounds; 77 rays
hit. Candidate count remains far below the 17,456-triangle total.

Shared-UV lookup examined 4–8 candidates and took about 29–43 µs on the dense
synthetic meshes. It is no longer part of hover.

Overlay measurements:

| Mesh | Extraction | First clipped-point rebuild | Cached redraw check | Old draw calls/redraw | New batched calls |
|---|---:|---:|---:|---:|---:|
| 16,928 triangles | 52.4 ms | 12.3 ms | 0.27 µs | 68,450 | 3 |
| 100,352 triangles | 314.8 ms | 75.9 ms | 0.27 µs | 403,202 | 2 |

Extraction and clipped-point rebuild happen only when their cache keys change,
not on linked-hover redraws.

## Verification and limitations

`res://tests/test_gddraw_mesh_paint_cache.gd` covers:

- indexed and non-indexed triangle surfaces;
- ray hits at geometry scales from `1e-6` through `1e6`;
- front- and back-facing hits;
- material-surface filtering and cache identity/invalidation keys;
- UVs outside 0–1, overlapping/mirrored-facing shells, and UV islands;
- negative and non-uniform transforms;
- valid tiny triangles and degenerate geometry;
- numeric UV-overlay deduplication;
- sublinear ray queries at 16,928 and 100,352 triangles.

The focused suite currently passes 7 tests and 164 assertions. A clean editor
plugin reload reports no GDScript errors.

Cache construction remains synchronous. It is short for the reported 17k
case, but multi-million-triangle assets may still warrant a future incremental
or worker-thread BVH builder with an editor progress UI. UV hover uses camera
distance as the existing visibility proxy for stacked shells; exact
occlusion-aware 2D-to-3D selection would require an additional accelerated
visibility ray.

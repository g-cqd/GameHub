root = "/Volumes/ExT2/GameHub/work/mtld3d-merge/"


def rep(path, old, new):
    p = root + path
    s = open(p).read()
    assert s.count(old) == 1, (path, s.count(old), old[:80])
    open(p, "w").write(s.replace(old, new))


rep("windows/core/src/stretch_rect.rs",
"""/// texture, between two surfaces that alias one texture, and between two
/// equal rects of one
/// surface that `render.scale` rounds to two extents. Metal's blit encoder""",
"""/// texture, between two surfaces that alias one texture, and between two
/// equal rects of one surface that `render.scale` rounds to two extents.
/// Metal's blit encoder""")

# D3: upstream #1063 (CrossingFetch) replaced this fork's read-span extension.
rep("docs/NFSMW.md",
"""Preserve a caller's nonzero vertex stride even if the consumed declaration extent is larger. Extend bounded staged-buffer read spans to include the final attribute, with overflow falling back to the whole tail. This supports overlapping layouts already accepted by this renderer; it does not claim that such layouts satisfy the documented Direct3D 9 stride contract.

The regression draws distinct green and red triangles at stride 12 and 44 and checks D3D9 read-back colors. Metal API validation accepted both pipelines on Apple M1. Unit tests cover zero, constant, per-instance, indexed and UP streams, plus overflow.""",
"""Preserve a caller's nonzero vertex stride even if the consumed declaration extent is larger. Since the merge of upstream 0.12, upstream's crossing-attribute fetch (#1063) does this: an attribute that ends past its stream's stride is fetched through a binding of its own, and a staged buffer's recorded read range grows by what the last element reads past its stride (`crossing_read_size`). It replaced this fork's own read-span extension.

The fork's regression `stride_below_consumed_extent_preserves_fetch_and_prior_draw` in `windows/tests/tests/e2e/streams.rs` is kept beside upstream's crossing tests: it draws a triangle whose colour lies past a 12-byte stride, refills those colours in the same frame, and checks that the earlier draw keeps its colours.""")
print("ok")

// Copyright (C) 2026 Cry of Fear: Enhanced contributors
// SPDX-License-Identifier: GPL-3.0-or-later
#include <stddef.h>
#include "xash3d_types.h"
#include "com_model.h"
#define CHECK(name, cond) typedef char check_##name[(cond) ? 1 : -1]
CHECK(pointer, sizeof(void *) == 4);
CHECK(node_size, sizeof(mnode_t) == 0x34);
CHECK(node_vis, offsetof(mnode_t, visframe) == 4);
CHECK(node_plane, offsetof(mnode_t, plane) == 0x24);
CHECK(node_children, offsetof(mnode_t, children_) == 0x28);
CHECK(node_first, offsetof(mnode_t, firstsurface_0) == 0x30);
CHECK(node_count, offsetof(mnode_t, numsurfaces_0) == 0x32);
CHECK(surface_size, sizeof(msurface_t) == 0x5c);
CHECK(surface_vis, offsetof(msurface_t, visframe) == 0);
CHECK(surface_flags, offsetof(msurface_t, flags) == 8);
CHECK(surface_poly, offsetof(msurface_t, polys) == 0x24);
CHECK(surface_texinfo, offsetof(msurface_t, texinfo) == 0x2c);
CHECK(texinfo_texture, offsetof(mtexinfo_t, texture) == 0x24);
CHECK(poly_verts, offsetof(glpoly2_t, verts) == 0x10);
CHECK(poly_numverts, offsetof(glpoly2_t, numverts) == 8);
CHECK(poly_flags, offsetof(glpoly2_t, flags) == 0xc);
CHECK(model_nodes, offsetof(model_t, nodes) == 0xa4);
CHECK(model_surfaces, offsetof(model_t, surfaces) == 0xb4);
CHECK(model_lightdata, offsetof(model_t, lightdata) == 0x17c);

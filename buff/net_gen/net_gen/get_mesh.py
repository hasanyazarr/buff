import numpy as np
import open3d as o3d
import random

import matplotlib.pyplot as plt
from collections import deque

from hamine.VesselTree import VesselTree
from hamine.network import Network, Edge, Node, get_track_prob

import pickle

with open('net_simple.pkl', 'rb') as fid:
    net = pickle.load(fid)


samples=[100, 100]
points = []
normals = []

Z, A = np.meshgrid(np.linspace(0, 1, samples[0]), np.linspace(0, 2*np.pi, samples[1]))
Z = Z.reshape(-1,1)

X = np.cos(A).reshape(-1,1)
Y = np.sin(A).reshape(-1,1)

for e in net.edges:
    p0 = e.nodes[0].pos
    r_start = e.r
    r_end = min([ee.r for ee in e.nodes[1].edges])
    r = (1-Z)*r_start + Z*r_end
    pos = p0 + e.length*Z*e.d + r*X*e.e1 + r*Y*e.e2
    nor = X*e.e1 + Y*e.e2
    normals.append(nor)
    points.append(pos)

inout_nodes = [n for n in net.nodes if len(n.edges)==1]
for n in inout_nodes[0:1]:
    e = list(n.edges)[0]
    p0 = n.pos
    r = e.r
    pos = p0 + r * Z * X * e.e1 + r * Z *Y * e.e2
    nor = -np.ones((pos.shape[0], 1)) * e.d
    normals.append(nor)
    points.append(pos)

for n in inout_nodes[1:]:
    e = list(n.edges)[0]
    p0 = n.pos
    r = e.r
    pos = p0 + r * Z * X * e.e1 + r * Z *Y * e.e2
    nor = np.ones((pos.shape[0], 1)) * e.d
    normals.append(nor)
    points.append(pos)

points = np.concatenate(points)
normals = np.concatenate(normals)

pcd = o3d.geometry.PointCloud()
pcd.points = o3d.utility.Vector3dVector(points)
pcd.normals = o3d.utility.Vector3dVector(normals)
o3d.visualization.draw_geometries([pcd])

o3d.io.write_point_cloud("point_cloud.pcd", pcd)

# distances = pcd.compute_nearest_neighbor_distance()
# avg_dist = np.mean(distances)
# radius = 3 * avg_dist
# 
# radius = max([max(e.r for e in n.edges) - min(e.r for e in n.edges) for n in net.nodes])/2
# 
# bpa_mesh = o3d.geometry.TriangleMesh.create_from_point_cloud_ball_pivoting(pcd,o3d.utility.DoubleVector([radius, radius * 2]))
# dec_mesh = bpa_mesh.simplify_quadric_decimation(100000)
# dec_mesh.remove_degenerate_triangles()
# dec_mesh.remove_duplicated_triangles()
# dec_mesh.remove_duplicated_vertices()
# dec_mesh.remove_non_manifold_edges()
# 
# o3d.io.write_triangle_mesh("out.stl", dec_mesh)
# 
# 
# poisson_mesh = o3d.geometry.TriangleMesh.create_from_point_cloud_poisson(pcd, depth=13, width=0, scale=1, linear_fit=False)[0]
# poisson_mesh = o3d.geometry.TriangleMesh.compute_triangle_normals (poisson_mesh)
# 
# o3d.visualization.draw_geometries([poisson_mesh])
# 
# o3d.io.write_triangle_mesh("out_pois.stl", poisson_mesh)
# 
# # export cylinder properties
# np.concatenate([np.concatenate([e.nodes[0].pos, e.d, np.zeros((1,)) * [e.r] ], 0).reshape(1,-1) for e in net.edges],0)

def inside_mask(pos, e, rtol = 0):
    p0 = e.nodes[0].pos
    p1 = e.nodes[1].pos
    r_start = e.r
    r_end = min([ee.r for ee in e.nodes[1].edges])
    v = pos - p0
    v_d  = np.dot(v, e.d.reshape(3,1)).reshape(-1)
    v_e1 = np.dot(v, e.e1.reshape(3,1)).reshape(-1)
    v_e2 = np.dot(v, e.e2.reshape(3,1)).reshape(-1)
    rr = np.sqrt(v_e1*v_e1 + v_e2*v_e2)
    dd = v_d/e.length
    r_compare = r_start * (1-dd) + r_end * dd
    in_d = np.logical_and(dd >= -rtol/2, dd <= (1+rtol/2))
    in_rr = rr <= (r_compare*(1+rtol))
    return np.logical_and(in_d, in_rr)

mask = inside_mask(points, net.edges[20], rtol=0)
mask = np.logical_and(mask, inside_mask(points, net.edges[31], rtol=0))

import itertools as it

rtol = 1e-3
mask_keep = np.array([True]*points.shape[0])
for n in net.nodes:
    if len(n.edges) == 1:
        continue
    for group in it.combinations(n.edges,2):
        mask_ina = inside_mask(points, group[0], rtol=rtol)
        mask_inb = inside_mask(points, group[1], rtol=rtol)
        mask_in = np.logical_and(mask_ina, mask_inb)
    mask_keep = np.logical_and(mask_keep, np.logical_not(mask_in))



    

pcd_full = o3d.geometry.PointCloud()
pcd_full.points = o3d.utility.Vector3dVector(points)
pcd_full.normals = o3d.utility.Vector3dVector(normals)
pcd_full.colors = o3d.utility.Vector3dVector(points*0+1)

pcd = o3d.geometry.PointCloud()
pcd.points = o3d.utility.Vector3dVector(points[mask, :])
pcd.normals = o3d.utility.Vector3dVector(normals[mask, :])
pcd.colors = o3d.utility.Vector3dVector(points[mask,:]*0+[0,0,1])
o3d.visualization.draw_geometries([pcd])

o3d.visualization.draw_geometries([pcd_full, pcd])



pcd_b = o3d.geometry.PointCloud()
pcd_b.points = o3d.utility.Vector3dVector(points[np.logical_not(mask), :])
pcd_b.normals = o3d.utility.Vector3dVector(normals[np.logical_not(mask), :])
o3d.visualization.draw_geometries([pcd_b])
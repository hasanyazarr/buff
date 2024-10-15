import numpy as np
import open3d as o3d
import random

import matplotlib.pyplot as plt
from collections import deque

from hamine.VesselTree import VesselTree
from hamine.network import Network, Edge, Node, get_track_prob

import pickle

import itertools as it


with open('net_simple.pkl', 'rb') as fid:
    net = pickle.load(fid)


samples=[500, 500]
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
    # normals.append(nor)
    # points.append(pos)

for n in inout_nodes[1:]:
    e = list(n.edges)[0]
    p0 = n.pos
    r = e.r
    pos = p0 + r * Z * X * e.e1 + r * Z *Y * e.e2
    nor = np.ones((pos.shape[0], 1)) * e.d
    # normals.append(nor)
    # points.append(pos)

points = np.concatenate(points)
normals = np.concatenate(normals)


def inside_mask(pos, e, rtol = 0):
    p0 = e.nodes[0].pos
    p1 = e.nodes[1].pos
    v = pos - p0
    v_d  = np.dot(v, e.d)
    v_e1 = np.dot(v, e.e1)
    v_e2 = np.dot(v, e.e2)

    rr = np.sqrt(v_e1*v_e1 + v_e2*v_e2)

    r_start = e.r
    r_end = min([ee.r for ee in e.nodes[1].edges])
    dd = v_d/e.length
    r_compare = r_start * (1-dd) + r_end * dd

    in_d = np.logical_and(dd > -rtol/2, dd < (1+rtol/2))
    in_rr = rr <= (r_compare*(1+rtol))
    return np.logical_and(in_d, in_rr)

rtol = 1e-5

# mask = np.array([False]*points.shape[0])
# for n in net.nodes:
#     if len(n.edges) == 1:
#         continue
#     for group in it.combinations(n.edges,2):
#         mask_ina = inside_mask(points, group[0], rtol=rtol)
#         mask_inb = inside_mask(points, group[1], rtol=rtol)
#         mask_in = np.logical_and(mask_ina, mask_inb)
#     #mask_keep = np.logical_and(mask_keep, np.logical_not(mask_in))
#     mask = np.logical_or(mask, mask_in)

mask_in = np.array([0]*points.shape[0])
for e in net.edges:
    mask_in += inside_mask(points, e, rtol=rtol)

mask_in = mask_in>1
mask_out = np.logical_not(mask_in)

pcd_in = o3d.geometry.PointCloud()
pcd_in.points = o3d.utility.Vector3dVector(points[mask_in, :])
pcd_in.normals = o3d.utility.Vector3dVector(normals[mask_in, :])
pcd_in.colors = o3d.utility.Vector3dVector(points[mask_in,:]*0 + [1,0,0])

pcd_out = o3d.geometry.PointCloud()
pcd_out.points = o3d.utility.Vector3dVector(points[mask_out, :])
pcd_out.normals = o3d.utility.Vector3dVector(normals[mask_out, :])
pcd_out.colors = o3d.utility.Vector3dVector(points[mask_out,:]*0 + [0,0,1])
o3d.visualization.draw_geometries([pcd_in, pcd_out])
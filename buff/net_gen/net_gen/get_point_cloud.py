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


samples=[20000]
points = []
normals = []


for e in net.edges:
    pos, nor = e.random_surface_poins(samples=samples)
    normals.append(nor)
    points.append(pos)

inout_nodes = [n for n in net.nodes if len(n.edges)==1]
for n in inout_nodes[0:1]:
    e = list(n.edges)[0]
    pos, nor = e.random_cap_poins(samples=samples, Z=0)
    normals.append(nor)
    points.append(pos)

for n in inout_nodes[1:]:
    e = list(n.edges)[0]
    pos, nor = e.random_cap_poins(samples=samples, Z=1)
    normals.append(nor)
    points.append(pos)

points = np.concatenate(points)
normals = np.concatenate(normals)

pcd = o3d.geometry.PointCloud()
pcd.points = o3d.utility.Vector3dVector(points)
pcd.normals = o3d.utility.Vector3dVector(normals)
o3d.visualization.draw_geometries([pcd])



def inside_mask(pos, e, rtol = [0, 0]):
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
    in_d = np.logical_and(dd >= -rtol[1]/2, dd <= (1+rtol[1]/2))
    in_rr = rr <= (r_compare*(1+rtol[0]))
    return np.logical_and(in_d, in_rr)



all_mask = np.array([False] * points.shape[0])

rtol = [-1e-5, -1e-3]
for e in net.edges:
    all_mask = np.logical_or(all_mask, inside_mask(points, e, rtol=rtol))

pcd_full = o3d.geometry.PointCloud()
pcd_full.points = o3d.utility.Vector3dVector(points)
pcd_full.normals = o3d.utility.Vector3dVector(normals)
pcd_full.colors = o3d.utility.Vector3dVector(points*0+1)

pcd = o3d.geometry.PointCloud()
pcd.points = o3d.utility.Vector3dVector(points[all_mask, :])
pcd.normals = o3d.utility.Vector3dVector(normals[all_mask, :])
pcd.colors = o3d.utility.Vector3dVector(points[all_mask,:]*0+[0,0,1])

o3d.visualization.draw_geometries([pcd_full, pcd])


pcd_b = o3d.geometry.PointCloud()
pcd_b.points = o3d.utility.Vector3dVector(points[np.logical_not(all_mask), :])
pcd_b.normals = o3d.utility.Vector3dVector(normals[np.logical_not(all_mask), :])
o3d.visualization.draw_geometries([pcd_b])


o3d.io.write_point_cloud("point_cloud.pcd", pcd_b, format='xyz')
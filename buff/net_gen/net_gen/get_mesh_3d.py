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


samples=[80, 80, 80]
points = []
normals = []

# Z, R, A = np.meshgrid(np.linspace(0, 1, samples[0]), np.linspace(0, 1, samples[1]), np.linspace(0, 2*np.pi, samples[2]))


for e in net.edges:
    zra = np.random.rand(1000000, 3)
    zra *= [1, 1, 2*np.pi]
    Z, R, A = zra[:,0], zra[:,1], zra[:,2]

    Z = Z.reshape(-1,1)
    X = R.reshape(-1,1) * np.cos(A).reshape(-1,1)
    Y = R.reshape(-1,1) * np.sin(A).reshape(-1,1)

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
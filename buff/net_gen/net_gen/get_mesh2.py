import numpy as np
import random

import matplotlib.pyplot as plt

from hamine.VesselTree import VesselTree
from hamine.network import Network, Edge, Node, get_track_prob

from stl import mesh
import stl

import pickle

def get_mesh_cyl_join(n, samples=[20]):

    e0 = list(n.edges)[0]
    e1 = list(n.edges)[1]

    A = np.linspace(0, 1, samples[0]) * 2*np.pi
    X = np.cos(A)
    Y = np.sin(A)

    r = min(e0.r, e1.r)

    c0 = n.pos
    pos0 = c0 \
    + r * X.reshape(samples+[1]) * e0.e1 \
    + r * Y.reshape(samples+[1]) * e0.e2

    c1 = n.pos
    pos1 = c1 \
    + r * X.reshape(samples+[1]) * e1.e1 \
    + r * Y.reshape(samples+[1]) * e1.e2


    faces_a = np.arange(samples[0])
    faces_a = np.stack([faces_a, np.roll(faces_a,-1), faces_a + samples[0]])
    faces_a = faces_a.T.astype(int)

    faces_b = np.arange(samples[0])
    faces_b = np.stack([np.roll(faces_b,-1), faces_b + samples[0], np.roll(faces_b,-1) + samples[0]])
    faces_b = faces_b.T.astype(int)

    pos = np.concatenate([pos0, pos1])
    faces = np.concatenate([faces_a, faces_b])
    ring = mesh.Mesh(np.zeros(faces.shape[0], dtype=mesh.Mesh.dtype))
    for i, f in enumerate(faces):
        for j in range(3):
            ring.vectors[i][j] = pos[f[j],:]

    return ring

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


with open('net_simple.pkl', 'rb') as fid:
    net = pickle.load(fid)

samples = [200, 200]
meshes = []

for e in net.edges:
    meshes.append(e.get_mesh_cylinder(samples))

normal_nodes = [n for n in net.nodes if len(n.edges)>1]

for n in normal_nodes:
    meshes.append(get_mesh_cyl_join(n, samples[1:]))


inout_nodes = [n for n in net.nodes if len(n.edges)==1]
for n in inout_nodes[0:1]:
    e = list(n.edges)[0]
    meshes.append(e.get_mesh_cap(samples[1:], Z=0))

for n in inout_nodes[1:]:
    e = list(n.edges)[0]
    meshes.append(e.get_mesh_cap(samples[1:], Z=1))


all_points = np.concatenate([m.points for m in meshes])
a1 = all_points[:, 0:3]
a2 = all_points[:, 3:6]
a3 = all_points[:, 6:9]

all_mask = np.array([False] * all_points.shape[0])

rtol = -1e-5
for e in net.edges:
    all_mask = np.logical_or(all_mask, inside_mask(a1, e, rtol=rtol))
    all_mask = np.logical_or(all_mask, inside_mask(a2, e, rtol=rtol))
    all_mask = np.logical_or(all_mask, inside_mask(a3, e, rtol=rtol))


all_data = np.concatenate([m.data for m in meshes])

all_data_filtered = np.delete(all_data, all_mask, 0)

#combined = mesh.Mesh(all_data_filtered)
combined = mesh.Mesh(all_data)

combined.save('meshupa.stl', mode=stl.Mode.BINARY)

# from mpl_toolkits import mplot3d
# from matplotlib import pyplot
# 
# # plot
# figure = pyplot.figure()
# axes = mplot3d.Axes3D(figure)
# 
# axes.add_collection3d(mplot3d.art3d.Poly3DCollection(combined.vectors))
# 
# scale = combined.points.flatten()
# axes.auto_scale_xyz(scale, scale, scale)
# 
# pyplot.show()

#import vtk
#readerSTL = vtk.vtkSTLReader()
#readerSTL.SetFileName('mega_mesh.stl')
#readerSTL.Update()
#polydata = readerSTL.GetOutput()
#
#fill = vtk.vtkFillHolesFilter()
#fill.SetInputData(polydata)
#fill.SetHoleSize(100)    
#fill.Update()
#
#writer = vtk.vtkSTLWriter()
#writer.SetFileTypeToBinary()
#writer.SetInputConnection(fill.GetOutputPort())
#writer.SetFileName('mega_mesh2.stl')
#writer.Update()
#writer.Write()

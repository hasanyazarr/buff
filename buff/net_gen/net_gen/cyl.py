import numpy as np
from stl import mesh
from hamine.network import Network, Edge, Node, get_track_prob
from mpl_toolkits import mplot3d
from matplotlib import pyplot

def dsik(e, samples=20, Z=0):

    r_start = e.r
    r_end = min([ee.r for ee in e.nodes[1].edges] + [e.r])
    r = (1-Z)*r_start + Z*r_end

    A = np.linspace(0, 1, samples[0]) * 2*np.pi
    X = np.cos(A)
    Y = np.sin(A)

    center = e.nodes[0].pos + e.length * Z * e.d.reshape(1,3)

    pos = center \
    + r * X.reshape(samples+[1]) * e.e1 \
    + r * Y.reshape(samples+[1]) * e.e2

    nor = [-1, 1][Z] * np.ones((pos.shape[0], 1)) * e.d

    faces = np.arange(samples[0])
    faces = np.stack([faces, np.roll(faces,-1), np.ones(samples[0])*samples[0]])
    faces = faces.T.astype(int)

    pos = np.concatenate([pos, center])

    disk = mesh.Mesh(np.zeros(faces.shape[0], dtype=mesh.Mesh.dtype))
    for i, f in enumerate(faces):
        for j in range(3):
            disk.vectors[i][j] = pos[f[j],:]

    return disk


def section(e, samples=[20, 20]):

    Z, A = np.meshgrid(
        np.linspace(0, 1, samples[0]),
        np.linspace(0, 1, samples[1]) * 2*np.pi,
        indexing='ij',
    )
    r_start = e.r
    r_end = min([ee.r for ee in e.nodes[1].edges] + [e.r])
    r = (1-Z)*r_start + Z*r_end
    X = np.cos(A)
    Y = np.sin(A)

    pos = e.nodes[0].pos \
    + e.length*Z.reshape(samples+[1])*e.d.reshape(1,1,3) \
    + r.reshape(samples+[1])*X.reshape(samples+[1])*e.e1.reshape(1,1,3) \
    + r.reshape(samples+[1])*Y.reshape(samples+[1])*e.e2.reshape(1,1,3)

    nor = X.reshape(samples+[1])*e.e1.reshape(1,1,3) + Y.reshape(samples+[1])*e.e2.reshape(1,1,3).reshape(1,1,3)
    
    vertices = pos.reshape(-1,3)
    #create vertices matrix
    # vertices = np.stack([X.reshape(-1), Y.reshape(-1), Z.reshape(-1)], 1)

    I, J = np.meshgrid(
            np.linspace(0, samples[0]-1, samples[0]), 
            np.linspace(0, samples[1]-1, samples[1]),
            indexing='ij'
    )

    ij = np.stack([I,J], 2)
    #aa = np.array()

    # Build triangle |/ indices
    tri_a_p1 = ij[:-1,:]
    tri_a_p2 = np.roll(ij, shift=-1, axis=1)[:-1,:]
    tri_a_p3 = np.roll(ij, shift=-1, axis=0)[:-1,:]

    #convert i,j to single index: i * j_sz + j = [i,j] * [j_sz, 1]
    trns = np.array([samples[1],1]).reshape(2,)
    tri_a_p1 = np.dot(tri_a_p1, trns)
    tri_a_p2 = np.dot(tri_a_p2, trns)
    tri_a_p3 = np.dot(tri_a_p3, trns)

    #create face matrix
    face_a = np.stack([tri_a_p1.reshape(-1), tri_a_p2.reshape(-1), tri_a_p3.reshape(-1)], 1)

    # Build triangle /| indices
    tri_b_p1 = ij[1:,:]
    tri_b_p2 = np.roll(ij, shift=1, axis=1)[1:,:]
    tri_b_p3 = np.roll(ij, shift=1, axis=0)[1:,:]
    #convert i,j to single index: i * j_sz + j
    trns = np.array([samples[1],1]).reshape(2,)
    tri_b_p1 = np.dot(tri_b_p1, trns)
    tri_b_p2 = np.dot(tri_b_p2, trns)
    tri_b_p3 = np.dot(tri_b_p3, trns)

    #create face matrix
    face_b = np.stack([tri_b_p1.reshape(-1), tri_b_p2.reshape(-1), tri_b_p3.reshape(-1)], 1)

    faces = np.concatenate([face_a,face_b]).astype(int)

    cylinder = mesh.Mesh(np.zeros(faces.shape[0], dtype=mesh.Mesh.dtype))
    for i, f in enumerate(faces):
        for j in range(3):
            cylinder.vectors[i][j] = vertices[f[j],:]


    return cylinder


# n0 = Node(pos=np.array([1e-3,2e-3,3e-3]), id=0)
n0 = Node(pos=np.array([0, 0, 0]), id=0)

length = 1e-3
r = 1e-3
d  = np.array([0, 0, 1])
e1 = np.array([1, 0, 0])
e2 = np.array([0, 1, 0])

from hamine.VesselTreeSimple import VesselTree
d, e2 = VesselTree().rotate(d, e1, 20), VesselTree().rotate(e2, e1,20)

#n1 = Node(pos=np.array([1e-3,2e-3,3.1e-3]), id=1)
n1 = Node(pos=n0.pos + length * d, id=1)

e = Edge(r=r, nodes=[n0, n1], id=0)
e.d = d
e.e1 = e2
e.e2 = e1


# Create a new plot
figure = pyplot.figure()
axes = mplot3d.Axes3D(figure)

cylinder = section(e)
axes.add_collection3d(mplot3d.art3d.Poly3DCollection(cylinder.vectors))

disk = dsik(e, samples=[20], Z=1)
axes.add_collection3d(mplot3d.art3d.Poly3DCollection(disk.vectors))

scale = disk.points.flatten()
axes.auto_scale_xyz(scale, scale, scale)

pyplot.show()

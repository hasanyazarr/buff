import matplotlib.pyplot as plt
from mpl_toolkits.mplot3d import Axes3D
import numpy as np
from itertools import count
import plotly.graph_objects as go
from stl import mesh

class Node():
    def __init__(self, pos, id=0):
        self.id = id
        self.pos = pos
        self.edges = set()
        self.pressure = 0

    def __repr__(self):
        return "N:{}".format(self.id)

class Edge():    
    def __init__(self, r=0, nodes=[], id=0):
        self.id = id
        self.r = r
        self.pd = 0
        self.vel = 0
        self.q = 0
        
        self.d  = np.array([0, 0, 1])
        self.e1 = np.array([1, 0, 0])
        self.e2 = np.array([0, 1, 0])

        self.nodes = nodes

    @property
    def length(self):
        if self.nodes:
            return np.linalg.norm(self.nodes[1].pos - self.nodes[0].pos)
        return -1

    @length.setter
    def length(self, value):
        raise Exception('Edge', 'Length cant be set!')

    @length.getter
    def length(self):
        if self.nodes:
            return np.linalg.norm(self.nodes[1].pos - self.nodes[0].pos)
        return -1

    @property
    def dir(self):
        if self.nodes:
            return self.nodes[1].pos - self.nodes[0].pos
        return np.array([0, 0, 0])

    @dir.setter
    def dir(self, value):
        raise Exception('Edge', 'Direction cant be set!')

    @dir.getter
    def dir(self):
        if self.nodes:
            return self.nodes[1].pos - self.nodes[0].pos
        return np.array([0, 0, 0])

    def __repr__(self):
        return "E:{}".format(self.id)

    def sample(self, spatial_freq=1/100e-6):
        """ generates positions for an edge
        """
        m = np.linspace(0, 1, np.ceil(self.length*spatial_freq).astype(np.int64))
        out = self.nodes[0].pos + np.expand_dims(m,-1)*np.expand_dims(self.dir,0)
        return out

    def get_mesh_cylinder(self, samples=[20, 20]):
        Z, A = np.meshgrid(
            np.linspace(0, 1, samples[0]),
            np.linspace(0, 1, samples[1]) * 2*np.pi,
            indexing='ij',
        )
        r_start = self.r
        r_end = min([ee.r for ee in self.nodes[1].edges] + [self.r])
        r = (1-Z)*r_start + Z*r_end
        X = np.cos(A)
        Y = np.sin(A)

        pos = self.nodes[0].pos \
        + self.length*Z.reshape(samples+[1])*self.d.reshape(1,1,3) \
        + r.reshape(samples+[1])*X.reshape(samples+[1])*self.e1.reshape(1,1,3) \
        + r.reshape(samples+[1])*Y.reshape(samples+[1])*self.e2.reshape(1,1,3)

        nor = X.reshape(samples+[1])*self.e1.reshape(1,1,3) + Y.reshape(samples+[1])*self.e2.reshape(1,1,3).reshape(1,1,3)
        
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

    def get_mesh_cap(self, samples=20, Z=0):

        r_start = self.r
        r_end = min([ee.r for ee in self.nodes[1].edges] + [self.r])
        r = (1-Z)*r_start + Z*r_end

        A = np.linspace(0, 1, samples[0]) * 2*np.pi
        X = np.cos(A)
        Y = np.sin(A)

        center = self.nodes[0].pos + self.length * Z * self.d.reshape(1,3)

        pos = center \
        + r * X.reshape(samples+[1]) * self.e1 \
        + r * Y.reshape(samples+[1]) * self.e2

        nor = [-1, 1][Z] * np.ones((pos.shape[0], 1)) * self.d

        faces = np.arange(samples[0])
        faces = np.stack([faces, np.roll(faces,-1), np.ones(samples[0])*samples[0]])
        faces = faces.T.astype(int)

        pos = np.concatenate([pos, center])

        disk = mesh.Mesh(np.zeros(faces.shape[0], dtype=mesh.Mesh.dtype))
        for i, f in enumerate(faces):
            for j in range(3):
                disk.vectors[i][j] = pos[f[j],:]

        return disk

    def random_surface_poins(self, samples=[20]):
        Z = np.random.rand(samples[0], 1)
        A = np.random.rand(samples[0], 1) * 2 * np.pi

        r_start = self.r
        r_end = min([ee.r for ee in self.nodes[1].edges] + [self.r])
        r = (1-Z)*r_start + Z*r_end
        X = np.cos(A)
        Y = np.sin(A)

        pos = self.nodes[0].pos \
        + self.length * Z * self.d \
        + r * X * self.e1 \
        + r * Y * self.e2

        nor = X * self.e1 + Y * self.e2
        
        return pos, nor

    def random_cap_poins(self, samples=[20], Z=0):
        R = np.random.rand(samples[0], 1)
        A = np.random.rand(samples[0], 1) * 2 * np.pi

        r_start = self.r
        r_end = min([ee.r for ee in self.nodes[1].edges] + [self.r])
        r = (1-Z)*r_start + Z*r_end
        r = r * R
        X = np.cos(A)
        Y = np.sin(A)

        pos = self.nodes[0].pos \
        + self.length * Z * self.d \
        + r * X * self.e1 \
        + r * Y * self.e2

        nor = X * self.e1 + Y * self.e2
        
        return pos, nor

class Network():
    def __init__(self):
        self.nodes = []
        self.edges = []

    def plot2(self):
        x = [n.pos[0] for n in self.nodes]
        y = [n.pos[1] for n in self.nodes]
        z = [n.pos[2] for n in self.nodes]
        
        fig = go.Figure()

        for e in self.edges:
            x = np.array([self.nodes[0].pos[0], self.nodes[1].pos[0]])
            y = np.array([self.nodes[0].pos[1], self.nodes[1].pos[1]])
            z = np.array([self.nodes[0].pos[2], self.nodes[1].pos[2]])

            fig.add_trace(
                go.Scatter3d(
                    x=x, y=y, z=z,
                    marker=dict(
                        size=4,
                        color=100,
                        colorscale='Viridis',
                    ),
                    line=dict(
                        color='darkblue',
                        width=2
                    )
                )
            )

        fig.show()

    def plot(self, ax):
        if ax is None:
            fig = plt.figure()
            ax = fig.add_subplot(111, projection='3d')

        x = [n.pos[0] for n in self.nodes]
        y = [n.pos[1] for n in self.nodes]
        z = [n.pos[2] for n in self.nodes]

        #ax.scatter(x,y,z)

        evel = np.array([e.nodes[0].pressure for e in self.edges])
        evel = np.array([e.vel for e in self.edges])
        maxevel = min(evel)
        minevel = max(evel)

        for e in self.edges:
            x = np.array([e.nodes[0].pos[0], e.nodes[1].pos[0]])
            y = np.array([e.nodes[0].pos[1], e.nodes[1].pos[1]])
            z = np.array([e.nodes[0].pos[2], e.nodes[1].pos[2]])
            vel = (e.nodes[0].pressure-minevel)/(maxevel-minevel)
            ax.plot(x, y, z, color=plt.cm.jet(vel), linewidth=6)
        
        # set_axes_equal(ax)
        x_limits = ax.get_xlim3d()
        y_limits = ax.get_ylim3d()
        z_limits = ax.get_zlim3d()

        x_range = abs(x_limits[1] - x_limits[0])
        x_middle = np.mean(x_limits)
        y_range = abs(y_limits[1] - y_limits[0])
        y_middle = np.mean(y_limits)
        z_range = abs(z_limits[1] - z_limits[0])
        z_middle = np.mean(z_limits)

        # The plot bounding box is a sphere in the sense of the infinity
        # norm, hence I call half the max range the plot radius.
        plot_radius = 0.5*max([x_range, y_range, z_range])

        ax.set_xlim3d([x_middle - plot_radius, x_middle + plot_radius])
        ax.set_ylim3d([y_middle - plot_radius, y_middle + plot_radius])
        ax.set_zlim3d([z_middle - plot_radius, z_middle + plot_radius])

    def tracks(self):
        """returns a list of all possible tracks with the ids of the edges
            A track is defined as the path from the start node to an end node
        """

        inout_nodes = [n for n in self.nodes if len(n.edges)==1]
        in_node = inout_nodes[0]
        out_nodes = inout_nodes[1:]
        
        def build_track(curr_node):
            out = []
            prefix = []
            
            # if no bifurcation keep adding to prefix
            while len(curr_node.edges) == 2 or curr_node==in_node:
                for edge in curr_node.edges:
                    if edge.nodes[1] != curr_node:
                        prefix.append(edge)
                        curr_node = edge.nodes[1]
                        break

            # if it is an end
            if curr_node in out_nodes:
                return [prefix]

            # if bifurcation call recursively
            for edge in curr_node.edges:
                # only forward edges
                if edge.nodes[1] == curr_node:
                    continue

                # run on next node
                tracks_nn = build_track(edge.nodes[1])
                for e in tracks_nn:
                    out.append( prefix + [edge] + e )
            
            return out

        return build_track(in_node)
    
    def bounding_box(self):
        min_p = np.array([min(n.pos[d] for n in self.nodes) for d in range(3)])
        max_p = np.array([max(n.pos[d] for n in self.nodes) for d in range(3)])

        box_center = (min_p + max_p)/2
        box_size = max_p - min_p
        return box_center, box_size
    

def get_track_prob(track):
    prob = 1

    for ce, ne in zip(track, track[1:]):
        prob *= ne.q/ce.q

    return prob

def gen_track_scat_pos(track, rad_ppos0, rad_ptheta, axial_pos0, dt, start_edge=0):
    """ generates scatterer positions for a track
    """
    cur_edge = track[start_edge]    
    track_scat_pos = []

    # start position
    cur_pos = cur_edge.nodes[0].pos + axial_pos0 * cur_edge.d \
            + cur_edge.r * rad_ppos0 * np.cos(2*np.pi*rad_ptheta) * cur_edge.e1 \
            + cur_edge.r * rad_ppos0 * np.sin(2*np.pi*rad_ptheta) * cur_edge.e2
    
    for cur_edge, next_edge in zip(track, track[1:] + track[-1:]):

        # Update pos
        walked_len = 0
        while walked_len <= cur_edge.length:
            track_scat_pos.append(cur_pos.copy())
            walked_len += cur_edge.vel * (1-(rad_ppos0)**2) * dt
            cur_pos += cur_edge.d * cur_edge.vel * (1-(rad_ppos0)**2) * dt
            
        
        # calculate the overhshoot distance
        overhshoot = walked_len - cur_edge.length
        
        cur_pos = next_edge.nodes[0].pos + overhshoot * next_edge.vel/cur_edge.vel * next_edge.d \
                + next_edge.r * rad_ppos0 * np.cos(2*np.pi*rad_ptheta) * next_edge.e1 \
                + next_edge.r * rad_ppos0 * np.sin(2*np.pi*rad_ptheta) * next_edge.e2

    return np.vstack(track_scat_pos)
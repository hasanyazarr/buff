import numpy as np
from itertools import count
from .network import Node, Edge, Network
from abc import ABC, abstractmethod

# status: pos, r, v, l, 
class BaseVesselTree(ABC):
    def __init__(self):
        # n_ids 'counts' a unique ID for each node
        self.n_ids = count(0)
        # e_ids 'counts' a unique ID for each edge
        self.e_ids = count(0)
    
    @abstractmethod
    def edge_step_f(self, n, d, e1, e2, r, lvl):
        pass

    @abstractmethod
    def inside_f(self, n, d, e1, e2, r, lvl):
        pass

    @abstractmethod
    def bif_occurs_f(self, n, d, e1, e2, r, lvl):
        pass

    @abstractmethod
    def r_decay_f(self, n, d, e1, e2, r, lvl):
        pass

    @abstractmethod
    def rot_f(self, n, d, e1, e2, r, lvl):
        pass

    @abstractmethod
    def bif_r_decay_f(self, n, d, e1, e2, r, lvl):
        pass

    @abstractmethod
    def bif_rot_f(self, n, d, e1, e2, r, lvl):
        pass

    def rotate_dir(self, d, e1, e2, k, ang):
        """Rotates the whole frame of reference in space, given an axis and angle of rotation according to the right hand rule.

        :param d: main direction, 3 element array of `float` type.
        :type d: ndarray
        :param e1: basis vector (perpendicular to d and e2), 3 element array of `float` type.
        :type e1: ndarray
        :param e2: basis vector (perpendicular to d and e1), 3 element array of `float` type.
        :type e2: ndarray
        :param k: rotation axis, 3 element array of `float` type.
        :type k: ndarray
        :param ang: rotation angle in degrees.
        :type ang: float
        :return: tuple with the three rotated vectors (d, e1, e2), each 3 element array of `float` type.
        :rtype: ndarray
        """
        return self.rotate(d,k,ang), self.rotate(e1,k,ang), self.rotate(e2,k,ang)

    def rotate(self, v, k, ang):
        """rotates a vector in space, given an axis and angle of rotation according to the right hand rule.

        :param v: vector to rotate, 3 element array of `float` type.
        :type v: ndarray
        :param k: rotation axis, 3 element array of `float` type.
        :type k: ndarray
        :param ang: rotation angle in degrees.
        :type ang: float
        :return: rotated vector, 3 element array of `float` type.
        :rtype: ndarray
        """
        # Rodriguez rotation
        ang = np.deg2rad(ang)
        return v * np.cos(ang) + np.cross(k, v)*np.sin(ang) + k*np.dot(k, v)*(1-np.cos(ang))

    def generate(self, p, d, e1, e2, r):
        """Generate vessel tree using initial position, direction and radius

        :param p: initial position, 3 element array of `float` type.
        :type p: ndarray
        :param d: initial direction, 3 element array of `float` type.
        :type d: ndarray
        :param e1: basis vector (perpendicular to d and e2), 3 element array of `float` type.
        :type e1: ndarray
        :param e2: basis vector (perpendicular to d and e1), 3 element array of `float` type.
        :type e2: ndarray
        :param r: initial radius.
        :type r: float
        :return: generated network
        :rtype: hamine.Network
        """
        # normalize
        d = d/np.linalg.norm(d)
        e1 = e1/np.linalg.norm(e1)
        e2 = e2/np.linalg.norm(e2)

        net = Network()

        # create initial node
        n = Node(p, id=next(self.n_ids))
        net.nodes.append(n)

        # recursively generate vessels
        self.generate_vessel(n, d, e1, e2, r, 0, net)

        return net

    def generate_vessel(self, n, d, e1, e2, r, lvl, net):
        nodes = []
        edges = []
        bifs = []

        p = n.pos

        while self.inside_f(n, d, e1, e2, r, lvl):

            # Create the continuation segment
            p = p + d * self.edge_step_f(n, d, e1, e2, r, lvl)

            if not self.inside_f(n, d, e1, e2, r, lvl):
                break
            
            next_n = Node(p, id=next(self.n_ids))
            nodes.append(next_n)
            new_edge = Edge(r, [n, next_n], id=next(self.e_ids))
            new_edge.r = r
            new_edge.d = d
            new_edge.e1 = e1
            new_edge.e2 = e2
            edges.append(new_edge)
            n.edges.add(new_edge)
            next_n.edges.add(new_edge)
            n = next_n

            if self.bif_occurs_f(n, d, e1, e2, r, lvl):
                # apply bifurcation rotation
                d, e1, e2, bif_d, bif_e1, bif_e2 = self.bif_rot_f(n, d, e1, e2, r, lvl)
                # apply bifurcation radius decay
                r, bif_r = self.bif_r_decay_f(n, d, e1, e2, r, lvl)
                bif_lvl, lvl = lvl+1, lvl+1
                bifs.append((n, bif_d, bif_e1, bif_e2, bif_r, bif_lvl))
            else:            
                # apply vessel rotation
                d, e1, e2 = self.rot_f(n, d, e1, e2, r, lvl)
                # apply vessel radius decay
                r = self.r_decay_f(n, d, e1, e2, r, lvl)

            

        # Extend the network
        net.nodes.extend(nodes)
        net.edges.extend(edges)

        for bif_n, bif_d, bif_e1, bif_e2, bif_r, bif_lvl in bifs:
            self.generate_vessel(bif_n, bif_d, bif_e1, bif_e2, bif_r, bif_lvl, net)


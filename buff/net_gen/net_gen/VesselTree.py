import numpy as np
from .BaseVesselTree import BaseVesselTree

class VesselTree(BaseVesselTree):
    def __init__(self):
        super().__init__()
        # range of [-5, 5] degrees for vessel tortuosity in the first axis
        self.vessel_angle1_span = 10
        # range of [-5, 5] degrees for vessel tortuosity in the second axis
        self.vessel_angle2_span = 10
        # range of [10, 90] degrees for angle of bifurcation vs the main axis
        self.bifurcation_angle1_min = 10
        self.bifurcation_angle1_max = 90
        # range of [0, 360] degrees for angle of bifurcation vs the first axis
        self.bifurcation_angle2_min = 10
        self.bifurcation_angle2_max = 90

        self.edge_freq = 1/1e-3
        self.max_lvl = 6
        self.i_pos = np.array([0, 0, 57e-3])
        self.box_sz = np.array([20e-3, 10e-3, 40e-3])

    def edge_step_f(self, n, d, e1, e2, r, lvl):
        # edge step size [m]
        return 1/self.edge_freq

    def inside_f(self, n, d, e1, e2, r, lvl):
        p = n.pos
        return np.all( np.abs(p - self.i_pos) < self.box_sz ) and r > 5e-6 and lvl<self.max_lvl

    def bif_occurs_f(self, n, d, e1, e2, r, lvl):
        #bif_prob = (0.1, 0.075, 0.1, 0.2, 0.25, 0.3, 0.4)[lvl]
        #bif_prob = 0.1 + 0.05*lvl
        bif_prob = 0.1
        bif_occurs = np.random.rand() <= bif_prob
        return bif_occurs

    def r_decay_f(self, n, d, e1, e2, r, lvl):
        return r*0.9

    def rot_f(self, n, d, e1, e2, r, lvl):
        ang1 = (np.random.rand()-0.5) * self.vessel_angle1_span
        ang2 = (np.random.rand()-0.5) * self.vessel_angle2_span

        # rotate over e1
        d, e2 = self.rotate(d, e1, ang1), self.rotate(e2, e1, ang1)

        # rotate over e2
        d, e1 = self.rotate(d, e2, ang2), self.rotate(e1, e2, ang2)

        if np.dot(d,e1)>0.001 or np.dot(d,e2)>0.001 or np.dot(e1,e2)>0.001:
            print("FATAL ERROR!1")

        return d, e1, e2

    def bif_r_decay_f(self, n, d, e1, e2, r, lvl):
        # Murray's law r = r/2**(1/3)                
        # Create bif_r sepaate from normal r
        # solve for murray and for percentage(state)
        bif_r_ratio_span = 0.0
        a = (np.random.rand()-0.5) * bif_r_ratio_span + 0.5
        k = a/(1-a)

        bif_r = r/(k**3+1)**(1/3)
        r = bif_r * k
        return r, bif_r

    def bif_rot_f(self, n, d, e1, e2, r, lvl):

        # rotate angle against main dir
        ang1 = np.random.uniform(low=self.bifurcation_angle1_min, high=self.bifurcation_angle1_max) * (-1)**(np.random.rand()>0.5)
        ang2 = np.random.uniform(low=self.bifurcation_angle2_min, high=self.bifurcation_angle2_max) * (-1)**(np.random.rand()>0.5)

        # rotate over e1
        bif_d, bif_e2 = self.rotate(d, e1, ang1), self.rotate(e2, e1, ang1)

        # rotate over e2
        bif_d, bif_e1 = self.rotate(bif_d, bif_e2, ang2), self.rotate(e1, bif_e2, ang2)

        return d, e1, e2, bif_d, bif_e1, bif_e2

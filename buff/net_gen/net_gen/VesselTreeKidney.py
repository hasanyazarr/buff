import numpy as np
from .VesselTree import VesselTree

class VesselTreeKidney(VesselTree):
    def __init__(self):
        super().__init__()

    def inside_f(self, n, d, e1, e2, r, lvl):
        p = n.pos
        in_ellip = np.sum( ((p - self.i_pos)/ (self.box_sz))**2  ) < 1
        
        return  in_ellip and r > 5e-6 and lvl<9

    def bif_occurs_f(self, n, d, e1, e2, r, lvl):
        #bif_prob = (0.2, 0.3, 0.4, 0.5, 0.6)[lvl]
        bif_prob = 0.3 + 0.075 * lvl**3/16

        bif_prob = np.max( ((n.pos - self.i_pos)/ (self.box_sz)) ) * 2

        bif_occurs = np.random.rand() <= bif_prob
        return bif_occurs

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

    def bif_rot_f(self, n, d, e1, e2, r, lvl):

            # rotate angle against main dir
            # ang1 = np.random.uniform(low=self.bifurcation_angle1_min, high=self.bifurcation_angle1_max) * (-1)**(np.random.rand()>0.5)
            ang2 = np.random.uniform(low=self.bifurcation_angle2_min, high=self.bifurcation_angle2_max) * (-1)**(np.random.rand()>0.5)

            ang1 = self.bifurcation_angle1_min * (8-lvl)*lvl/2 * (-1)**(np.random.rand()>0.5)
            #ang2 = self.bifurcation_angle2_min * lvl * (-1)**(np.random.rand()>0.5)

            # rotate over e1
            bif_d, bif_e2 = self.rotate(d, e1, ang1), self.rotate(e2, e1, ang1)

            # rotate over e2
            bif_d, bif_e1 = self.rotate(bif_d, bif_e2, ang2), self.rotate(e1, bif_e2, ang2)

            return d, e1, e2, bif_d, bif_e1, bif_e2

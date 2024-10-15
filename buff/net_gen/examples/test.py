import numpy as np
import random

import matplotlib.pyplot as plt
from collections import deque

from net_gen.VesselTreeSimple import VesselTree
from net_gen.network import Network, Edge, Node, get_track_prob
from net_gen.flow import solve
from net_gen.outputs import continuous_injection, gen_pv_structure, gen_pv_flow_all, gen_pv_flow_separate, gen_pv_cyl

from BWTree import BWTree

import pickle

# Generate network
i_dir = np.array([0, 0, 1])
e1    = np.array([1, 0, 0])
e2    = np.array([0, 1, 0])
i_r = 1e-3
a = BWTree()

net = a.generate(a.i_pos, i_dir, e1, e2, i_r)

inout_nodes = [n.id for n in net.nodes if len(n.edges)==1]

p_inout = np.zeros(len(net.nodes))
p_inout[0] = 10
#p_inout[inout_nodes[-1]] = 20

solve(net, preset_p=p_inout, preset_idx=inout_nodes, visc=4e-3)

fig = plt.figure()
ax1 = fig.add_subplot(131, projection='3d')
ax2 = fig.add_subplot(132, projection='3d')
ax3 = fig.add_subplot(133, projection='3d')
net.plot(ax1)
ax1.view_init(elev=0, azim=0)
net.plot(ax2)
ax2.view_init(elev=90, azim=0)
net.plot(ax3)
ax3.view_init(elev=0, azim=90)
plt.show()

if 'n' in input("continue?(y/n)"):
    exit()

with open('net_simple.pkl', 'wb') as fid:
    pickle.dump(net, fid, pickle.HIGHEST_PROTOCOL)

# # Continuous Injection
all_tracks = net.tracks()
all_tracks_p = [get_track_prob(t) for t in all_tracks]
ft = continuous_injection(all_tracks, all_tracks_p, 200, 2, 0.002, 2.0)

# # Save
gen_pv_flow_all('out/scat/', ft)
#gen_pv_structure('out/structure/', net)
#gen_pv_flow_separate('out/separate/', ft)
#gen_pv_cyl('out/cyl/', net)






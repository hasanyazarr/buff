import numpy as np
import random

from .network import Node, Edge, Network, get_track_prob, gen_track_scat_pos

def gen_pos_table(scat_pos, scat_id, delay, nframes):
    if nframes == -1:
        nframes = scat_pos.shape[0]
    else:
        nframes = min(nframes-delay, scat_pos.shape[0])

    f_id = np.arange(nframes) + delay
    s_id = np.ones(nframes) * scat_id

    return np.hstack([
        np.expand_dims(f_id, -1), 
        np.expand_dims(s_id, -1), 
        scat_pos[0:nframes, :]])


def continuous_injection(tracks, tracks_p, avg_rate, duration, dt, start_t=0):
    
    duration += start_t
    nframes = int(np.ceil(duration/dt))
    full_table = np.ndarray([0,5])
    t=0
    scat_id = 0

    start_f = int(np.round(start_t/dt))

    while t<duration:

        print(f"%{100*t/duration:.2f}", end='\r')

        # choose a track at random
        chosen_track = random.choices(tracks, weights=tracks_p)[0]

        # sample the track
        # TODO: add random initial axial position 'axial_pos0'
        track_pos = gen_track_scat_pos(
            track=chosen_track, 
            rad_ppos0=0, 
            rad_ptheta=0, 
            axial_pos0=np.random.uniform(0, chosen_track[0].length) , 
            dt=dt, 
            start_edge=0
        )

        # generate position table for track
        delay = int(np.round(t/dt))
        pos_table = gen_pos_table(track_pos, scat_id, delay, nframes)

        # remove until start_t
        pos_table = pos_table[pos_table[:, 0] >= start_f]
        pos_table -= np.array([start_f, 0, 0, 0, 0])

        # add position table to final table
        full_table = np.vstack([full_table, pos_table])

        # time since last event
        t += np.random.exponential(1/avg_rate)
        scat_id+=1

    # sort by f_id
    full_table = full_table[full_table[:, 0].argsort()]

    # make scat_id start from 0
    start_scat_id = np.min(full_table[:,1])
    full_table -=  np.array([0, start_scat_id, 0, 0, 0])

    return full_table


def combine(scats_pos, delays, nframes=-1):
    def gen_table(scat_pos, scat_id, delay, nframes):
        if nframes == -1:
            nframes = scat_pos.shape[0]
        else:
            nframes = min(nframes-delay, scat_pos.shape[0])

        f_id = np.arange(nframes) + delay
        s_id = np.ones(nframes) * scat_id

        return np.hstack([
            np.expand_dims(f_id, -1), 
            np.expand_dims(s_id, -1), 
            scat_pos[0:nframes,:]])

    nscats = len(scats_pos)
    full_table = np.vstack([gen_table(scats_pos[i], i, delays[i], nframes) for i in range(nscats)])
    full_table = full_table[full_table[:, 0].argsort()]  # sort by f_id
    return full_table


def gen_pv_flow_all(out_path, ft, fname='gt_scat.txt'):
    np.savetxt(out_path + fname, ft, fmt='%.18e', delimiter=',', newline='\n', header='f_id,s_id,x,y,z', comments='')


def gen_pv_flow_separate(out_path, ft, fname="separate.txt"):
    minf, maxf = int(min(ft[:,0])), int(max(ft[:,0]))
    ndig = int(np.floor(np.log10(maxf))+1)
    for ff in range(minf, maxf+1):
        np.savetxt(
            out_path + fname.split('.')[0] + f"{ff}".zfill(ndig) + '.' + fname.split('.')[1], 
            ft[ft[:,0]==ff], 
            fmt='%.18e', delimiter=',', newline='\n', header='f_id,s_id,x,y,z', comments=''
        )


def gen_pv_structure(out_path, net, fname='gt_net.txt'):
    out = []
    for e in net.edges:
        pos = gen_track_scat_pos([e], 0, 0, 0, 0.01, start_edge=0)
        d = np.ones((pos.shape[0],1)) * e.d
        r = np.ones(pos.shape[0]) * e.r
        v = np.ones(pos.shape[0]) * e.vel
        out.append(
            np.hstack(
                [
                    pos,
                    d,
                    np.expand_dims(r,-1),
                    np.expand_dims(v,-1),
                ]
            )
        )
    out = np.vstack(out)
    np.savetxt(out_path + fname, out, fmt='%.18e', delimiter=',', newline='\n', header='px,py,pz,dx,dy,dz,r,v', comments='')

def gen_pv_cyl(out_path, net, fname='net_cyl.txt'):
    out = []
    for e in net.edges:
        p0 = e.nodes[0].pos
        p1 = e.nodes[1].pos
        d = e.d
        e1 = e.e1
        e2 = e.e2
        r = e.r
        v = e.vel
        out.append(
            np.hstack(
                [
                    p0,
                    p1,
                    d,
                    e1,
                    e2,
                    r,
                    v,
                ]
            )
        )
    out = np.vstack(out)
    np.savetxt(out_path + fname, out, fmt='%.18e', delimiter=',', newline='\n', header='p0x,p0y,p0z,p1x,p1y,p1z,dx,dy,dz,e1x,e1y,e1z,e2x,e2y,e2z,r,v', comments='')



def combine_tables(tables):
    """Combines multiple tables into a signle one

    :param tables: List of tables to combine
    :type tables: List
    :return: combined table
    :rtype: table
    """
    # number of events in each table
    # TODO: should it be +1?
    n_bubs = [np.max(t[:,1] for t in tables)]

    # offset to add to each bubble id 
    to_add = [0] + n_bubs[:-1]
    to_add = np.cumsum(to_add)
    
    # add bubble id offset to each table
    for t, tadd in zip(tables, to_add):
        t += np.array([0, tadd, 0, 0, 0])

    # stack all tables
    full_table = np.vstack(tables)

    # sort by frame number first
    full_table = full_table[full_table[:, 0].argsort()]

    return full_table


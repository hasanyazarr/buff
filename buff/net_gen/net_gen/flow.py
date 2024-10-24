import numpy as np
import math

def solve(net, preset_p, preset_idx, visc=1e-3):
    """ Solve for flows, pressures and velocities

    :param net: Network
    :type net: Network
    :param preset_p: List of pressures to be pre-set
    :type preset_p: list
    :param preset_idx: List of indices to pre-set the pressure
    :type preset_idx: list
    :param visc: viscosity of the liquid in Pa/s, defaults to 1 mPa/s
    :type visc: float, optional
    """
    # A maps node voltages with edge voltages
    A = np.zeros(shape=(len(net.edges), len(net.nodes)))
    for i, e in enumerate(net.edges):
        na, nb = e.nodes[0].id, e.nodes[1].id
        A[i][na] = -1
        A[i][nb] = 1

    # create inout pressure vector
    v = -np.dot(A, preset_p)
    
    # remove columns corresponding to inout nodes
    A = np.delete(A, preset_idx, 1)

    # K maps edge voltages with edge flows
    K = np.zeros(shape=(len(net.edges), len(net.edges)))

    for i, e in enumerate(net.edges):
        K[i][i] = 1/(8*visc/math.pi*e.length/e.r**4)

    # M*x = b 
    M = np.dot(np.dot(A.T,K),A)
    b = np.dot(np.dot(A.T,K),v)

    # solution
    x = np.dot(np.linalg.inv(M),b)

    # assign node pressures
    x_inx = list(set(range(len(net.nodes))) - set(preset_idx))
    for ni, nv in zip(preset_idx, preset_p):
        net.nodes[ni].pressure = nv
    for ni, nv in zip(x_inx, x):
        net.nodes[ni].pressure = nv

    # assign edge pressures
    e = v - np.dot(A, x)
    for i, ev in enumerate(e):
        net.edges[i].pressure = ev

    # edge volumetric flow and mean velocity
    q = np.dot(K, e)
    for i, eq in enumerate(q):
        net.edges[i].q = eq
        net.edges[i].vel = eq/(math.pi * np.power(net.edges[i].r,2))


        
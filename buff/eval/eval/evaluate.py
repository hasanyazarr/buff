import numpy as np
import matplotlib.pyplot as plt
import scipy.optimize
from .Stats import Stats


def split_by_frames(raw_data):
    i = np.r_[True, raw_data[:,0][:-1]!=raw_data[:,0][1:], True]
    fc = np.diff(np.flatnonzero(i))
    return np.split(raw_data, np.cumsum(fc))[:-1]

def evaluate_frame(gta, gtb, fta, ftb, r = 500e-6):
    # extract ground truth position for frames a and b
    pos_gta = gta[:,2:5]
    pos_gtb = gtb[:,2:5]

    # extract localization position for frames a and b
    pos_fta = fta[:,2:5]
    pos_ftb = ftb[:,2:5]

    # remove y coord
    pos_gta[:,-2] = 0.0
    pos_fta[:,-2] = 0.0
    pos_gtb[:,-2] = 0.0
    pos_ftb[:,-2] = 0.0

    # Localizations inside radius for frame a
    # calcualte the distance between each ground truth to each localization
    Da = np.linalg.norm(
        np.expand_dims(pos_gta, 1)-np.expand_dims(pos_fta, 0), 
        axis=2
    )
    # make inf all distances greater than search radius
    Da[Da>r] = 999.0
    # assign matches that minimize the sum of distances
    Ma = scipy.optimize.linear_sum_assignment(Da)
    Ma = [(i,j) for i,j in zip(*Ma) if Da[i][j]<r]

    # Save localization statistics
    loca_stats = Stats()
    # number of ground truth events
    a_ngt = Da.shape[0]
    # number of user localizations
    a_nft = Da.shape[1]
    loca_stats.TP = len(Ma)
    loca_stats.TP_dists = [Da[mi][mj] for mi, mj in Ma]
    loca_stats.FN = a_ngt - loca_stats.TP
    loca_stats.FP = a_nft - loca_stats.TP

    # localization match dictionaries to transform gt_ix <-> i <-> ft_ix for frame a
    # i -> gt_ix
    Ma_i2g = { i:gta[i,1] for i,_ in Ma}
    # gt_ix -> i
    Ma_g2i = { gta[i,1]:i for i,_ in Ma}
    # i -> ft_ix
    Ma_i2f = { j:fta[j,1] for _,j in Ma}
    # ft_ix -> i
    Ma_f2i = { fta[j,1]:j for _,j in Ma}
    # gt_ix -> ft_ix
    Ma_g2f = { gta[i,1]:fta[j,1] for i,j in Ma}
    # ft_ix -> gt_ix
    Ma_f2g = { fta[j,1]:gta[i,1] for i,j in Ma}

    # set of gt_ix that are correctly matched in frame a
    TPa_gt_ix = set([gta[i,1] for i,_ in Ma])
    # set of ft_ix that are correctly matched in frame a
    TPa_ft_ix = set([fta[j,1] for _,j in Ma])

    # Localizations inside radius for frame b
    # calcualte the distance between each ground truth to each localization
    Db = np.linalg.norm(
        np.expand_dims(pos_gtb, 1) - np.expand_dims(pos_ftb, 0), 
        axis=2
    )
    # make inf all distances greater than search radius
    Db[Db>r] = 999.0
    # assign matches that minimize the sum of distances
    Mb = scipy.optimize.linear_sum_assignment(Db)
    Mb = [(i,j) for i,j in zip(*Mb) if Db[i][j]<r]

    # Save localization statistics
    locb_stats = Stats()
    # number of ground truth events
    b_ngt = Db.shape[0]
    # number of user localizations
    b_nft = Db.shape[1]
    locb_stats.TP = len(Mb)
    locb_stats.TP_dists = [Db[mi][mj] for mi, mj in Mb]
    locb_stats.FP = b_nft - locb_stats.TP
    locb_stats.FN = b_ngt - locb_stats.TP

    # localization match dictionary gt_ix -> ft_ix for frame b
    # localization match dictionaries to transform gt_ix <-> i <-> ft_ix for frame b
    # i -> gt_ix
    Mb_i2g = { i:gtb[i,1] for i,_ in Mb}
    # gt_ix -> i
    Mb_g2i = { gtb[i,1]:i for i,_ in Mb}
    # i -> ft_ix
    Mb_i2f = { j:ftb[j,1] for _,j in Mb}
    # ft_ix -> i
    Mb_f2i = { ftb[j,1]:j for _,j in Mb}
    # gt_ix -> ft_ix
    Mb_g2f = { gtb[i,1]:ftb[j,1] for i,j in Mb}
    # ft_ix -> gt_ix
    Mb_f2g = { ftb[j,1]:gtb[i,1] for i,j in Mb}

    # set of gt_ix that are correctly matched in frame b
    TPb_gt_ix = set([gtb[i,1] for i,_ in Mb])
    # set of ft_ix that are correctly matched in frame b
    TPb_ft_ix = set([ftb[j,1] for _,j in Mb])

    # Pairing frames a and b
    # gt_ix correctly localized in both frame a and b
    gt_pairs = TPa_gt_ix.intersection(TPb_gt_ix)
    # ft_ix correctly localized in both frame a and b
    ft_pairs = TPa_ft_ix.intersection(TPb_ft_ix)

    # all (gt_ix, ft_ix) pairs that have the same associated ft_ix in frame a and b
    true_pos = [(gi, Ma_g2f[gi]) for gi in gt_pairs if Ma_g2f[gi] == Mb_g2f[gi]]
    # all (gt_ix, ft_ixa, ft_ixb) pairs that have the different associated ft_ix in frame a and b
    false_neg = [(gi, Ma_g2f[gi], Mb_g2f[gi]) for gi in gt_pairs if Ma_g2f[gi] != Mb_g2f[gi]]
    # all (ft_ix, gt_ixa, gt_ixb) pairs that have the different associated gt_ix in frame a and b
    false_pos = [(fi, Ma_f2g[fi], Mb_f2g[fi]) for fi in ft_pairs if Ma_f2g[fi] != Mb_f2g[fi]]

    # Save tracking statistics
    track_stats = Stats()

    track_stats.TP = len(true_pos)
    track_stats.FN = len(false_neg)
    track_stats.FP = len(false_pos)
    
    # TP_dist
    track_stats.TP_dists = [
        np.linalg.norm(
            pos_gta[Ma_g2i[g]] - pos_gtb[Mb_g2i[g]]
        )
        for g,_ in true_pos
    ]

    # FN_dist
    track_stats.FN_dists = [
        np.linalg.norm(
            pos_gta[Ma_g2i[g]] - pos_gtb[Mb_g2i[g]]
        )
        for g,_,_ in false_neg
    ]

    # FP_dist
    track_stats.FP_dists = [
        np.linalg.norm(
            pos_fta[Ma_f2i[f]] - pos_ftb[Mb_f2i[f]]
        )
        for f,_,_ in false_pos
    ]

    return loca_stats, locb_stats, track_stats
import numpy as np
from .Stats import Stats
from .evaluate import split_by_frames, evaluate_frame
import argparse

def main(args):
    gt_data = np.loadtxt(
        args.gt_path,
        delimiter=args.delimiter,
        skiprows=args.skiprows,
    )

    ft_data = np.loadtxt(
        args.data_path,
        delimiter=args.delimiter,
        skiprows=args.skiprows,
    )

    # sort user data by frame
    ft_data = ft_data[ft_data[:, 0].argsort()]

    # split into list of frames
    gt_frames = split_by_frames(gt_data)
    ft_frames = split_by_frames(ft_data)

    # Evaluate
    loc_stats = Stats()
    track_stats = Stats()

    # localization search radius
    r = args.search_radius

    # run evaluation for all frames
    for gta, gtb, fta, ftb in zip(gt_frames, gt_frames[1:], ft_frames, ft_frames[1:]):
        a_lstat, b_lstat, tstat = evaluate_frame(gta, gtb, fta, ftb, r)
        loc_stats += a_lstat
        track_stats += tstat

    loc_stats += b_lstat

    print("LOCALIZATION RESULTS")
    print("====================")
    print(f"Total Events:\t\t{loc_stats.gt_events}")
    print(f"True Positives:\t\t{loc_stats.TP}")
    print(f"False Positives:\t{loc_stats.FP}")
    print(f"False Negatives:\t{loc_stats.FN}")
    print(f"Precision:\t\t{loc_stats.precision:.2f}")
    print(f"Recall:\t\t\t{loc_stats.recall:.2f}")

    print(f"Total Error:\t\t{np.sum(loc_stats.TP_dists):.2f} [m]")
    print(f"Mean Error:\t\t{np.mean(loc_stats.TP_dists)*1e6:.2f} [um]")
    print(f"std Error:\t\t{np.std(loc_stats.TP_dists)*1e6:.2f} [um]")

    print("")

    print("TRACKING RESULTS")
    print("====================")
    print(f"N Expected Pairs:\t{track_stats.gt_events}")
    print(f"N Correct Pairs (TP):\t{track_stats.TP}")
    print(f"N Missed Pairs  (FN):\t{track_stats.FN}")
    print(f"N Invented Pairs (FP):\t{track_stats.FP}")

    print(f"Precision:\t\t{track_stats.precision:.2f}")
    print(f"Recall:\t\t\t{track_stats.recall:.2f}")

    print("")

    tp_dist = np.sum(track_stats.TP_dists)
    fp_dist = np.sum(track_stats.FP_dists)
    fn_dist = np.sum(track_stats.FN_dists)

    print(f"Expected Distance:\t{tp_dist+fn_dist:.2f} [m]")
    print(f"TP Distance:\t\t{tp_dist:.2f} [m]")
    print(f"Error Distance:\t\t{fn_dist + fp_dist:.2f} [m]")
    print(f"\tFN Distance:\t{fn_dist:.2f} [m]")
    print(f"\tFP Distance:\t{fp_dist:.2f} [m]")
    print(f"Fraction Correct:\t{tp_dist/(tp_dist+fn_dist):.2f}")
    print(f"dist score:\t\t{(tp_dist -fn_dist -fp_dist)/(tp_dist + fn_dist + fp_dist):.2f}")

    print("")

    print("METRICS")
    print("====================")
    print(f"Localization Precision:\t\t{loc_stats.precision:.2f}")
    print(f"Localization Recall:\t\t{loc_stats.recall:.2f}")
    print(f"Localization Mean Error:\t{np.mean(loc_stats.TP_dists)*1e6:.2f} [um]")
    print(f"Tracking Precision:\t\t{track_stats.precision:.2f}")
    print(f"Tracking Recall:\t\t{track_stats.recall:.2f}")
    print(f"Tracking Score:\t\t\t{(tp_dist -fn_dist -fp_dist)/(tp_dist + fn_dist + fp_dist):.2f}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--gt_path", type=str, required=True, help="Path to the ground truth file")
    parser.add_argument("--data_path", type=str, required=True, help="Path to the file with the data to evaluate")
    parser.add_argument("--delimiter", type=str, default=',', help="Delimiter for the data and gt files")
    parser.add_argument("--skiprows", type=int, default=0, help="Skip header rows in the the data files")
    parser.add_argument("--radius", type=float, default=500e-6, help="Search radius for localization matching")
    args = parser.parse_args()

    main(args)
from dataclasses import dataclass, field
from typing import List

@dataclass
class Stats:
    '''Class for storing localization statistics'''
    TP: int = 0
    TN: int = 0
    FP: int = 0
    FN: int = 0
    TP_dists: List = field(default_factory=lambda: [])
    TN_dists: List = field(default_factory=lambda: [])
    FP_dists: List = field(default_factory=lambda: [])
    FN_dists: List = field(default_factory=lambda: [])

    @property
    def precision(self):
        if self.TP:
            return self.TP/(self.TP + self.FP)
        return 0

    @property
    def gt_events(self):
        return self.TP + self.FN

    @property
    def ft_events(self):
        return self.TP + self.FP

    @property
    def recall(self):
        if self.TP:
            return self.TP/(self.TP + self.FN)
        return 0

    @property
    def jaccard(self):
        if self.TP:
            return self.TP/(self.TP + self.FP + self.FN)
        return 0

    def __repr__(self):
        return (
            f'Total Events:\t\t{self.TP + self.FN}\n'
            f'True Positives:\t\t{self.TP}\n'
            f'False Positives:\t{self.FP}\n'
            f'False Negatives:\t{self.FN}\n'
            f'Precision:\t\t{self.precision:.2f}\n'
            f'Recall:\t\t\t{self.recall:.2f}\n'
        )

    def __add__(self, o):
        out = Stats()
        out.TP = self.TP + o.TP
        out.TN = self.TN + o.TN
        out.FP = self.TP + o.TP
        out.FN = self.FN + o.FN
        out.TP_dists = self.TP_dists + o.TP_dists
        out.TN_dists = self.TN_dists + o.TN_dists
        out.FP_dists = self.TP_dists + o.TP_dists
        out.FN_dists = self.FN_dists + o.FN_dists
    
    def __iadd__(self, o):
        self.TP += o.TP
        self.TN += o.TN
        self.FP += o.FP
        self.FN += o.FN
        self.TP_dists += o.TP_dists
        self.TN_dists += o.TN_dists
        self.FP_dists += o.FP_dists
        self.FN_dists += o.FN_dists
        
        return self
import sys
import numpy as np
from .Stats import Stats
from .evaluate import split_by_frames, evaluate_frame
import traceback
from PyQt5.QtWidgets import (
    QApplication, 
    QLabel, 
    QWidget, 
    QPushButton, 
    QVBoxLayout, 
    QHBoxLayout, 
    QLineEdit, 
    QSpinBox,
    QFileDialog,
    QFormLayout,
    QDialog,
    QCheckBox,
)


class ResultsWindow(QDialog):
    def __init__(self, data):
        super().__init__()
        self.setWindowTitle('Results')
        self.lay_main = QFormLayout()
        for k,v in data:
            self.lay_main.addRow(
                QLabel(k),
                QLabel(v)
            )
        self.setLayout(self.lay_main)


class MainWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.init_ui()
        self.init_clbk()
        self.ft_fname = ''
        self.gt_fname = ''
        self.r = 100e-6

    def btn_go_onclick(self):
        if 1 or self.ft_fname != '' and self.gt_fname != '':
            try:
                gt_delim = self.lne_gt_delimiter.text() if self.chk_gt_delimiter.isChecked() else None
                gt_data = np.loadtxt(
                    self.gt_fname,
                    skiprows=self.spn_gt_skip.value(),
                    delimiter=gt_delim,
                )
                # split into list of frames
                gt_frames = split_by_frames(gt_data)

                ft_delim = self.lne_ft_delimiter.text() if self.chk_ft_delimiter.isChecked() else None
                ft_data = np.loadtxt(
                    self.ft_fname,
                    skiprows=self.spn_ft_skip.value(),
                    delimiter=ft_delim,
                )
                # sort data by frame
                ft_data = ft_data[ft_data[:, 0].argsort()]
                # split into list of frames
                ft_frames = split_by_frames(ft_data)

                # Evaluate
                loc_stats = Stats()
                track_stats = Stats()

                for gta, gtb, fta, ftb in zip(gt_frames, gt_frames[1:], ft_frames, ft_frames[1:]):
                    a_lstat, _, tstat = evaluate_frame(gta, gtb, fta, ftb, float(self.lne_r.text()))
                    loc_stats += a_lstat
                    track_stats += tstat

                # evaluate last frame localizations only
                lstat, _, _ = evaluate_frame(gt_frames[-1], gt_frames[-1], ft_frames[-1], ft_frames[-1], float(self.lne_r.text()))
                loc_stats += a_lstat

                tp_dist = sum(track_stats.TP_dists)
                fp_dist = sum(track_stats.FP_dists)
                fn_dist = sum(track_stats.FN_dists)

                out = [
                    ('LOCALIZATION RESULTS', ''),
                    ('====================', ''),
                    ('Total Events:', f"{loc_stats.gt_events}"),
                    ('True Positives:', f"{loc_stats.TP}"),
                    ('False Positives:', f"{loc_stats.FP}"),
                    ('False Negatives:', f"{loc_stats.FN}"),
                    ('Precision:', f"{loc_stats.precision:.2f}"),
                    ('Recall:', f"{loc_stats.recall:.2f}"),
                    ('Total Error [m]:', f"{sum(loc_stats.TP_dists) :.2f}"),
                    ('Mean Error [um]:', f"{sum(loc_stats.TP_dists)/len(loc_stats.TP_dists) * 1e6:.2f}"),
                    ('', f""),
                    ('TRACKING RESULTS', f""),
                    ('====================', f""),
                    ('N Expected Pairs:', f"{track_stats.gt_events}"),
                    ('N Correct Pairs (TP):', f"{track_stats.TP}"),
                    ('N Invented Pairs (FP):', f"{track_stats.FP}"),
                    ('N Missed Pairs  (FN):', f"{track_stats.FN}"),
                    ('Precision:', f"{track_stats.precision:.2f}"),
                    ('Recall:', f"{track_stats.recall:.2f}"),
                    ('', f""),
                    ('Expected Distance:', f"{tp_dist + fn_dist:.2f} [m]"),
                    ('TP Distance:', f"{tp_dist:.2f} [m]"),
                    ('Error Distance:', f"{fn_dist + fp_dist:.2f} [m]"),
                    ('\tFN Distance:', f"{fn_dist:.2f} [m]"),
                    ('\tFP Distance:', f"{fp_dist:.2f} [m]"),
                    ('dist score:', f"{(tp_dist-fn_dist-fp_dist)/(tp_dist+fn_dist+fp_dist):.2f}"),
                ]
                res = ResultsWindow(out)
                res.exec_()
            except Exception as e:
                print('gtname', self.gt_fname)
                print('gtdelim', self.lne_gt_delimiter.text())
                print('ftname', self.ft_fname)
                print('ftdelim', self.lne_ft_delimiter.text())
                print(traceback.format_exc())

    def chk_ft_delimiter_clbk(self):
        self.lne_ft_delimiter.setEnabled(self.chk_ft_delimiter.isChecked())

    def chk_gt_delimiter_clbk(self):
        self.lne_gt_delimiter.setEnabled(self.chk_gt_delimiter.isChecked())

    def btn_gt_search_onclick(self):
        self.gt_fname = QFileDialog.getOpenFileName(self,
            'Open Ground Truth File', 
            '/home/',
            "Text files (*.txt)"
        )[0]
        
    def btn_ft_search_onclick(self):
        self.ft_fname = QFileDialog.getOpenFileName(self,
            'Open User File', 
            '/home/',
            "Text files (*.txt)"
        )[0]

    def init_clbk(self):
        self.btn_gt_search.clicked.connect(self.btn_gt_search_onclick)
        self.btn_ft_search.clicked.connect(self.btn_ft_search_onclick)
        self.btn_go.clicked.connect(self.btn_go_onclick)
        self.chk_ft_delimiter.clicked.connect(self.chk_ft_delimiter_clbk)
        self.chk_gt_delimiter.clicked.connect(self.chk_gt_delimiter_clbk)

    def init_ui(self):
        self.setWindowTitle("ULTRA-SR Evaluation")

        # divide vertically
        self.lay_vmain = QVBoxLayout()

        # top: divide horizontally
        self.lay_hmain = QHBoxLayout()

        # top, left: divide vertically
        self.lay_gt  = QVBoxLayout()

        # top, left, top: divide horizontally: gtpath, search
        self.lay_gt_file = QHBoxLayout()
        self.lbl_gt_search = QLabel('GT File')
        self.btn_gt_search = QPushButton('Open')
        self.lay_gt_file.addWidget(self.lbl_gt_search)
        self.lay_gt_file.addWidget(self.btn_gt_search)
        self.lay_gt.addLayout(self.lay_gt_file)

        # top, left, mid: divide horizontally: delimiter, txt
        self.lay_gt_delimiter = QHBoxLayout()
        self.lbl_gt_delimiter = QLabel('Delimiter')
        self.lne_gt_delimiter = QLineEdit(' ')
        self.lne_gt_delimiter.setText(',')
        self.chk_gt_delimiter = QCheckBox()
        self.chk_gt_delimiter.setChecked(True)
        self.lay_gt_delimiter.addWidget(self.lbl_gt_delimiter)
        self.lay_gt_delimiter.addWidget(self.lne_gt_delimiter)
        self.lay_gt_delimiter.addWidget(self.chk_gt_delimiter)
        self.lay_gt.addLayout(self.lay_gt_delimiter)

        # top, left, bot: divide horizontally: skip rows, counter
        self.lay_gt_skip = QHBoxLayout()
        self.lbl_gt_skip = QLabel('Skip Rows')
        self.spn_gt_skip = QSpinBox()
        self.lay_gt_skip.addWidget(self.lbl_gt_skip)
        self.lay_gt_skip.addWidget(self.spn_gt_skip)
        self.lay_gt.addLayout(self.lay_gt_skip)

        self.lay_hmain.addLayout(self.lay_gt)

        # top, right: divide vertically
        self.lay_ft  = QVBoxLayout()

        # top, left, top: divide horizontally: gtpath, search
        self.lay_ft_file = QHBoxLayout()
        self.lbl_ft_search = QLabel('User File')
        self.btn_ft_search = QPushButton('Open')
        self.lay_ft_file.addWidget(self.lbl_ft_search)
        self.lay_ft_file.addWidget(self.btn_ft_search)
        self.lay_ft.addLayout(self.lay_ft_file)

        # top, left, mid: divide horizontally: delimiter, txt
        self.lay_ft_delimiter = QHBoxLayout()
        self.lbl_ft_delimiter = QLabel('Delimiter')
        self.lne_ft_delimiter = QLineEdit(' ')
        self.lne_ft_delimiter.setText(',')
        self.lne_ft_delimiter.setEnabled(False)
        self.chk_ft_delimiter = QCheckBox()
        self.lay_ft_delimiter.addWidget(self.lbl_ft_delimiter)
        self.lay_ft_delimiter.addWidget(self.lne_ft_delimiter)
        self.lay_ft_delimiter.addWidget(self.chk_ft_delimiter)
        self.chk_ft_delimiter.setChecked(False)
        self.lay_ft.addLayout(self.lay_ft_delimiter)

        # top, left, bot: divide horizontally: skip rows, counter
        self.lay_ft_skip = QHBoxLayout()
        self.lbl_ft_skip = QLabel('Skip Rows')
        self.spn_ft_skip = QSpinBox()
        self.lay_ft_skip.addWidget(self.lbl_ft_skip)
        self.lay_ft_skip.addWidget(self.spn_ft_skip)
        self.lay_ft.addLayout(self.lay_ft_skip)

        self.lay_hmain.addLayout(self.lay_ft)

        self.lay_vmain.addLayout(self.lay_hmain)

        self.lay_l = QHBoxLayout()
        self.lbl_r = QLabel('Search Radius')
        self.lne_r = QLineEdit('100e-6')

        self.lay_l.addWidget(self.lbl_r)
        self.lay_l.addWidget(self.lne_r)
        
        self.lay_vmain.addLayout(self.lay_l)

        self.btn_go = QPushButton('Go!')
        self.lay_vmain.addWidget(self.btn_go)

        self.setLayout(self.lay_vmain)



if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec_())

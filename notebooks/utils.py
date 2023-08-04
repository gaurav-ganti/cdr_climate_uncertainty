# Thank you Daniel: https://github.com/iiasa/ENGAGE-netzero-analysis/blob/main/assessment/1_categorization.ipynb 
import pyam
import numpy as np

def _cross_threshold(x):
    y = pyam.cross_thresholds(
        x,
        threshold=0.1
    )
    return y[0] if len(y) else np.nan

def calculate_netzero(_df):
    return _df.apply(
        _cross_threshold,
        raw=False,
        axis=1
    )
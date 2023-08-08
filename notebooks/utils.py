# Thank you Daniel: https://github.com/iiasa/ENGAGE-netzero-analysis/blob/main/assessment/1_categorization.ipynb 
import pyam
import numpy as np
import scmdata

def _cross_threshold(x):
    y = pyam.cross_threshold(
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

def assign_peak_and_2100_warming(df):
    """
    Function to append peak and 2100
    warming for a given dataframe
    """
    df = scmdata.ScmRun(
        df
    )
    # Step 1: Cast this to a timeseries
    df_ts = df.timeseries()
    # Step 2: Assign the maximum to the data
    max_values = df_ts.max(axis=1)
    df = df.set_meta(
        dimension='peak_warming',
        value=max_values
    )
    # Step 3: Assign the 2100 value to the data
    values_2100 = df_ts['2100-01-01']
    df = df.set_meta(
        dimension='2100_warming',
        value=values_2100
    )
    # Step 5: Calculate the drawdown
    df = df.set_meta(
        dimension='drawdown',
        value=(
            df.meta.loc[:,'2100_warming']
            -
            df.meta.loc[:,'peak_warming']
        )
    )
    # Step 6: Return the metadata
    return df.meta

def _prep_df_for_subtract(df,cols=None):
    df.set_index(
        [
            'model',
            'scenario',
            'run_id'
        ],
        inplace=True
    )
    if cols:
        return df.loc[:,cols]
    else:
        return df
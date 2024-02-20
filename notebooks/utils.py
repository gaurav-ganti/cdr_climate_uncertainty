# Thank you Daniel: https://github.com/iiasa/ENGAGE-netzero-analysis/blob/main/assessment/1_categorization.ipynb 
import pyam
import numpy as np
import scmdata
import sys
sys.path.append('../scripts')
from cdr import construct_new_cdr_pathway

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

def strip_nz_suffix(df, return_as_ts=True):
    """
    Function to strip out the _NZCO2 suffix
    """
    if isinstance(df, pyam.IamDataFrame):
        df_ts = (
            df
            .timeseries()
            .reset_index()
        )
    else:
        if 'scenario' not in df.columns:
            if 'scenario' in df.index:
                df_ts = df.reset_index()
            else:
                raise ValueError('scenario column not in data')
        else:
            df_ts = df
    # Now proceed to strip out _NZCO2
    df_ts.loc[:,'scenario'] = (
        df_ts
        .loc[:,'scenario']
        .apply(
            lambda x: x.replace(
                '_NZCO2',
                ''
            )
        )
    )
    # Now return this
    if return_as_ts:
        df_return = df_ts
    else:
        df_return = pyam.IamDataFrame(
            df_ts
        )
    return df_return

def assign_warming_levels(df, assign_peak_year=False, include_2015=False):
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
    if assign_peak_year:
        new_ts = (
            df
            .to_iamdataframe()
            .swap_time_for_year()
            .timeseries()
        )
        peak_year = (
            new_ts.apply(
                lambda x: x[x==x.max()].index[0],
                axis=1
            )
        )
        df = df.set_meta(
            dimension='year_peak_warming',
            value=peak_year
        )
    # Step 3: Assign the 2100 value to the data and 2015 if necessary
    values_2100 = df_ts['2100-01-01']
    df = df.set_meta(
        dimension='2100_warming',
        value=values_2100
    )
    if include_2015:
        values_2015 = df_ts['2015-01-01']
        df=df.set_meta(
            dimension='2015_warming',
            value=values_2015
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

def process_cdr_pathway(novel_cdr_compiled, metrics_first_guess, model, scenario, ensemble_member):
    try:
        return construct_new_cdr_pathway(novel_cdr_compiled, metrics_first_guess, model, scenario, ensemble_member)
    except:
        print(model, scenario)

def rebase_temperatures_wg3(raw_temp):
    temp_rebased_init = (
        raw_temp
        .filter(region='World')
        .relative_to_ref_period_mean(
            year=range(1850,1901)
        )
        .drop_meta(["reference_period_start_year", "reference_period_end_year"])
    )
    temp_rebased_final = (
        temp_rebased_init.adjust_median_to_target(
            0.85,
            range(1995, 2015),
            process_over=("run_id",),
        )
    )
    return temp_rebased_final
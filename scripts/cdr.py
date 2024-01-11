import pyam
import pandas as pd

import copy
import math
import numpy as np

import yaml
from pathlib import Path

def compile_novel_cdr_estimates(db, dimensions):
    """
    Compiles novel CDR estimates from a given database.

    Args:
        db (pyam.IamDataFrame): The input database containing CDR data.
        dimensions (dict): Optional dimensions to filter the database.

    Returns:
        pyam.IamDataFrame: The aggregated novel CDR data.
    """
    with open(Path('definitions.yml')) as f:
        defs = yaml.load(f, Loader=yaml.FullLoader)
    print(defs)

    # Step 1: We first want to filter the given database for the necessary novel CDR variables
    if dimensions is None:
        db_novel = (
            db
            .filter(
                variable=defs['novel_cdr_vars']
            )
        )
    else:
        db_novel = (
            db
            .filter(
                variable=defs['novel_cdr_vars'],
                **dimensions
            )
        )
    print(db_novel.variable)
    # Step 2: We now want to aggregate the data to construct a total novel CDR variable
    db_novel_aggregated = (
        db_novel
        .aggregate(
            variable='Carbon Dioxide Removal|Novel',
            components=defs['novel_cdr_vars'],
            append=False
        )
    )
    # Step 3: Return the processed data
    return db_novel_aggregated

def rotate_and_calc_cumulative(scen_data, angle):
    """
    Rotate the scenario data by a given angle and calculate the cumulative values.

    Parameters:
        scen_data (pyam.IamDataFrame): The scenario data to be rotated and calculated.
        angle (float): The angle (in degrees) by which to rotate the data.

    Returns:
        pyam.IamDataFrame: The transformed scenario data with cumulative values.
        pandas.DataFrame: The cumulative values calculated for each time series.

    Raises:
        ValueError: If the 'netzero|CO2' metadata is not present in the scenario data.
        ValueError: If the function is called with more than one scenario.

    """
    if 'netzero|CO2' not in scen_data.meta:
        raise ValueError('The netzero|CO2 metadata is required')
    if len(scen_data.meta.index) > 1:
        raise ValueError('This function only operates on a single scenario')
    # Step 1: Cast the data to a timeseries
    scen_data_ts = scen_data.timeseries()
    nz_year =  scen_data.meta['netzero|CO2'].values[0]
    # Step 2: Get the transformed data
    scen_data_transformed = _shear_transform(
        scen_data_ts,
        nz_year,
        angle
    )
    # Step 3: Cast this to a pyam dataframe
    scen_pyam = pyam.IamDataFrame(scen_data_transformed)
    # Step 4: Calculate the cumulative values
    cumulative = (
        scen_pyam
        .timeseries()
        .apply(
            lambda x: pyam.cumulative(
                x,
                first_year=nz_year,
                last_year=2100
            ),
            axis=1
        )
    )
    return scen_pyam, cumulative

def _shear_transform(data_ts, t_netzero, angle):
    """
    Function to rotate the timeseries data around
    the data at net zero emissions.

    Args:
        data_ts (pd.DataFrame): The input timeseries data to be transformed.
        t_netzero (int): The time at which net zero emissions occur.
        angle (int): The angle of rotation (in degrees).

    Returns:
        type: The transformed timeseries data.
    """
    # Step 1: We first want to calculate the angle in radians
    angle_rad = math.radians(angle)
    # Step 2: We now want to identify the origin
    ox = t_netzero
    # Step 3: Identify the columns to transform
    data_transformed = copy.deepcopy(data_ts)
    cols = [x for x in data_transformed.columns if x>t_netzero]
    for c in cols:
        x_offset = c - ox
        data_transformed.loc[:,c] = (
            x_offset
            * np.tan(angle_rad)
            + data_transformed.loc[:,c]
        )
    # Step 5: Assign the angle to a new column
    data_transformed.loc[:, 'angle'] = angle
    return data_transformed.reset_index()
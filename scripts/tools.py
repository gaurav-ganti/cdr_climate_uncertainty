import pyam
import pandas as pd

from pathlib import Path

def grab_results(ensemble_members, model, scenario, result_path):
    """
    Function to grab results
    """
    failed_runs = []
    if '/' in model:
        model=model.replace('/', '-')
    cdr_string_type=f"CDR_{model}_{scenario}"
    temp_string_type=f"TEMP_{model}_{scenario}"
    cdr_dfs=[]
    temp_dfs=[]
    for i in range(0, ensemble_members):
        try:
            _cdr=pd.read_csv(
                f"{result_path}/{cdr_string_type}_{i}.csv"
            )
            _temp=pd.read_csv(
                f"{result_path}/{temp_string_type}_{i}.csv"
            )
            _cdr['ensemble_member']=i
            _temp['ensemble_member']=i
            cdr_dfs.append(
                pyam.IamDataFrame(_cdr)
            )
            temp_dfs.append(
                pyam.IamDataFrame(_temp)
            )
        except:
            print(i)
            failed_runs.append((i, model, scenario))
    cdr_final=pyam.concat(cdr_dfs)
    temp_final=pyam.concat(temp_dfs)
    return cdr_final, temp_final, failed_runs
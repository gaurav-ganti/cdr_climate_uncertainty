import sys
sys.path.append('../scripts')
from tools import grab_results
import papermill as pm
import pandas as pd
import pyam
import pathlib
from tqdm import tqdm
import os
import dotenv

dotenv.load_dotenv()

def grab_results_all(model_scens):
    temp = []
    cdr = []
    fail = []
    for _, (_, model, scenario) in tqdm(model_scens.iterrows()):
        cdr_scen , temp_scen, fail_scen = grab_results(
            int(sys.argv[1]),
            model, 
            scenario, 
            os.path.join(os.environ['OUTPUT_PATH'], 'results')
        )
        temp.append(temp_scen)
        cdr.append(cdr_scen)
        if fail_scen is not None:
            for x in fail_scen:
                fail.append(x)
    temp_compiled = pyam.concat(temp)
    cdr_compiled = pyam.concat(cdr)
    temp_compiled.swap_time_for_year(inplace=True)
    #failed_to_hit_1p5 = temp_compiled.validate(
    #    upper_bound=1.55,
    #    year=2100,
    #    exclude_on_fail=True
    #)
    failed_to_hit_1p5 = temp_compiled.validate(
        criteria={
            temp_compiled.variable[0]:{'up': 1.55, 'year':2100}
        }
    )
    try:
        for index, row in failed_to_hit_1p5.iterrows():
            fail.append(
                (row['ensemble_member'], row['model'], row['scenario'])
            )
    except:
        print('None failed to hit 1.5')
    return cdr_compiled, temp_compiled, fail

if __name__=='__main__':
    scen_names = pd.read_csv(
        pathlib.Path(
            "../data/100_scenario_names.csv"
        ),
        header=None
    )
    cdr, temp, fail = grab_results_all(
        scen_names    
    )
    cdr.to_csv('../data/405_cdr.csv')
    temp.to_csv('../data/405_temp.csv')
    pd.DataFrame(fail).to_csv('../data/405_final.csv', header=False)
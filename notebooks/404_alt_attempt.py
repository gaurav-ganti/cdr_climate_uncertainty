import sys
sys.path.append('../scripts')
from tools import grab_results
import papermill as pm
import pandas as pd
import pyam

import dotenv
import pathlib
import time
import os

from tqdm import tqdm
from itertools import islice
import concurrent.futures

# Deal with logging
import logging
import datetime
logger = logging.getLogger(__name__)

# Properties of the logging file
current_datetime = (
    datetime
    .datetime
    .now()
    .strftime('%Y-%m-%d_%H-%M')
)   

fh = logging.FileHandler(f'logging/{current_datetime}_404_runs.log')
logger.addHandler(fh)

# Deal with the paths and load the environment file
dotenv.load_dotenv()
os.environ['MAGICC_WORKER_NUMBER']='1'
current_path=pathlib.Path().resolve()
OUTPUT_PATH=os.environ['OUTPUT_PATH']

# Construct and batch the configuration files
def construct_and_batch_configs(mod_scens, batch_size):
    logger.info(
        f'Step 1: Constructing and batching {len(mod_scens)} configs with batch size {batch_size}'
    )
    configs=[]
    for row, value in mod_scens.iterrows():
        for i in range(0, int(sys.argv[1])):
            configs.append({
                'ENSEMBLE_MEMBER':i,
                'MODEL':value[1],
                'SCENARIO':value[2]
            })
    iterator=iter(configs)
    while batch := list(islice(iterator, batch_size)):
        yield batch
# Function to run a single papermill notebook
def run_papermill_notebook(config):
    if '/' in config['MODEL']:
        OUTPUT_MODEL=config['MODEL'].replace('/', '-')
    else:
        OUTPUT_MODEL=config['MODEL']
    pm.execute_notebook(
        pathlib.Path(current_path /'403_iterate_for_cdr.ipynb'),
        f"{OUTPUT_PATH}/papermill_output/403_{config['ENSEMBLE_MEMBER']}_{OUTPUT_MODEL}_{config['SCENARIO']}.ipynb",
        parameters=config
    )
# Function to habdle the parallel execution of the papermill notebooks
# Thank you: https://danshiebler.com/2016-09-14-parallel-progress-bar/
def parallel_process(conf_batch, n_jobs=16, front_num=3):
    if front_num > 0:
        front = [run_papermill_notebook(conf) for conf in conf_batch[:front_num]]
    with concurrent.futures.ProcessPoolExecutor(max_workers=n_jobs) as pool:
        futures = [
            pool.submit(
                run_papermill_notebook,
                conf
            )
            for conf in conf_batch[front_num:]
        ]
    for f in tqdm(concurrent.futures.as_completed(futures), total=len(futures)):
        pass
    out = []
    #Get the results from the futures. 
    for i, future in tqdm(enumerate(futures)):
        try:
            out.append(future.result())
        except Exception as e:
            out.append(e)
    #pool.shutdown()
    return front + out
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
    failed_to_hit_1p5 = temp_compiled.validate(
        upper_bound=1.55,
        year=2100,
        exclude_on_fail=True
    )
    try:
        for index, row in failed_to_hit_1p5.iterrows():
            fail.append(
                (row['ensemble_member'], row['model'], row['scenario'])
            )
    except:
        print('None failed to hit 1.5')
    return cdr_compiled, temp_compiled, fail

if __name__=="__main__":
    start_time = datetime.datetime.now().isoformat()
    logger.info(f'Starting runs at: {start_time}')
    mod_scens=pd.read_csv(
        pathlib.Path(
            "../data/100_scenario_names.csv"
        ),
        header=None
    )
    confs=construct_and_batch_configs(mod_scens, int(sys.argv[2]))
    logger.info('Config batching successful')
    counter = 1
    for conf in tqdm(confs):
        logger.info(f'Running batch no: {counter}')
        parallel_process(conf, n_jobs=int(sys.argv[3]), front_num=3)
        counter += 1
    logger.info('First runs complete')
    time.sleep(2)
    scen_names = pd.read_csv(
        pathlib.Path(
            "../data/100_scenario_names.csv"
        ),
        header=None
    )
    cdr, temp, fail = grab_results_all(
        scen_names    
    )
    first_runs_finish = datetime.datetime.now().isoformat()
    logger.info(f'First runs finished at: {first_runs_finish}')
    logger.info(f'{len(fail)} failed to run')

    # Decide how many re runs we want
    re_run_max = 10
    re_run_counter = 1
    while len(fail) > 0:
        if re_run_counter > re_run_max:
            logger.info(f'Exceeded maximum number of re-runs: {re_run_max}')
            break
        logger.info(f'Starting re-run number: {re_run_counter} for {len(fail)} failed runs')
        fail_as_config = [
            {
                'ENSEMBLE_MEMBER':x[0],
                'MODEL':x[1],
                'SCENARIO':x[2]
            }
            for x in fail
        ]
        parallel_process(fail_as_config, n_jobs=20, front_num=5)
        time.sleep(2)
        cdr, temp, fail = grab_results_all(scen_names )
    logger.info('Writing results to file')
    cdr.to_csv('../data/404_cdr.csv')
    temp.to_csv('../data/404_temp.csv')
    complete_time = datetime.datetime.now().isoformat()
    logger.info(f'Runs complete at: {complete_time}')
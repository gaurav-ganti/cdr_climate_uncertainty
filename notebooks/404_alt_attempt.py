import sys
import papermill as pm
import pandas as pd
import dotenv
import pathlib
import time
import os

from tqdm import tqdm
from itertools import islice
import concurrent.futures

# Deal with the paths and load the environment file
dotenv.load_dotenv()
os.environ['MAGICC_WORKER_NUMBER']='1'
current_path=pathlib.Path().resolve()
OUTPUT_PATH=os.environ['OUTPUT_PATH']

# Construct and batch the configuration files
def construct_and_batch_configs(mod_scens, batch_size):
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
    return front + out

if __name__=="__main__":
    mod_scens=pd.read_csv(
        pathlib.Path(
            "../data/100_scenario_names.csv"
        ),
        header=None
    )
    confs=construct_and_batch_configs(mod_scens, int(sys.argv[2]))
    for conf in tqdm(confs):
        parallel_process(conf, n_jobs=int(sys.argv[3]), front_num=3)
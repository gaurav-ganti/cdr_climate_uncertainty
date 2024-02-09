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
current_path=pathlib.Path().resolve()
OUTPUT_PATH=os.environ["OUTPUT_PATH"]

# Construct the necessary configurations
def _construct_configs():
    configs=[]
    # This line is just for testing
    #models_and_scenarios=pd.DataFrame(
    #    index=[0],
    #    columns=['i', 'model', 'scenario'],
    #    data=[
    #        [0, 'REMIND-MAgPIE 2.1-4.3', 'DeepElec_SSP2_ HighRE_Budg900'],
    #    ]
    #)
    models_and_scenarios=pd.read_csv(
        pathlib.Path(
            "../data/100_scenario_names.csv"
        ),
        header=None
    )
    for row, value in models_and_scenarios.iterrows():
        print(value)
        for i in range(0, int(sys.argv[1])):
            configs.append(
                {
                    'ENSEMBLE_MEMBER':i,
                    'MODEL':value[1],
                    'SCENARIO':value[2]
                }
            )
    return configs

def batch_configs(config_list, batch_size):
    """
    Thank you: https://stackoverflow.com/questions/8290397/how-to-split-an-iterable-in-constant-size-chunks 
    """
    iterator=iter(config_list)
    while batch := list(islice(iterator, batch_size)):
        yield batch

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

def main():
    configs=_construct_configs()
    config_batches=batch_configs(configs, int(sys.argv[2]))

    with concurrent.futures.ProcessPoolExecutor() as executor:
        for batch in config_batches:
            futures = [
                executor.submit(
                    run_papermill_notebook,
                    config
                )
                for config in batch
            ]
            for i, future in tqdm(
                enumerate(
                    concurrent.futures.as_completed(futures)
                ),
                total=len(futures)
            ):
                print(i)
    executor.shutdown()
if __name__=="__main__":
    main()
    
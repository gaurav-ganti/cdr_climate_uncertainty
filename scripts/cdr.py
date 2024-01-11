import pyam
import pandas as pd
import yaml
from pathlib import Path

def compile_novel_cdr_estimates(db, dimensions):
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
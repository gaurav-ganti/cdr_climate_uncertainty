# Fair CDR obligations under climate uncertainty

This repository accompanies the paper:
> Ganti, G., Pelz, S., Klönne, U., Gidden, M.J., Schleussner, C.-F.S., Nicholls, Z., Fair carbon removal obligations under climate uncertainty. DOI:

## Data and citations

To replicate the analysis here, you will need the following datafiles. Please update the file paths in the `env.sample` file we have provided and rename it to `.env`.

## Data references
> Meinshausen, M., Meinshausen, N., Hare, W., Raper, S. C. B., Frieler, K., Knutti, R., Frame, D. J., & Allen, M. R. (2009). Greenhouse-gas emission targets for limiting global warming to 2 °C. Nature, 458(7242), 1158–1162. https://doi.org/10.1038/nature08017

> Meinshausen, M., Nicholls, Z. R. J., Lewis, J., Gidden, M. J., Vogel, E., Freund, M., Beyerle, U., Gessner, C., Nauels, A., Bauer, N., Canadell, J. G., Daniel, J. S., John, A., Krummel, P. B., Luderer, G., Meinshausen, N., Montzka, S. A., Rayner, P. J., Reimann, S., … Wang, R. H. J. (2020). The shared socio-economic pathway (SSP) greenhouse gas concentrations and their extensions to 2500. Geoscientific Model Development, 13(8), 3571–3605. https://doi.org/10.5194/gmd-13-3571-2020

> Meinshausen, M., Raper, S. C. B., & Wigley, T. M. L. (2011). Emulating coupled atmosphere-ocean and carbon cycle models with a simpler model, MAGICC6 – Part 1: Model description and calibration. Atmospheric Chemistry and Physics, 11(4), 1417–1456. https://doi.org/10.5194/acp-11-1417-2011

> Riahi, K. et al. Mitigation pathways compatible with long-term goals. in IPCC, 2022: Climate Change 2022: Mitigation of Climate Change. Contribution of Working Group III to the Sixth Assessment Report of the Intergovernmental Panel on Climate Change (eds. Shukla, P. R. et al.) (Cambridge University Press, 2022). doi:10.1017/9781009157926.005.

> Byers, E. et al. AR6 Scenarios Database. (2022) doi:10.5281/zenodo.5886912.

## Installation

We have provided an `environment.yml` file to help set up a dedicated `python` environment to run this analysis. To set it up, run the following in your command line:
```
conda env create --file environment.yml
conda activate cdr_climate_uncertainty
```

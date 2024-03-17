# Replication archive for: "Delaying Carbon Debt Drawdown Fails Younger Generations"

# Contact for clarifications: [ANONYMISED]       

# Script contents: Evaluate assessed scenarios

# LOAD PACKAGES ----------------------------------------------------------------

#install.packages("pacman")
library(pacman)

# processing
p_load(dplyr, tidyr, readr, readxl, writexl, purrr, ggplot2, forcats, stringr, 
       patchwork)

# misc
p_load(here, countrycode, zoo)

# options
options(scipen = 999)

# COUNTRY NAMES AND REGIONAL GROUPING ------------------------------------------

# Determine country-years for analysis
iso3c_tbl <- read_csv(here("Data", "countrygroups", "iso3c_region_mapping.csv")) %>% 
  select(country.name, iso3c, r10 = iamc_r10) %>% 
  group_by(country.name, iso3c, r10) %>% 
  expand(year = 1850:2050) %>% 
  ungroup()

# Set consistent r10 ordering
r10order <- tibble(r10 = c("NAM", "EUR", "PAO", "FSU", "MEA", "EAS", "LAM", "PAS", "AFR", "SAS"),
                   r10label = c("R10NORTH_AM", "R10EUROPE", "R10PAC_OECD", "R10REF_ECON", "R10MIDDLE_EAST", "R10CHINA+", "R10LATIN_AM", "R10REST_ASIA", "R10AFRICA", "R10INDIA+"),
                   r10labellong = c("North America", "Europe", "Asia-Pacific Developed",
                                    "Eastern Europe and West-Central Asia", "Middle East", "Eastern Asia",
                                    "Latin America and Caribbean", "South-East Asia and developing Pacific",
                                    "Africa", "Southern Asia"))

# Adjust labels to reflect those for publication
iso3c_tbl <- iso3c_tbl %>% 
  left_join(r10order) %>% 
  select(country.name, iso3c, r10, r10label, r10labellong, year)

# PROCESSED DATA ---------------------------------------------------------------

r10_rcb19902020 <- read_csv(here("data", "equity_data", "processed", "r10_rcb19902020.csv")) %>% 
  select(r10, year, category, gtco2_hist = gtco2, rcb) %>% 
  left_join(r10order)

# SCENARIO DATA ----------------------------------------------------------------

co2ffi_paths <- read_csv(here("data", "pathways", "305_equity_input.csv")) %>% 
  filter(Variable != "Population") %>% 
  pivot_longer(cols = matches("\\d{4}"), names_to = "year", values_to = "gtco2_path") %>%
  mutate(gtco2_path = gtco2_path / 10^3,
         year = as.numeric(year)) %>% 
  filter(year >= 2025) %>% 
  select(model = Model, scen = Scenario, r10 = Region, year, gtco2_path)

novelcdr_paths <- read_csv(here("data", "pathways", "404_cdr.csv")) %>% 
  pivot_longer(cols = matches("\\d{4}"), names_to = "year", values_to = "gtcdr") %>% 
  mutate(gtcdr = gtcdr / 10^3,
         year = as.numeric(year)) %>% 
  filter(year >= 2025) %>% 
  select(model = Model, scen = Scenario, angle = Angle, ensemble_member = Ensemble_Member, year, gtcdr)

# COMBINE HISTORICAL AND MODELLED EMISSIONS PATHWAYS ---------------------------

co2ffi_paths_hist <- list(co2ffi_paths %>%  mutate(category = "1_PP1990"),
                          co2ffi_paths %>% mutate(category = "2_PP1850")) %>% 
  reduce(bind_rows) %>% 
  # To discuss how to address novel CDR / emissions in this catchall region
  filter(r10 != "R10ROWO") %>% 
  group_by(model, scen, r10, category) %>% 
  complete(year = 1990:2100) %>% 
  left_join(r10_rcb19902020 %>% select(r10 = r10label, category, year, gtco2_hist, rcb)) %>% 
  arrange(model, scen, r10, category, year) %>% 
  mutate(gtco2 = ifelse(year < 2025, gtco2_hist, gtco2_path)) %>% 
  group_by(model, scen, category, r10) %>% 
  mutate(gtco2_interp = zoo::na.approx(gtco2)) %>% 
  # Remove novel CDR (placeholder until Gaurav provides R10 novel CDR paths)
  mutate(gtco2_interp_nocdr = ifelse(gtco2_interp < 0, 0, gtco2_interp)) %>% 
  mutate(gtco2_interp_nocdr_cmltv = cumsum(gtco2_interp_nocdr),
         rcb_interp = rcb[year == 1990] - lag(gtco2_interp_nocdr_cmltv, default = 0))

# Visualise
co2ffi_paths_hist %>% 
  filter(category == "1_PP1990", model == "REMIND 2.1") %>% 
  ggplot(aes(year, rcb_interp, colour = r10)) +
  geom_line() +
  facet_wrap(model~scen)

# DETERMINE CARBON DEBT AT GLOBAL NET-ZERO CO2 ---------------------------------

# At present, we determine total carbon debt in year 2100, having removed novel CDR
cdebt <- co2ffi_paths_hist %>% 
  filter(year == 2100) %>% 
  mutate(debt = ifelse(rcb_interp < 0, -rcb_interp, 0)) %>% 
  select(model, scen, category, r10, debt) %>% 
  group_by(model, scen, category) %>% 
  mutate(debtshare = debt / sum(debt)) %>% 
  arrange(model, scen, category, r10)

# ASSIGN GLOBAL CUMULATIVE NOVEL CDR BY DEBT SHARE -----------------------------

novelcdr_resp <- left_join(cdebt, 
                           novelcdr_paths %>% 
                             group_by(model, scen, angle, ensemble_member) %>% 
                             summarise(gtcdr = sum(gtcdr))) %>% 
  mutate(gtcdr_resp = debtshare * gtcdr)

novelcdr_resp %>% 
  filter(category == "1_PP1990", model == "REMIND 2.1", gtcdr_resp > 0, angle == min(angle)) %>% 
  ggplot(aes(gtcdr_resp, fill = r10)) +
  geom_density() +
  facet_wrap(model ~ scen, scales = "free")






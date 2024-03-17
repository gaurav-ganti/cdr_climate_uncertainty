# Replication archive for: 

# Contact for clarifications: [ANONYMISED]       

# Script contents: Determine remaining carbon budgets from the beginning of 2023.

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

# HISTORICAL CUMULATIVE EMISSIONS GCP (1850-1989) ------------------------------

# Historical production-based CO2-FFI emissions - Global Carbon Budget 2023
# https://zenodo.org/records/10177738
hist_prodco2 <- read_csv(here("data", "equity_data",
                               "GCB2023v36_MtCO2_flat.csv")) %>% 
  # Data provided in million tonnes of CO2 per year, convert to GtCO2
  transmute(iso3c = `ISO 3166-1 alpha-3`, year = Year, CO2 = Total * 1e-3) %>% 
  right_join(iso3c_tbl %>% filter(year >= 1850, year <= 1989), 
                              by = c("iso3c", "year")) %>% 
  filter(year >= 1850, year <= 1989)

# Check which iso3c are missing in GCB emissions data
miss_hist_prodco2 <- hist_prodco2 %>% 
  group_by(iso3c, country.name) %>% 
  summarise(n_total = n(),
            n_missing = sum(is.na(CO2)))

# Determine cumulative emissions 1850-1989
hist_prodco2 <- hist_prodco2 %>% 
  filter(!iso3c %in% 
           (miss_hist_prodco2 %>% filter(n_total == n_missing) %>% pull(iso3c))) %>% 
  group_by(iso3c) %>% 
  summarise(gtco2_18501989 = 
              sum(ifelse(year >= 1850 & year <= 1989, CO2, NA_real_), na.rm = T)) %>% 
  left_join(iso3c_tbl %>% distinct(iso3c, r10, country.name)) %>% 
  ungroup() %>% 
  select(country.name, iso3c, r10,  gtco2_18501989)

# RECENT CUMULATIVE EMISSIONS (GCP) (1990-2022) --------------------------------

# Recent production-based CO2-FFI emissions - Global Carbon Budget 2022
# https://www.icos-cp.eu/science-and-impact/global-carbon-budget/2022
recent_prodco2 <- read_csv(here("data", "equity_data",
                                "GCB2023v36_MtCO2_flat.csv")) %>% 
  # Data provided in million tonnes of CO2 per year, convert to GtCO2
  transmute(iso3c = `ISO 3166-1 alpha-3`, year = Year, gtco2 = Total * 1e-3) %>% 
  right_join(iso3c_tbl %>% filter(year >= 1990, year <= 2022), 
                              by = c("iso3c", "year")) %>% 
  filter(year >= 1990, year <= 2022)

# Check which iso3c are missing in GCB emissions data in each year
miss_recent_prodco2 <- recent_prodco2 %>% 
  group_by(iso3c, country.name) %>% 
  summarise(n_total = n(),
            n_missing = sum(is.na(gtco2)))

# Determine cumulative emissions 1990-2022
recent_prodco2 <- recent_prodco2 %>% 
  filter(!iso3c %in% 
           (miss_recent_prodco2 %>% filter(n_total == n_missing) %>% pull(iso3c))) %>% 
  select(iso3c, country.name, year, gtco2) %>% 
  group_by(iso3c, country.name) %>% 
  mutate(gtco2_cmltv = cumsum(gtco2))  %>% 
  left_join(iso3c_tbl %>% filter(year >= 1990, year <= 2022), 
             by = c("iso3c", "year", "country.name")) %>% 
  ungroup()

# HISTORICAL (OWID) AND PROJECTED POPULATION (IIASA WIC SSP2) ------------------

# Historical population 1850-2019 (OWID)
hist_pop <- read_csv(here("Data", "equity_data", "population.csv")) %>% 
  select(iso3c = Code, year = Year, pop = `Population (historical estimates)`) %>% 
  filter(year >= 1850, year <= 2019)

# Future population projections 2025-2100 (IIASA SSP2) 
popssp2 <- read_csv(here("data", "equity_data", 
                         "SspDb_country_data_2013-06-12.csv")) %>%
  filter(MODEL == "IIASA-WiC POP", SCENARIO %in% c("SSP2_v9_130115"), 
         VARIABLE == "Population") %>% 
  select(iso3c = REGION, `2025`, `2030`, `2035`,`2040`, `2045`,`2050`,
         `2060`, `2070`, `2080`, `2090`, `2100`) %>% 
  mutate(across(-c(iso3c), ~ . * 1e6))  %>% 
  pivot_longer(-c(iso3c), names_to = "year", values_to = "pop") %>% 
  mutate(year = as.numeric(year)) 

# ADD SSP data points (2025, 2030, 2035, ..., 2100)
projected_pop <- 
  rbind(hist_pop %>% 
          select(iso3c, year, pop) %>% 
          filter(iso3c %in% unique(popssp2$iso3c)), popssp2) %>% 
  arrange(iso3c, year) 

# Interpolate
projected_pop <- projected_pop %>% 
  arrange(iso3c, year) %>% 
  group_by(iso3c) %>% 
  complete(year = c(1850:2100)) %>% 
  group_by(iso3c) %>% 
  mutate(pop = round(zoo::na.approx(pop, maxgap = 50)))
  
# Create full dataset, making missing iso3c explicit
projected_pop <- projected_pop %>% 
  full_join(iso3c_tbl %>% distinct(iso3c, country.name, r10), by = c("iso3c"))

# Determine missing countries
miss_projected_pop <- projected_pop %>% 
  group_by(iso3c, country.name) %>% 
  summarise(n_total = n(),
            n_missing = sum(is.na(pop)))

# DETERMINE SET OF COUNTRIES WITH COMPLETE DATA --------------------------------

iso3c_analysis <- list(miss_hist_prodco2 %>% filter(n_total != n_missing), 
                       miss_recent_prodco2 %>%  filter(n_total != n_missing),
                       miss_projected_pop %>% filter(n_total != n_missing)) %>% 
  reduce(inner_join, by = c("iso3c")) %>% pull(iso3c)

hist_prodco2 <- hist_prodco2 %>% filter(iso3c %in% iso3c_analysis)
recent_prodco2 <- recent_prodco2 %>% filter(iso3c %in% iso3c_analysis)
projected_pop <- projected_pop %>% filter(iso3c %in% iso3c_analysis)

# Write to file for later use
hist_prodco2 %>% 
  arrange(r10, iso3c) %>% 
  write_csv(here("data", "equity_data", "processed", "iso3c_emiss18501989gtco2.csv"))

# Write to file for later use
recent_prodco2 %>% 
  arrange(r10, iso3c, year) %>% 
  write_csv(here("Data", "equity_data", "processed", "iso3c_emiss19902022gtco2.csv"))

# Write to file for later use
projected_pop %>%
  filter(!iso3c %in% 
           (miss_projected_pop %>% filter(n_total == n_missing) %>% pull(iso3c))) %>% 
  arrange(r10, iso3c, year) %>% 
  write_csv(here("data", "equity_data", "processed", "iso3c_popssp218502100.csv"))

# SET REMAINING CARBON BUDGETS -------------------------------------------------

# From 2020 with a temperature target of 1.5C with a likelihood of 50%, using the
# updated 2023 value (247Gt) from Lamboll et al (2023) https://doi.org/10.1038/s41558-023-01848-5, 
# and adding CO2-FFI emissions from 2020-2022,
# from Friedlingstein et al (2023), https://doi.org/10.5194/essd-15-5301-2023). 
rcb2020_nz = 247 + round(pull(recent_prodco2 %>% filter(year %in% 2020:2022) %>% 
                                summarise(gtco2 = sum(gtco2, na.rm = T))),2)

# From 1990 to net zero, adding CO2-FFI emissions from 1990-2019,
# from Friedlingstein et al (2023), https://doi.org/10.5194/essd-15-5301-2023).  
rcb1990_nz = round(pull(recent_prodco2 %>% filter(year %in% 1990:2019) %>% 
                          summarise(gtco2 = sum(gtco2, na.rm = T))),2) + rcb2020_nz

# From 1850 to net zero, adding CO2-FFI emissions from 1850-1989,
# from Friedlingstein et al (2023), https://doi.org/10.5194/essd-15-5301-2023).  
rcb1850_nz = round(sum(hist_prodco2$gtco2_18501989),2) + rcb1990_nz

# Write these to file for later use
write_csv(tibble(rcb = c("rcb2020_nz", "rcb1990_nz", "rcb1850_nz"),
                 gtco2 = c(rcb2020_nz, rcb1990_nz, rcb1850_nz)),
          here("data", "equity_data", "processed", "rcbquantities.csv"))

# ALLOCATIONS OVER TIME (1990-2020) --------------------------------------------

# Create dummy data frame
rcb19902020 <- tibble(.rows = 0)

# Prepare analysis dataset
alloc_dataset <- list(miss_recent_prodco2 %>%  filter(n_total != n_missing),
                          miss_hist_prodco2 %>% filter(n_total != n_missing),
                          miss_projected_pop %>% filter(n_total != n_missing)) %>% 
  reduce(inner_join, by = c("iso3c")) %>% 
  select(iso3c) %>% 
  left_join(
    projected_pop %>% 
      group_by(iso3c) %>% 
      summarise(pop_18502050 = sum(pop, na.rm = T),
                pop_19902050 = sum(ifelse(year >= 1990 & year <= 2050, pop, NA_real_), na.rm = T))) %>% 
  ungroup() %>% 
  left_join(hist_prodco2 %>% select(iso3c, gtco2_18501989))

# Loop over years 1990-2020, determining the RCB at each year
for(curr_year in 1990:2020) {
  
  iso3_analysis_loop <- 
    left_join(
      alloc_dataset,
      recent_prodco2 %>% 
        filter(year == curr_year - 1) %>% 
        select(iso3c, gtco2_cmltv)) %>% 
    left_join(
      projected_pop %>% 
        summarise(cmltv_pop1990_curryear = sum(ifelse(year >= 1990 & year <= curr_year, pop, NA_real_), na.rm = TRUE))) %>% 
    select(iso3c, pop_19902050, pop_18502050, gtco2_cmltv, gtco2_18501989) %>% 
    # For the year 1990
    mutate(gtco2_cmltv = ifelse(is.na(gtco2_cmltv), 0, gtco2_cmltv))
  
  iso3_analysis_loop <- iso3_analysis_loop %>% 
    mutate(
      # ECPC 1850-2050
      ecpc_pp1850_tco2 = (rcb1850_nz * 1e9) / sum(pop_18502050),
      # ECPC 1990-2050
      ecpc_pp1990_tco2 = (rcb1990_nz * 1e9) / sum(pop_19902050))
  
  iso3_analysis_loop <- iso3_analysis_loop %>% 
    transmute(iso3c = iso3c,
              year = curr_year,
              "pp1990" = (ecpc_pp1990_tco2 * pop_19902050) / 1e9 - gtco2_cmltv,
              "pp1850" = (ecpc_pp1850_tco2 * pop_18502050) / 1e9 - gtco2_18501989 - gtco2_cmltv)
  
  rcb19902020 <- rbind(rcb19902020, iso3_analysis_loop)
  
}

# Check allocations
alloc_check_years <- rcb19902020 %>% 
  group_by(year) %>% 
  summarise(across(-c(iso3c), ~round(sum(.,na.rm = T), 2)))

# AGGREGATE TO R10 LEVEL --------------------------------------------------------

# Calculate population from year to 2050 for every year after 1990
pop_rem <- tibble(.rows = 0)

for (i in 1990:2020) {
  
  pop_rem_loop <- projected_pop %>% 
    group_by(iso3c) %>% 
    filter(year >= i & year <= 2050) %>% 
    summarise(pop_yearto2050 = sum(pop, na.rm = T)) %>% 
    mutate(year = i)
  
  pop_rem <- rbind(pop_rem, pop_rem_loop)
  
}

r10_rcb19902020 <- rcb19902020 %>% 
  pivot_longer(-c(iso3c, year), values_to = "rcb") %>% 
  left_join(projected_pop %>% 
              select(year, r10, iso3c, pop) %>% 
              filter(year >= 1990, year <= 2050) %>% 
              group_by(r10, iso3c) %>% 
              summarise(pop19902050 = sum(pop)), by = c("iso3c")) %>% 
  left_join(projected_pop %>% 
              select(year, iso3c, pop) %>% 
              filter(year >= 1850, year < 1990) %>% 
              group_by(iso3c) %>% 
              summarise(pop18501989 = sum(pop)), by = c("iso3c")) %>% 
  left_join(pop_rem) %>% 
  left_join(recent_prodco2 %>% select(iso3c, year, gtco2)) %>% 
  group_by(r10, year, name) %>% 
  # Some smaller countries missing data in 1990/1991
  summarise(gtco2 = sum(gtco2, na.rm = T),
            rcb = sum(rcb, na.rm = T),
            pop18501989 = sum(pop18501989, na.rm = T),
            pop_yearto2050 = sum(pop_yearto2050, na.rm = T)) %>% 
  mutate(gtco2 = ifelse(gtco2 == 0, NA_real_, gtco2)) %>% 
  ungroup() %>% 
  mutate(
    rcb_pc = case_when(
      grepl(name, pattern = "1990") ~ rcb * 1e9 / pop_yearto2050,
      grepl(name, pattern = "1850") ~ rcb * 1e9 / pop_yearto2050),
    category = case_when(
      name == "pp1990" ~ "1_PP1990",
      name == "pp1850" ~ "2_PP1850"),
    category = factor(category, levels = c("1_PP1990", "2_PP1850"))) %>% 
  arrange(category)

# WRITE TO FILE ----------------------------------------------------------------

r10_rcb19902020 %>% 
  arrange(r10, category, year) %>% 
  write_csv(here("data", "equity_data", "processed", "r10_rcb19902020.csv"))

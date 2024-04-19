# Replication archive for: ""

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

# knitr options
#' ```{r setup, include=FALSE}
#' knitr::opts_chunk$set(echo = TRUE, fig.width=12, fig.height=6)
#' ```

# COUNTRY NAMES AND REGIONAL GROUPING ------------------------------------------

# Determine country-years for analysis
iso3c_tbl <- read_csv(here("Data", "countrygroups", "region_mapping_REMIND.csv")) %>% 
  select(iso3c = ISO, r10 = R10_REMIND_2.1.REGION) %>% 
  group_by(iso3c, r10) %>% 
  expand(year = 1850:2100) %>% 
  ungroup()

# Set consistent r10 ordering
r10order <- tibble(r10 = c("R10NORTH_AM", "R10EUROPE", "R10PAC_OECD", "R10REF_ECON", "R10MIDDLE_EAST", "R10CHINA+", "R10LATIN_AM", "R10REST_ASIA", "R10AFRICA", "R10INDIA+"),
                   r10labellong = c("North America", "Europe", "Asia-Pacific Developed",
                                    "Eastern Europe and West-Central Asia", "Middle East", "Eastern Asia",
                                    "Latin America and Caribbean", "South-East Asia and developing Pacific",
                                    "Africa", "Southern Asia"))

# Adjust labels to reflect those for publication
iso3c_tbl <- iso3c_tbl %>% 
  left_join(r10order) %>% 
  select(iso3c, r10, r10labellong, year)

# PROCESSED DATA ---------------------------------------------------------------

r10_rcb19902020 <- read_csv(here("data", "equity_data", "processed", "r10_rcb19902020.csv")) %>% 
  select(r10, year, category, gtco2_hist = gtco2, rcb) %>% 
  left_join(r10order)

# SCENARIO DATA ----------------------------------------------------------------

# Read in regional CO2-FFI and Novel CDR emissions paths
paths <- read_csv(here("data", "pathways", "406_compiled_equity_data.csv")) %>% 
  filter(Variable %in% c("Emissions|CO2|Energy and Industrial Processes", 
                         "Carbon Dioxide Removal|Novel")) %>%
  select(-Unit) %>% 
  pivot_longer(cols = matches("\\d{4}"), names_to = "Year", values_to = "Value") %>% 
  pivot_wider(names_from = "Variable", values_from = "Value") %>% 
  mutate("Emissions|CO2|Energy and Industrial Processes|Gross" = 
           `Emissions|CO2|Energy and Industrial Processes` +
           `Carbon Dioxide Removal|Novel`,
         Year = as.numeric(Year)) %>%
  # Change units to GtCo2
  mutate(across(-c(Model, Scenario, Region, Year), ~. / 1e3)) %>% 
  filter(Year > 2020)

# Read in global P90 CDR paths and SUBTRACT FROM THESE global NOVEL CDR
p90cdr <- read_csv(here("data", "pathways", "406_compiled_equity_data.csv")) %>% 
  filter(Variable %in% c("Carbon Dioxide Removal|Novel [p90]", "Carbon Dioxide Removal|Novel"),
         Region == "World") %>%
  select(-Unit) %>% 
  pivot_longer(cols = matches("\\d{4}"), names_to = "Year", values_to = "Value") %>% 
  pivot_wider(names_from = "Variable", values_from = "Value") %>% 
  mutate(Year = as.numeric(Year),
         `Carbon Dioxide Removal|Novel [p90]|Additional` = `Carbon Dioxide Removal|Novel [p90]` - `Carbon Dioxide Removal|Novel`) %>%
  # Change units to GtCo2
  mutate(across(-c(Model, Scenario, Region, Year), ~. / 1e3)) %>% 
  filter(Year > 2020)

p90cdr %>% 
  pivot_longer(-c(Model, Scenario, Region, Year)) %>% 
  ggplot(aes(x = Year, y = value, colour = name)) +
  geom_line() +
  facet_wrap(~Scenario, ncol = 5) +
  theme_bw() +
  theme(legend.position = "bottom") +
  labs(x = NULL, y = "GtCO2", colour = NULL,
       title = "Novel CDR pathways, P90 CDR pathways, and difference (additional P90 CDR)")

# COMBINE HISTORICAL AND MODELLED EMISSIONS PATHWAYS ---------------------------

co2ffi_paths_hist <- list(paths %>%  mutate(Category = "1_PP1990"),
                          paths %>% mutate(Category = "2_PP1850")) %>% 
  reduce(bind_rows) %>% 
  group_by(Model, Scenario, Region, Category) %>%
  complete(Year = 1990:2100) %>%
  filter(!Region  %in% c("World", "R10ROWO")) %>% 
  list(., r10_rcb19902020 %>% 
         transmute(Region = r10, Category = category, Year = year, 
                   "Emissions|CO2|Energy and Industrial Processes|Historical" = gtco2_hist,
                   "Emissions|CO2|Energy and Industrial Processes|HistoricalRemaining" = rcb)) %>% 
  reduce(left_join)

co2ffi_paths_hist %>% 
  filter(Category == "1_PP1990") %>% 
  ggplot(aes(x = Year)) +
  geom_line(aes(y = `Emissions|CO2|Energy and Industrial Processes|Historical`)) +
  geom_line(aes(y = `Emissions|CO2|Energy and Industrial Processes|Gross`, colour = Scenario)) +
  facet_wrap(~Region, scales = "free_y", ncol = 5) +
  labs(x = NULL, y = "GtCO2-FFI", colour = "Scenario", title = "Historical and modelled CO2-FFI paths") +
  theme_bw() +
  theme(legend.position = "bottom")

co2ffi_paths_hist <- co2ffi_paths_hist %>% 
  group_by(Model, Scenario, Region, Category) %>% 
  transmute(Year = Year, 
            `Emissions|CO2|Energy and Industrial Processes|Gross` = 
              ifelse(is.na(`Emissions|CO2|Energy and Industrial Processes|Gross`), 
                     `Emissions|CO2|Energy and Industrial Processes|Historical`, 
                     `Emissions|CO2|Energy and Industrial Processes|Gross`),
            `Carbon Dioxide Removal|Novel` = ifelse(is.na(`Carbon Dioxide Removal|Novel`), 
                                                    0, `Carbon Dioxide Removal|Novel`),
            `Emissions|CO2|Energy and Industrial Processes|HistoricalRemaining` = 
              `Emissions|CO2|Energy and Industrial Processes|HistoricalRemaining`,
            `Emissions|CO2|Energy and Industrial Processes|GrossRemaining` = 
              `Emissions|CO2|Energy and Industrial Processes|HistoricalRemaining`[Year == 1990] -
              cumsum(lag(`Emissions|CO2|Energy and Industrial Processes|Gross`, default = 0)))

# DETERMINE CARBON DEBT IN 2100 ------------------------------------------------

cdebt <- co2ffi_paths_hist %>% 
  mutate(`Emissions|CO2|Energy and Industrial Processes|GrossDebtCmltv` = 
           ifelse(`Emissions|CO2|Energy and Industrial Processes|GrossRemaining` < 0, 
                  -`Emissions|CO2|Energy and Industrial Processes|GrossRemaining`, 0),
         `Emissions|CO2|Energy and Industrial Processes|GrossCmltv` = 
           cumsum(`Emissions|CO2|Energy and Industrial Processes|Gross`),
         `Carbon Dioxide Removal|NovelCmltv` =
           cumsum(`Carbon Dioxide Removal|Novel`)) %>% 
  filter(Year == 2100) %>% 
  select(Model, Scenario, Region, Category, `Emissions|CO2|Energy and Industrial Processes|GrossCmltv`, 
         `Emissions|CO2|Energy and Industrial Processes|GrossDebtCmltv`, `Carbon Dioxide Removal|NovelCmltv`) %>% 
  group_by(Model, Scenario, Category) %>% 
  mutate(`Emissions|CO2|Energy and Industrial Processes|GrossCmltvShare` =
           `Emissions|CO2|Energy and Industrial Processes|GrossCmltv` / 
           sum(`Emissions|CO2|Energy and Industrial Processes|GrossCmltv`),
         `Emissions|CO2|Energy and Industrial Processes|GrossDebtShare` = 
           `Emissions|CO2|Energy and Industrial Processes|GrossDebtCmltv` / 
           sum(`Emissions|CO2|Energy and Industrial Processes|GrossDebtCmltv`),
         ) %>% 
  arrange(Model, Scenario, Category, Region)

cdebt %>% 
  filter(Category == "1_PP1990") %>% 
  pivot_longer(-c(Model, Scenario, Region, Category)) %>% 
  ggplot(aes(x = Region, y = value, colour = Scenario)) +
  geom_point() +
  facet_wrap(~name, scales = "free_x", ncol = 5, strip.position = "right") +
  theme_bw() +
  theme(legend.position = "bottom") +
  coord_flip() +
  labs(x = NULL, y = "GtCO2", colour = "Scenario",
       title = "Comparing cumulative novel CDR, gross emissions, debt and shares")

# ASSIGN GLOBAL CUMULATIVE NOVEL AND PREVENTATIVE NOVEL CDR --------------------

novelcdr_resp <- left_join(cdebt, 
                           p90cdr %>% 
                             select(-Region) %>% 
                             group_by(Model, Scenario) %>% 
                             summarise(`Carbon Dioxide Removal|Novel|WorldCmltv` = sum(`Carbon Dioxide Removal|Novel`),
                                       `Carbon Dioxide Removal|Novel [p90]|WorldCmltv` = sum(`Carbon Dioxide Removal|Novel [p90]`))) %>% 
  mutate(`Carbon Dioxide Removal|Novel|FairShare` = `Emissions|CO2|Energy and Industrial Processes|GrossCmltvShare` * `Carbon Dioxide Removal|Novel|WorldCmltv`,
         `Carbon Dioxide Removal|Novel [p90]|FairShare` = `Emissions|CO2|Energy and Industrial Processes|GrossDebtShare` * `Carbon Dioxide Removal|Novel [p90]|WorldCmltv`)

novelcdr_resp %>% 
  filter(Category == "1_PP1990") %>% 
  select(Model, Scenario, Region, Category, `Carbon Dioxide Removal|NovelCmltv`, `Carbon Dioxide Removal|Novel|FairShare`, `Carbon Dioxide Removal|Novel [p90]|FairShare`) %>% 
  pivot_longer(-c(Model, Scenario, Region, Category, `Carbon Dioxide Removal|NovelCmltv`)) %>% 
  ggplot(aes(x = Region)) +
  geom_col(aes(y = value, fill = name)) +
  geom_point(aes(y = `Carbon Dioxide Removal|NovelCmltv`, shape = "Carbon Dioxide Removal|NovelCmltv")) +
  facet_wrap(~Scenario, ncol = 5) +
  coord_flip() +
  theme_bw() +
  theme(legend.position = "bottom") +
  labs(x = NULL, y = "GtCO2", shape = NULL, fill = NULL,
       title = "Comparing 'fair' shares of novel CDR, 'fair' shares of preventative CDR, and modeled novel CDR") +
  guides(fill = guide_legend(reverse = T))





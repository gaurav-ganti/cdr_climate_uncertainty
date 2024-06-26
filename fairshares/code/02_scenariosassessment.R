# Replication archive for: ""

# Contact for clarifications: [ANONYMISED]       

# Script contents: Evaluate assessed scenarios

# LOAD PACKAGES ----------------------------------------------------------------

#install.packages("pacman")
library(pacman)

# processing
p_load(dplyr, tidyr, readr, readxl, writexl, purrr, ggplot2, forcats,
       stringr, patchwork, geomtextpath)

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

r10_poprem <- read_csv(here("data", "equity_data", "processed", "iso3c_allocdataset.csv")) %>% 
  group_by(r10) %>%
  summarise(pop_20202100 = sum(pop_20202100)) %>% 
  rename(Region = r10)

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
  labs(x = NULL, y = "GtCO2-FFI", colour = "Scenario", title = "Historical and modelled gross CO2-FFI paths") +
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
         `Emissions|CO2|Energy and Industrial Processes|GrossDebtCmltvShare` = 
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

novelcdr_resp <- left_join(
  cdebt, 
  p90cdr %>% 
    select(-Region) %>% 
    group_by(Model, Scenario) %>% 
    summarise(`Carbon Dioxide Removal|Novel|WorldCmltv` = 
                sum(`Carbon Dioxide Removal|Novel`),
              `Carbon Dioxide Removal|Novel [p90]|Additional|WorldCmltv` = 
                sum(`Carbon Dioxide Removal|Novel [p90]|Additional`))) %>% 
  mutate(`Carbon Dioxide Removal|Novel|FairShare` = 
           `Emissions|CO2|Energy and Industrial Processes|GrossCmltvShare` * 
           `Carbon Dioxide Removal|Novel|WorldCmltv`,
         `Carbon Dioxide Removal|Novel [p90]|Additional|FairShare` = 
           `Emissions|CO2|Energy and Industrial Processes|GrossDebtCmltvShare` * 
           `Carbon Dioxide Removal|Novel [p90]|Additional|WorldCmltv`) %>% 
  select(Model, Scenario, Region, Category, matches("Emissions"), matches("Removal"))

novelcdr_resp %>% 
  filter(Category == "1_PP1990") %>% 
  select(Model, Scenario, Region, Category, `Carbon Dioxide Removal|NovelCmltv`, 
         `Carbon Dioxide Removal|Novel|FairShare`, 
         `Carbon Dioxide Removal|Novel [p90]|Additional|FairShare`) %>% 
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

# Figure 3 ---------------------------------------------------------------------

# a <- novelcdr_resp %>% 
#   filter(Category == "1_PP1990") %>% 
#   left_join(r10_poprem) %>% 
#   select(Model, Scenario, Region, Category, `Carbon Dioxide Removal|NovelCmltv`, 
#          `Carbon Dioxide Removal|Novel|FairShare`, 
#          `Carbon Dioxide Removal|Novel [p90]|Additional|FairShare`) %>%
#   ggplot(aes(x = Region)) +
#   geom_errorbar(aes(ymin = `Carbon Dioxide Removal|Novel|FairShare`, 
#                     ymax = `Carbon Dioxide Removal|Novel [p90]|Additional|FairShare`,
#                     colour = Scenario), width = 0.5, size = 0.5, 
#                 position = position_dodge(width = 0.5)) +
#   geom_point(aes(y = `Carbon Dioxide Removal|NovelCmltv`, 
#                  shape = "Modelled removals", colour = Scenario),
#              position = position_dodge(width = 0.5)) +
#   scale_color_brewer(type = "qual", palette = "Dark2") +
#   coord_flip() +
#   theme_bw() +
#   theme(legend.position = "right") +
#   labs(x = NULL, y = "Cumulative removals 2020-2100 (GtCO2)", shape = NULL, colour = NULL) +
#   guides(colour = guide_legend(reverse = T))

a <- novelcdr_resp %>% 
  filter(Category == "1_PP1990") %>% 
  left_join(r10_poprem) %>% 
  mutate(across(c(`Carbon Dioxide Removal|NovelCmltv`,
                  `Carbon Dioxide Removal|Novel|FairShare`,
                  `Carbon Dioxide Removal|Novel [p90]|Additional|FairShare`), 
                ~ . * 1e9 / pop_20202100, .names = "{.col}|PerCapita20202100")) %>% 
  select(Model, Scenario, Region, Category, `Carbon Dioxide Removal|NovelCmltv|PerCapita20202100`, 
         "Modelled" = `Carbon Dioxide Removal|Novel|FairShare|PerCapita20202100`, 
         "Preventative" = `Carbon Dioxide Removal|Novel [p90]|Additional|FairShare|PerCapita20202100`) %>%
  ggplot(aes(x = Region)) +
  geom_col(aes(y = `Carbon Dioxide Removal|NovelCmltv|PerCapita20202100`, fill = Scenario),
           position = position_dodge(width = 0.6), width = 0.6, alpha = 0.6) +
  geom_segment(aes(y = Modelled, yend = Modelled + Preventative, colour = Scenario), 
             position = position_dodge(width = 0.6), show.legend = F, alpha = 0.1) +
  geom_point(aes(y = Modelled, colour = Scenario, shape = "Scenario"),
             position = position_dodge(width = 0.6), alpha = 2) +
  geom_point(aes(y = Modelled + Preventative, colour = Scenario, shape = "Scenario + Preventative"),
             position = position_dodge(width = 0.6), alpha = 2) +
  scale_colour_brewer(type = "qual", palette = "Dark2", direction = -1) +
  scale_fill_brewer(type = "qual", palette = "Dark2", direction = -1) +
  scale_shape_manual(values = c(4, 20)) +
  coord_flip() +
  theme_bw() +
  theme(legend.position = "right", panel.grid = element_blank()) +
  labs(x = NULL, y = "Average per-capita CDR 2020-2100 (tCO2/capita/year)", 
       shape = "'Fair' novel CDR shares", fill = "Scenario") +
  guides(colour = "none",
         fill = guide_legend(reverse = T))

b <- novelcdr_resp %>% 
  filter(Category == "1_PP1990") %>% 
  left_join(r10_poprem) %>% 
  mutate(difference = `Carbon Dioxide Removal|NovelCmltv` - 
           (`Carbon Dioxide Removal|Novel|FairShare` + `Carbon Dioxide Removal|Novel [p90]|Additional|FairShare`)) %>% 
  group_by(Category, Scenario) %>% 
  mutate(preventativegap = sum(difference)) %>% 
  ggplot(aes(x = Scenario)) +
  geom_hline(yintercept = 0, linetype = "dashed", colour = "grey") +
  geom_col(aes(y = -difference, fill = Scenario),
           width = 0.4, alpha = 0.6) +
  geom_textsegment(aes(y = 0, yend = -preventativegap, label = "Absolute gap", xend = Scenario),
                   data = . %>% distinct(Model, Scenario, Category, preventativegap),
                   arrow = arrow(type = "closed", length = unit(0.1, "cm")), size = 2.5, alpha = 0.7) +
  scale_fill_brewer(type = "qual", palette = "Dark2", direction = -1) +
  labs(fill = "Scenario", y = "Cumulative preventative CDR gap (GtCO2e)",
       x = NULL) +
  coord_flip() +
  theme_bw() +
  theme(legend.position = "right", panel.grid = element_blank(),
        axis.text.y = element_blank(),
        axis.ticks.y = element_blank()) +
  guides(fill = guide_legend(reverse = T))

wrap_plots(a,b) + plot_layout(guides = "collect")

ggsave(here("figure", "figure3.png"), width = 12, height = 5, dpi = 300)

# Write data to file
a$data %>% write_csv(here("figure", "figure3a.csv"))
b$data %>% write_csv(here("figure", "figure3b.csv"))

# Volumes of drawdown
# 1 Figure, 200-300 words






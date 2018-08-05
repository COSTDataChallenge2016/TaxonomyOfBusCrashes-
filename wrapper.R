# Change this to wherever you've cloned the repo
base_dir <- "~/GES/TaxonomyOfBusCrashes-/"

yrs <- c("05","06","07","08","09","10","11","12","13","14","15")
base_dir_backup <- base_dir
for (i in seq_along(yrs)) {
  print(paste0("Extracting data for year: ", yrs[i]))
  source(paste0(base_dir, "data_", yrs[i], "_extract.R"))
}
# base_dir is overwritten, so reinitialize
base_dir <- base_dir_backup
source(paste0(base_dir, "combine_05_09.R"))
source(paste0(base_dir, "combine_10_15.R"))
source(paste0(base_dir, "combine_to_reduced_05_09.R"))
source(paste0(base_dir, "combine_to_reduced_10_15.R"))

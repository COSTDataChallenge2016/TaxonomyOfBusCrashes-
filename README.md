# TaxonomyOfBusCrashes-
This repo holds code and data to reproduce results and graphics in A Cluster-Based Taxonomy of Bus Crashes in the US.

To reproduce the graphs and the data for the tables, follow these steps:
1. Clone this repo:
```bash
git clone https://github.com/COSTDataChallenge2016/TaxonomyOfBusCrashes-.git
```
2. Download the [GES data](ftp://ftp.nhtsa.dot.gov/GES/). You only need the data from 2005-2015.
3. In all of the *data_xx_extract.R* files, change `data_base_dir` to the directory where you downloaded 
the data, and `data_out` to wherever you want intermediate output to be saved. 
4. In *combine_05_09.R* and *combine_10_15.R*, change `the_base_dir` to the parent directory of `data_out` 
from step 3. Change `outfile` as desired.
5. In *combine_to_reduced_05_09.R* and *combine_to_reduced_10_15.R*, change the path in `load()` to the value of 
`outfile` from step 4. Change `outfile` (in the current file) as desired.
6. In *wrapper.R*, change `base_dir` to wherever you've cloned the repo. Run this file. This will create the outputs
needed to run *master.R*.
7. [Download v2.0.19 of R package *kohonen* from CRAN](https://cran.r-project.org/src/contrib/Archive/kohonen/) and 
install from source:
```r
install.packages("~/Downloads/kohonen_2.0.19.tar.gz", repos = NULL, type = "source")
```
8. In *master.R*, change `basedir`, `repodir`, and `GES_dir` as required. The code comments tell you what 
each of these need to be. Run this file. This will create all the required plots and tables used in the paper. 
They will be located in `file.path(basedir, outdir)`.

We are including an "out" directory in this repo, so that you can compare your outputs with ours. Be sure
to change `outdir` in *master.R* if you don't want to overwrite our outputs! 
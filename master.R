
## basedir gives the directory path for the location of this code
## **basedir must contain a subdirectory named out/, with folders 1014a/, 0509a/, csv/, EDA/
## GES_dir is a subdirectory of basedir
## infiles are paths within GES_dir for the input data
setwd("~/Desktop/GES_Data_Challenge/codes_for_COST/")
library(FactoMineR)
library(data.table)
library(dbscan)
library(cluster)
library(kohonen, lib.loc = "~/Desktop/GES_Data_Challenge/codes_for_COST/lib/")
library(cclust)
library(WeightedCluster)
library(fmsb)

library(magrittr)
library(dplyr)

## Colors
cols <- c("#5884B3", ## Blue
          "#E87B70", ## Orange
          "#E5CF6C", ## Yellow
          "#5BBE94") ## Green

cols_cat <- list(veh_invl = c("#85cbcf", "#3984b6", "#192574"),
                 spd_lim = c("#85cbcf", "#3984b6", "#192574"),
                 crit_event = c("#c6e3cb", "#83cacf", "#47aed0",
                                "#3984b6", "#2c5a9c", "#1e3082",
                                "#141c59"),
                 traf_control = c("#9ed5cd", "#44a7cb", "#2e62a1", "#192574"),
                 bus_mov = c("#dcecc9", "#aadacc", "#78c6d0",
                             "#48b3d3", "#3e94c0", "#3474ac",
                             "#2a5599", "#203686", "#18216b",
                             "#11174b"))

infiles <- list("1014" = "data_final_2010_2015_reducedcols",
                "0509" = "data_final_2005_2009_reducedcols")

basedir <- "~/Desktop/GES_Data_Challenge/codes_for_COST/"
GES_dir <- file.path(basedir)

## Run clustering
for (use.1014 in c(TRUE, FALSE)) {
    ## Load data
    if (use.1014) {
        set.seed(20160918)
        load(file.path(GES_dir, infiles[["1014"]]))

        df <- df_reduced %>% tbl_df
        rm(df_reduced)
    } else {
        set.seed(20160920)
        load(file.path(GES_dir, infiles[["0509"]]))

        df <- df_test %>% tbl_df
        rm(df_test)
    }

    ## Format data
    df_noweight <- df %>% dplyr::select(-WEIGHT)
    mat <- model.matrix(~., df_noweight)

    ## Self-organizing map
    som_grid <- somgrid(xdim = 20, ydim=20, topo="hexagonal")
    som_model <- som(mat,
                     grid=som_grid,
                     rlen=200,
                     alpha=c(0.05,0.01),
                     keep.data = TRUE,
                     n.hood='circular' )

    myclust <- cclust(som_model$codes, 4, method='neuralgas')
    clusters <- myclust$cluster

    ## get clusters for each data point
    neurons2cluster <- data.frame(neuron=1:400, cluster_no=clusters)
    obs2neuron <- data.frame(obs_no=1:nrow(df), neuron=som_model$unit.classif)
    obs2cluster <- left_join(obs2neuron, neurons2cluster)

    ## add cluster to data
    df$cluster <- obs2cluster$cluster_no
    df$cluster <- factor(df$cluster)

    if (use.1014) {
        save(df, file = paste0("out/clusters_1014_noreorder.Rdata"))
    } else {
        save(df, file = paste0("out/clusters_0509.Rdata"))
    }

}

## Plots

for (use.1014 in c(TRUE, FALSE)) {
    ## Load data
    if (use.1014) {
        new_order <- c(4, 2, 1, 3)
        ## new_order <- 1:4
        load(file.path(basedir, "out/clusters_1014_noreorder.Rdata"))
        df <-
            df %>%
            filter(bus_mov != 4) %>%
            mutate(bus_mov = factor(bus_mov))
        infix <- "1014a"
    } else {
        new_order <- 1:4
        load(file.path(basedir, "out/clusters_0509.Rdata"))
        infix <- "0509a"
    }

    df <-
        tbl_df(df) %>%
        filter(sex != 8) %>%
        mutate(sex = factor(sex)) %>%
        mutate(sur_adverse = ifelse(sur_dry =="1" & profile_level == "1" &
                                    str_align == "1",
                                    "0", "1")) %>%
        mutate(sur_adverse = factor(sur_adverse)) %>%
        mutate(good_light = ifelse(light_cond == "1", "1", "0")) %>%
        mutate(good_light = factor(good_light)) %>%
        mutate(iad_p = ifelse(alc_p == "1" | speed_p == "1" | imp_p == "1", "1", "0")) %>%
        mutate(iad_p = factor(iad_p)) %>%
        mutate(spd_lim =ifelse(spd_lim < 35, "slow", ifelse(spd_lim < 55, "medium", "fast"))) %>%
        mutate(spd_lim = factor(spd_lim)) %>%
        mutate(spd_lim = as.ordered(spd_lim)) %>%
        select(-sur_dry, -profile_level, -str_align, -alc_p, -speed_p, -imp_p, -light_cond)

    if (!use.1014) {
        df$cluster <- factor(df$cluster)
        df <-
            df %>%
            filter(bus_mov != 4)
        df$bus_mov <- factor(df$bus_mov, levels(df$bus_mov)[-4])
    }

    ## Weights observations, and calculates weighted proportion of
    ## population with each factor level, for each cluster
    weightvar <- function(df, var, prop = TRUE) {
        df <-
            df %>%
            group_by_(.dots = c("cluster", var)) %>%
            summarise(n_clust_var = sum(WEIGHT)) %>%
            group_by(cluster) %>%
            mutate(n_clust = sum(n_clust_var)) %>%
            mutate(perc = n_clust_var / n_clust)
        if (prop) {
            df %>%
                select_(var, "cluster", "perc")
        } else {
            df
        }
    }

    factors <- names(df %>% select(-cluster, -WEIGHT))
    weighted <- list()
    weighted_raw <- list()
    for (v in factors) {
        weighted[[v]] <- weightvar(df, v)
        weighted_raw[[v]] <- weightvar(df, v, FALSE)
    }

    var_lookup <- list()
    var_lookup[["veh_invl"]] <- list("Number of vehicles involved",
                                     c("One", "Two", "Three or more"))
    var_lookup[["spd_lim"]] <- list("Speed limit",
                                    c("<35mph", "35mph-55mph", ">55mph"))
    # var_lookup[["crit_event"]] <-
    #     list("Critical event that made crash imminent",
    #          c("Loss of control",
    #            "Vehicle turning",
    #            "In another vehicle's lane",
    #            "Encroaching in another vehicle's lane",
    #            "Other vehicle encroaching into lane",
    #            "Non-motorist", "Object or animal"))
    var_lookup[["crit_event"]] <-
      list("Critical event that made crash imminent",
           c("Loss of control",
             "Vehicle turning",
             "Other vehicle in lane",
             "Other vehicle encroaching into lane",
             "Non-motorist at fault", "Object or animal","Unknown"))
    var_lookup[["traf_control"]] <- list("Traffic control",
                                         c("No control", "Traffic signal",
                                           "Traffic Sign", "Other"))
    var_lookup[["bus_mov"]] <-
        list("Bus movement prior to accident",
             c("Parking", "Going straight", "Stopping", "Decelerating",
               "Turning right", "Turning left", "Overtaking", "Reversing",
               "Negotiating a curve", "Other"))
    # var_lookup[["bus_mov"]] <-
    #   list("Bus movement prior to accident",
    #        c("Parking", "Going straight", "Stopping", "Accelerating", "Decelerating",
    #          "Turning right", "Turning left", "Overtaking", "Reversing",
    #          "Negotiating a curve", "Other"))
    
    var_lookup[["sch_bus"]] <- c("School bus")
    var_lookup[["nonm_invl"]] <- c("Non-motorists involved")
    var_lookup[["intersection"]] <- c("Located at intersection")
    var_lookup[["single_lane"]] <- c("Single lane road")
    var_lookup[["sur_adverse"]] <-
        c("Surface conditions adverse")
    var_lookup[["good_light"]] <- c("Daylight")
    var_lookup[["dr_distracted"]] <- c("Bus driver distracted")
    var_lookup[["iad"]] <- c("Bus driver impaired or speeding")
    var_lookup[["psv_p"]] <- c("Pickup truck, SUV or van involved")
    var_lookup[["lht_p"]] <- c("Light / heavy truck involved")
    var_lookup[["distr_p"]] <- c("Other driver distracted")
    var_lookup[["iad_p"]] <- c("Other driver impaired or speeding")
    var_lookup[["sex"]] <- c("Male")

    nonbinary <- c("veh_invl", "spd_lim", "crit_event",
                   "traf_control", "bus_mov")
    ## binary <- names(weighted)
    ## binary <- binary[!binary %in% nonbinary]

    binary <-
        c("nonm_invl", "sch_bus", "intersection", "single_lane",
          "dr_distracted", "distr_p", "iad", "iad_p", "sex", "psv_p",
          "lht_p", "sur_adverse", "good_light")

    nbin <- length(binary)
    bin_props <- matrix(NA, nbin, 4)
    rownames(bin_props) <- binary
    for (b in binary) {

        tmp <-
            weighted[[b]] %>%
            filter_(paste0(b, " == 1"))
        tmp$cluster <- as.character(tmp$cluster)
        tmp[[b]] <- as.character(tmp[[b]])

        for (i in 1:4) {
            if ((tmp %>% filter(cluster == i)  %>% nrow) == 0) {
                r <- data.frame("1", cluster = as.character(i), perc = 0)

                names(r)[1] <- b

                tmp <- bind_rows(tmp, r)
            }
        }
        tmp$cluster <- as.factor(tmp$cluster)
        tmp[[b]] <- as.factor(tmp[[b]])

        bin_props[b,] <-
            tmp %>%
            collect %>%
            .[["perc"]]
    }
    bin_props <- bin_props[,new_order]

    ylim.01 <- TRUE
    fnplot <- paste0("out/", infix, "/binary_proportions.png")
    if (ylim.01) fnplot <- paste0("out/", infix, "/binary_proportions_scaled.png")

    png(file.path(basedir, fnplot), width = 400, 1400)
    par(mar = c(5, 4, 4, 4)+.1, mfrow = c(7, 2))
    for (i in 1:nbin) {
        b <- binary[i]
        ## Labeling
        ax <- FALSE
        if (i %% 2 == 1) ax <- TRUE
        xlabs <- 1:4
        ## Plot proportions
        if (ylim.01) {
            barplot(bin_props[b,], main = var_lookup[[b]],
                    ## barplot(bin_props[b,], main = var_lookup[[b]],
                    names.arg = xlabs,
                    col = cols, ylim = c(0,1), axes = ax)
        } else {
            barplot(bin_props[b,], main = var_lookup[[b]],
                    ## barplot(bin_props[b,], main = var_lookup[[b]],
                    names.arg = xlabs,
                    col = cols, axes = TRUE)
        }
        if (i %% 2 == 0) axis(4)
    }
    dev.off()

    cont_tabs <- list()
    for (b in nonbinary) {
        bdata <- weighted_raw[[b]]
        lvls <- levels(bdata[[b]])

        nfactors <- length(lvls)

        ct <- matrix(0, 4, nfactors)
        for (i in 1:4) {
            tmp <-
                bdata %>%
                filter(cluster == i)
            ix_present <- which(lvls %in% tmp[[b]])

            ct[i,ix_present] <-
                tmp %>%
                collapse %>%
                .[["n_clust_var"]]
        }
        ct <- ct[new_order,]
        colnames(ct) <- var_lookup[[b]][[2]]
        rownames(ct) <- 1:4
        cont_tabs[[b]] <- ct
    }

    for (b in nonbinary) {
        png(sprintf("%s/out/%s/%s.png", basedir, infix, b),
            width = 10, height = 10, units = "in", res = 300)

        mosaicplot(cont_tabs[[b]], main = var_lookup[[b]][[1]], las = 1,
                   ## mosaicplot(cont_tabs[[b]], main = var_lookup[[b]][[1]], las = 1,
                   color = cols_cat[[b]], cex.axis = 1)

        dev.off()
    }

    save(bin_props, cont_tabs, weighted, weighted_raw,
         file = sprintf("%s/out/%s/plot_vals.Rdata", basedir, infix))
    save(df, file = sprintf("%s/out/%s/df.Rdata", basedir, infix))
    save(var_lookup, file = file.path(basedir, "out/var_lookup.Rdata"))

}

## Save CSV values

load(file.path(basedir, "out/var_lookup.Rdata"))

load(file.path(basedir, "out/0509a/plot_vals.Rdata"))

rownames(bin_props) <-
    rownames(bin_props) %>%
    var_lookup[.] %>%
    lapply(function(x) x[[1]]) %>%
    unlist

write.csv(bin_props, paste0(basedir, "/out/csv/0509-props.csv"))

cont_tabs <- lapply(cont_tabs, function(x) x %>% prop.table(1))

names(cont_tabs) <-
    names(cont_tabs) %>%
    var_lookup[.] %>%
    lapply(function(x) x[[1]]) %>%
    unlist

for (v in names(cont_tabs)) {
    write.csv(cont_tabs[[v]], paste0(basedir, "/out/csv/0509-", v, ".csv"))
}

load(file.path(basedir, "out/1014a/plot_vals.Rdata"))

rownames(bin_props) <-
    rownames(bin_props) %>%
    var_lookup[.] %>%
    lapply(function(x) x[[1]]) %>%
    unlist

write.csv(bin_props, paste0(basedir, "/out/csv/1014-props.csv"))

cont_tabs <- lapply(cont_tabs, function(x) x %>% prop.table(1))

names(cont_tabs) <-
    names(cont_tabs) %>%
    var_lookup[.] %>%
    lapply(function(x) x[[1]]) %>%
    unlist

for (v in names(cont_tabs)) {
    write.csv(cont_tabs[[v]], paste0(basedir, "/out/csv/1014-", v, ".csv"))
}

## Plots

## basedir <- "~/Dropbox/School/misc/jsm"
## GESdir <- file.path(basedir, "GES Data Challenge")

load(file.path(basedir, "out/var_lookup.Rdata"))

load(file.path(basedir, "out/1014a/df.Rdata"))
df14 <- df

load(file.path(basedir, "out/0509a/df.Rdata"))
df09 <- df

rm(df)
gc()

weightvar <- function(df, v) {
    df %>%
        select_(v, "WEIGHT") %>%
        group_by_(v) %>%
        summarize(n = sum(WEIGHT))
}

factors <- names(df09 %>% select(-cluster, -WEIGHT))
w09 <- list()
w14 <- list()
for (v in factors) {
    w09[[v]] <- weightvar(df09, v)
    w14[[v]] <- weightvar(df14, v)
}

## Binary proportions
binary <- c("nonm_invl", "sch_bus", "intersection", "single_lane",
            "dr_distracted", "iad", "sex", "psv_p", "lht_p", "distr_p",
            "sur_adverse", "good_light", "iad_p")

nonbinary <- c("veh_invl", "spd_lim", "crit_event", "traf_control", "bus_mov")

bin_props <- matrix(NA, length(binary), 4)
nbin <- length(binary)
for (i in 1:nbin) {
    b <- binary[i]
    bin_props[i,] <- c(w09[[b]]$n, w14[[b]]$n)
}
rownames(bin_props) <-
    var_lookup[binary] %>%
    unlist
colnames(bin_props) <- rep(c("No", "Yes"), 2)

## (bin_props[,4] - bin_props[,2]) %>% t %>% t

years <- c("2005--2009", "2010--2015")

fnplot <- "out/EDA/props.png"
png(file.path(basedir, fnplot),
    width = 10, height = 10, units = "in", res = 300)
par(mar = c(3, 2, 2, 2)+.1, mfrow = c(4, 4))
for (i in 1:nbin) {
    bn <- var_lookup[[binary[i]]]
    bp <-
        bin_props[i,] %>%
        matrix(2, 2) %>%
        t
    rownames(bp) <- years
    colnames(bp) <- c("No", "Yes")
    mosaicplot(bp, main = bn, col = c("#3984b6", "#85cbcf"))
}
dev.off()

w14$bus_mov <- w14$bus_mov %>% filter(bus_mov != 4) %>% mutate(bus_mov = factor(bus_mov))
## df14_nb <- lapply(w14[nonbinary], table)
## df09_nb <- lapply(w09[nonbinary], table)

cols_out <- list(veh_invl = c("#85cbcf", "#3984b6", "#192574"),
                 spd_lim = c("#85cbcf", "#3984b6", "#192574"),
                 crit_event = c("#c6e3cb", "#83cacf", "#47aed0",
                                "#3984b6", "#2c5a9c", "#1e3082",
                                "#141c59"),
                 traf_control = c("#9ed5cd", "#44a7cb", "#2e62a1", "#192574"),
                 bus_mov = c("#dcecc9", "#aadacc", "#78c6d0",
                             "#48b3d3", "#3e94c0", "#3474ac",
                             "#2a5599", "#203686", "#18216b",
                             "#11174b"))

for (nb in nonbinary) {
    vnb <- var_lookup[[nb]]
    tmp <- rbind(w09[[nb]]$n, w14[[nb]]$n)
    rownames(tmp) <- years
    colnames(tmp) <- vnb[[2]]
    tmp <-
        tmp %>%
        prop.table

    png(sprintf("%s/out/EDA/%s.png", basedir, nb),
        width = 10, height = 10, units = "in", res = 300)
    mosaicplot(tmp, main = vnb[[1]], col = cols_out[[nb]],
               cex.axis = 1, las = 1)
    dev.off()
}


png(sprintf("%s/out/EDA/radar.png", basedir, nb),
        width = 12, height = 6, units = "in", res = 300)
par(mfrow=c(2, 3),
    mar = c(3,2,2,2)+.1)
for (nb in nonbinary) {
    vnb <- var_lookup[[nb]]
    tmp <- rbind(w09[[nb]]$n, w14[[nb]]$n)
    rownames(tmp) <- years
    colnames(tmp) <- vnb[[2]]
    tmp <-
        tmp %>%
        prop.table

    k <- ncol(tmp)
    pmax <- ifelse(max(tmp) < .25, .25, .5)
    maxmin <- rbind(rep(pmax, k), rep(0, k))
    tmp <- rbind(maxmin, tmp)
    tmp <- as.data.frame(tmp)
    rownames(tmp)[1] <- "Max"
    rownames(tmp)[2] <- "Min"

    if (nb == "crit_event") tmp <- tmp[,c(4,5,1,2,3,6,7)]

    radarchart(tmp, title = vnb[[1]], pcol = c("red", "blue"),
               cglcol = "black")
}
plot(1, type="n", axes=FALSE, xlab="", ylab="")
legend(1, 1, legend = years, col= c("red", "blue"),
       lwd=2, cex=1, xjust=0.5, yjust=0.5, bty = "n")
dev.off()

source("colors.R")

png(sprintf("%s/out/EDA/radar-bar.png", basedir, nb),
        width = 12, height = 6, units = "in", res = 300)
par(mfrow=c(2, 3),
    mar = c(3,8,2,2)+.1)
for (nb in nonbinary) {
    vnb <- var_lookup[[nb]]
    tmp <- rbind(w09[[nb]]$n, w14[[nb]]$n)
    rownames(tmp) <- years
    colnames(tmp) <- vnb[[2]]
    tmp <-
        tmp %>%
        prop.table
    ##
    if (nb == "crit_event") {
        tmp <- tmp[,c(4,5,1,2,3,6,7)]
        cex <- .6
    } else if (nb == "bus_mov") {
        cex <- .8
    } else {
        cex <- 1
    }
    ## Swap rows so that 2005 is on top, note that colors are reversed
    ## from in legend---barplot plots from the bottom up, so the top
    ## row of tmp is the bottom row in the barplot
    tmp <- tmp[c(2,1),]
    barplot(tmp, beside = TRUE, cex.names = cex,
            main = vnb[[1]], col = c(cols_all["Blue1"], cols_all["Red1"]), las = 1, horiz = TRUE)
}
plot(1, type="n", axes=FALSE, xlab="", ylab="")
legend(1, 1, legend = years, fill = c(cols_all["Red1"], cols_all["Blue1"]),
       cex=1, xjust=0.5, yjust=0.5, bty = "n")
dev.off()
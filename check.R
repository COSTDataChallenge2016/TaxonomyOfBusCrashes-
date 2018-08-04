dat_nobus_red <- dat_nobus %>% filter(CASENUM %in% dat_bus$CASENUM)
acc_nonm <- acc15_sel %>% filter(PERNOTMVIT != 0, CASENUM %in% dat_bus$CASENUM)
dat_nobus_red_acc <- dat_nobus_red %>% filter(CASENUM %in% acc_nonm$CASENUM)

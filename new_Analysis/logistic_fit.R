##  This file fits a logistic growth to the whole population counts and perform likelihood ratio test on whether there is a K

# logistic growth function, reduce to exponential when invK=0, i.e. K=\infty
logistic_growth <- function(t,r,p0,invK=0){
  p0*exp(r*t)/(1+(p0*invK)*(exp(r*t)-1))
}

# with Poisson noise
negloglik_pois <- function(pars, y,t,dd = TRUE){
  pars <- exp(pars)
  if(dd){
    pred <- logistic_growth(t,pars[1],pars[2],pars[3] )
  }
  else{
    pred <- logistic_growth(t,pars[1],pars[2],0)
  }
  -sum(dpois(y,pred,log = TRUE))
}

# fit the Pois model
fit_pois_mod <- function(y,t,t_new,t0 = 1980,dd = TRUE, se = T, pred_inter = T){
  #opt <- optim(c(log(max(y)/min(y))/length(y),log(min(y)),-log(max(y))),negloglik_pois,y = y,t = t-t0, dd = dd, hessian = T)
  #pars <- exp(opt$par)
  if(dd){
    opt <- optim(c(log(max(y)/min(y))/length(y),log(min(y)),-log(max(y))),negloglik_pois,y = y,t = t-t0, dd = dd, hessian = T)
    pars <- exp(opt$par)
    pred <- logistic_growth(t_new-t0,pars[1],pars[2],pars[3] )
    if(se){
      the_se <- lapply(1:3, function(i, pars, t_new, pred){
        par1 <- pars
        par1[i] <- par1[i] + min(1e-8*abs(par1[i]),1e-8)
        pred1 <- logistic_growth(t_new,exp(par1[1]),exp(par1[2]),exp(par1[3]))
        (pred1-pred)/(par1[i]-pars[i])
      }, opt$par, t_new-t0, pred) |>
        Reduce(f = cbind) |> 
        apply(1,function(vec, hess){
          (as.vector(t(vec) %*% solve(hess, (vec))))
        }, opt$hessian) 
        the_se <- sqrt(the_se+(pred*pred_inter) )
    }
    else the_se <- NA
  }
  else{
    opt <- optim(c(log(max(y)/min(y))/length(y),log(min(y))),negloglik_pois,y = y,t = t-t0, dd = dd, hessian = T)
    pars <- exp(opt$par)
    pred <- logistic_growth(t_new-t0,pars[1],pars[2],0)
    # calculate Wald se using brutal force 
    if(se){
      the_se <- lapply(1:2, function(i, pars, t_new, pred){
        par1 <- pars
        par1[i] <- par1[i] + min(1e-8*abs(par1[i]),1e-8)
        pred1 <- logistic_growth(t_new,exp(par1[1]),exp(par1[2]),0)
        (pred1-pred)/(par1[i]-pars[i])
      }, opt$par, t_new-t0, pred) |>
        Reduce(f = cbind) |> 
        apply(1,function(vec, hess){
          (as.vector(t(vec) %*% solve(hess, (vec))))
        }, opt$hessian) 
      the_se <- sqrt(the_se+(pred*pred_inter) )
    }
    else the_se <- NA
  }
  
  return(list(opt = opt, pred = pred, se = the_se))
}

negloglik_gaus <- function(pars, y,t,dd = TRUE){
  pars <- exp(pars)
  if(dd){
    pred <- logistic_growth(t,pars[1],pars[2],pars[3] )
  }
  else{
    pred <- logistic_growth(t,pars[1],pars[2],0)
  }
  -sum(dnorm(y,pred,pars[3+dd],log = TRUE))
}

fit_norm_mod <- function(y,t,t_new,t0 = 1980,dd = TRUE,se = T, pred_inter = T){
  
  if(dd){
    opt <- optim(c(log(max(y)/min(y))/length(y),log(min(y)),-log(max(y)),log(var(y))/2),negloglik_gaus,y = y,t = t-t0, dd = dd, hessian = T)
    pars <- exp(opt$par)
    pred <- logistic_growth(t_new-t0,pars[1],pars[2],pars[3] )
    
    if(se){
      the_se <- lapply(1:4, function(i, pars, t_new, pred){
        par1 <- pars
        par1[i] <- par1[i] + min(1e-8*abs(par1[i]),1e-8)
        pred1 <- logistic_growth(t_new,exp(par1[1]),exp(par1[2]),exp(par1[3]))
        (pred1-pred)/(par1[i]-pars[i])
      }, opt$par, t_new-t0, pred) |>
        Reduce(f = cbind) |> 
        apply(1,function(vec, hess,samp_var,pred_inter){
          sqrt((t(vec) %*% solve(hess, (vec)))+samp_var * pred_inter)
        }, opt$hessian, pars[4]^2, pred_inter)
    }
    else the_se <- NA
    
  }
  else{
    opt <- optim(c(log(max(y)/min(y))/length(y),log(min(y)),log(1000)),negloglik_gaus,y = y,t = t-t0, dd = dd, hessian = T, control = list(reltol = 1e-10))
    pars <- exp(opt$par)
    pred <- logistic_growth(t_new-t0,pars[1],pars[2],0)
    
    if(se){
      the_se <- lapply(1:3, function(i, pars, t_new, pred){
        par1 <- pars
        par1[i] <- par1[i] + min(1e-8*abs(par1[i]),1e-8)
        pred1 <- logistic_growth(t_new,exp(par1[1]),exp(par1[2]),0)
        (pred1-pred)/(par1[i]-pars[i])
      }, opt$par, t_new-t0, pred) |>
        Reduce(f = cbind) |> 
        apply(1,function(vec, hess,samp_var,pred_inter){
          sqrt(t(vec) %*% solve(hess, (vec))+samp_var * pred_inter)
        }, opt$hessian, pars[3]^2, pred_inter)
    }
    else the_se <- NA
    
  }
  
  return(list(opt = opt, pred = pred, se = the_se))
}

root_3rd_der <- function(r,p0, invK, t0 = 1980){
  ap  <- invK * p0
  inside <- sqrt(3) * sqrt(ap^6 - 4 * ap^5 + 6*ap^4 - 4 * ap^3 + ap^2 ) 
  outside <- -2 * ap^3 +4 * ap^2 - 2 * ap
  
  x1 <- log((inside+outside)/(ap^3-ap^2))/r
  x2 <- log((outside-inside)/(ap^3-ap^2))/r
  return(c(x1,x2)+t0)
  
}


# logistic vs exponential, for sensitivity, we can exclude the harvest year or all year after them
logistic_mod <- fit_pois_mod(wolf$Winter.Minimum.Count[-c(34:41)]
                             , wolf$year[-c(34:41)]
                             , wolf$year
                             )
exponential_mod <- fit_pois_mod(wolf$Winter.Minimum.Count[-c(34:41)]
                                , wolf$year[-c(34:41)]
                                , wolf$year
                                , dd = FALSE)

# see fitting


#pdf("./figs/population_overall.pdf", width = 6, height = 3.5)
pdf("./figs/population_overall.pdf", width = 6, height = 2.5)
par(mar = c(3,3,2,2), mgp = c(1.8, 0.5, 0))
plot(wolf$year
     ,logistic_mod$pred, type = "l", ylab = "Population", xlab = 'Year', ylim = c(0,1300))


polygon(x = c(wolf$year, rev(wolf$year)),
        y = c(logistic_mod$pred - qnorm(0.975)*logistic_mod$se, 
              rev(logistic_mod$pred + qnorm(0.975)*logistic_mod$se)),
        col =  adjustcolor("black", alpha.f = 0.10), border = NA)


points(wolf$year[-c(34:41)]
       ,wolf$Winter.Minimum.Count[-c(34:41)]
       )
points(wolf$year[c(34:41)]
       ,wolf$Winter.Minimum.Count[c(34:41)]
       ,pch = 7
)

points(wolf$year[c(36:41)]-4
       ,wolf$Winter.Minimum.Count[c(36:41)]
       ,pch = 7,col = "red"
)

text(x = wolf$year[34:35], 
     y = wolf$Winter.Minimum.Count[c(34:35)], labels = c("*","*"), 
     pos = 1, offset = 0.3)

abline(h = 46494* 0.0254, lty = 2)
abline(h = 43119* 0.0254, lty = 2)
abline(h = 40798* 0.0254, lty = 2)
abline(h = exp(-logistic_mod$opt$par[3]), lty = 3)
polygon(x = c(1900,2030,2030,1099),
        y = c(rep(1/exp(logistic_mod$opt$par[3]+1.96*sqrt((solve(logistic_mod$opt$hessian))[3,3])),2), 
              rep(1/exp(logistic_mod$opt$par[3]-1.96*sqrt((solve(logistic_mod$opt$hessian))[3,3])), 2)),
        col =  adjustcolor("black", alpha.f = 0.10), border = NA)


text(2006,50000 * 0.0254,"Stauffer et al. 2021")
text(2006,43500* 0.0254,"Gantchoff et al. 2022")
text(2006,38000* 0.0254,"Mladenoff et al. 2009")
text(2018,exp(-logistic_mod$opt$par[3])-30,"'K'")


#lines(wolf$year
#      ,exponential_mod$pred
#      , lty = 2)
#points(wolf$year,wolf$Winter.Minimum.Count)
legend("topleft",legend = c("observed:pre-hunting","observed:post-hunting",
                            "shift 2015-2020 to 2011",
                            "logistic"), 
       lty = c(NA,NA,NA,1), pch = c(1,7,7,NA), col = c("black","black","red","black"),
       bg = "white")

dev.off()

# likelihood ratio test
likelihood_ratio <- 2*(exponential_mod$opt$value-logistic_mod$opt$value)
pchisq(likelihood_ratio,1, lower.tail = F, log.p = T)

# check prediction by moving 2015 to 2011:
sqrt(mean((logistic_mod$pred[(1980:2030)%in% c(2011:2016)] - 
        wolf$Winter.Minimum.Count[wolf$year %in% c(2015:2020)])^2))/mean(wolf$Winter.Minimum.Count[wolf$year %in% c(2015:2020)])

# is range expansion also logistic?
logistic_range <- fit_norm_mod(wolf_range$Winter.Minimum.Count[-c(34:41)]
                               , wolf_range$year[-c(34:41)]
                               , wolf_range$year
                               )
exponential_range <- fit_norm_mod(wolf_range$Winter.Minimum.Count[-c(34:41)]
                                  , wolf_range$year[-c(34:41)]
                                  , wolf_range$year
                                  ,dd = F, se = F)

pdf("./figs/range_overall.pdf", width = 6, height = 2.5)
par(mar = c(3,3,2,2), mgp = c(1.8, 0.5, 0))
plot(wolf_range$year
     ,logistic_range$pred, type = "l", ylab = "Range", xlab = 'Year', ylim = c(0,500+ exp(-logistic_range$opt$par[3])))

polygon(x = c(wolf$year, rev(wolf$year)),
        y = c(logistic_range$pred - qnorm(0.975)*logistic_range$se, 
              rev(logistic_range$pred + qnorm(0.975)*logistic_range$se)),
        col =  adjustcolor("black", alpha.f = 0.10), border = NA)

points(wolf_range$year[-c(34:41)]
       ,wolf_range$Winter.Minimum.Count[-c(34:41)]
       )
points(wolf_range$year[c(34:41)]
       ,wolf_range$Winter.Minimum.Count[c(34:41)]
       ,pch = 7
)
points(wolf_range$year[c(36:41)]-4
       ,wolf_range$Winter.Minimum.Count[c(36:41)]
       ,pch = 7
       ,col = "red"
)

text(x = wolf_range$year[34:35], 
     y = wolf_range$Winter.Minimum.Count[c(34:35)], labels = c("*","*"), 
     pos = 1, offset = 0.3)

#lines(wolf_range$year
#      ,exponential_range$pred
#      ,lty = 2
     
#      )
abline(h = 46494, lty = 2)
abline(h = 43119, lty = 2)
abline(h = 40798, lty = 2)
abline(h = exp(-logistic_range$opt$par[3]), lty = 3)
polygon(x = c(1900,2030,2030,1099),
        y = c(rep(1/ 2.132056e-05,2), 
              rep(1/1.125668e-05, 2)),
        col =  adjustcolor("black", alpha.f = 0.10), border = NA)


text(2006,50000,"Stauffer et al. 2021")
text(2006,43500,"Gantchoff et al. 2022")
text(2006,38000,"Mladenoff et al. 2009")
text(2018,exp(-logistic_range$opt$par[3])-500,"'K'")


legend("topleft",legend = c("observed:pre-hunting","observed:post-hunting",
                            "shift 2015-2020 to 2011",
                            "logistic"), 
       lty = c(NA,NA,NA,1), pch = c(1,7,7,NA), col = c("black","black","red","black"), 
       bg = "white")

dev.off()

likelihood_ratio_range <- 2*(exponential_range$opt$value-logistic_range$opt$value)
pchisq(likelihood_ratio_range,1, lower.tail = F, log.p = T)

last_decade <- data.frame(year = 2000:2020, density = (wolf$Winter.Minimum.Count/wolf_range$Winter.Minimum.Count)[year>=2000])

## check predict:
# check prediction by moving 2015 to 2011:
sqrt(mean((logistic_range$pred[(1980:2030)%in% c(2011:2016)] - 
             wolf_range$Winter.Minimum.Count[wolf$year %in% c(2015:2020)])^2))/mean(wolf_range$Winter.Minimum.Count[wolf$year %in% c(2015:2020)])


# what's the predicted range capacity? and CI
1/exp(logistic_range$opt$par[3])
1/exp(logistic_range$opt$par[3]+1.96*sqrt((solve(logistic_range$opt$hessian))[3,3]))
1/exp(logistic_range$opt$par[3]-1.96*sqrt((solve(logistic_range$opt$hessian))[3,3]))

## K of population calculated by range:
mean(last_decade$density)/exp(logistic_range$opt$par[3])
mean(last_decade$density)/exp(logistic_range$opt$par[3]+1.96*sqrt((solve(logistic_range$opt$hessian))[3,3]))
mean(last_decade$density)/exp(logistic_range$opt$par[3]-1.96*sqrt((solve(logistic_range$opt$hessian))[3,3]))



# is it coincide with the population level K and the observed equalibrium density?

## population K
1/exp(logistic_mod$opt$par[3])
1/exp(logistic_mod$opt$par[3]+1.96*sqrt((solve(logistic_mod$opt$hessian))[3,3]))
1/exp(logistic_mod$opt$par[3]-1.96*sqrt((solve(logistic_mod$opt$hessian))[3,3]))

1/exp(logistic_mod$opt$par[3])/mean(last_decade$density)
1/exp(logistic_mod$opt$par[3]+1.96*sqrt((solve(logistic_mod$opt$hessian))[3,3]))/mean(last_decade$density)
1/exp(logistic_mod$opt$par[3]-1.96*sqrt((solve(logistic_mod$opt$hessian))[3,3]))/mean(last_decade$density)

## CI on K estimated using different method
CI_K <- data.frame(matrix(NA, 3,4))
colnames(CI_K) <- c("method", "K", "low","high")
CI_K[,1] <- c("Population","Range","C&T2016-logistic")
CI_K$K <- c(1/exp(logistic_mod$opt$par[3]),
            mean(last_decade$density)/exp(logistic_range$opt$par[3]),
            1093
            )
CI_K$low = c(1/exp(logistic_mod$opt$par[3]+1.64*sqrt((solve(logistic_mod$opt$hessian))[3,3])),
             mean(last_decade$density)/exp(logistic_range$opt$par[3]+1.64*sqrt((solve(logistic_range$opt$hessian))[3,3])),
             591)
CI_K$high <- c(1/exp(logistic_mod$opt$par[3]-1.64*sqrt((solve(logistic_mod$opt$hessian))[3,3])),
               mean(last_decade$density)/exp(logistic_range$opt$par[3]-1.64*sqrt((solve(logistic_range$opt$hessian))[3,3])),
               2405)



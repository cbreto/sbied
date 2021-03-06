#' ---
#' title: "Likelihood by direct simulation: boarding school flu"
#' author: "Aaron A. King and Edward L. Ionides"
#' output:
#'   html_document:
#'     toc: yes
#'     toc_depth: 4
#' bibliography: ../sbied.bib
#' csl: ../ecology.csl
#' ---
#' 
#' \newcommand\prob[1]{\mathbb{P}\left[{#1}\right]}
#' \newcommand\expect[1]{\mathbb{E}\left[{#1}\right]}
#' \newcommand\var[1]{\mathrm{Var}\left[{#1}\right]}
#' \newcommand\dist[2]{\mathrm{#1}\left(#2\right)}
#' \newcommand\dd[1]{d{#1}}
#' \newcommand\dlta[1]{{\Delta}{#1}}
#' \newcommand\lik{\mathcal{L}}
#' \newcommand\loglik{\ell}
#' 
#' -----------------------------------
#' 
#' [Licensed under the Creative Commons Attribution-NonCommercial license](http://creativecommons.org/licenses/by-nc/4.0/).
#' Please share and remix noncommercially, mentioning its origin.  
#' ![CC-BY_NC](../graphics/cc-by-nc.png)
#' 
#' Produced in R version `r getRversion()`.
#' 
#' -----------------------------------
#' 
## ----prelims,include=FALSE,cache=FALSE-----------------------------------
options(
  keep.source=TRUE,
  stringsAsFactors=FALSE,
  encoding="UTF-8"
  )

set.seed(594709947L)
library(ggplot2)
theme_set(theme_bw())
library(plyr)
library(reshape2)
library(magrittr)
library(pomp)
stopifnot(packageVersion("pomp")>="1.6")

#' 
#' * We're going to demonstrate what happens when we attempt to compute the likelihood for the boarding school flu data by direct simulation from.
#' 
#' * First, let's reconstruct the toy SIR model we were working with.
#' 
## ----flu-construct-------------------------------------------------------
read.table("http://kingaa.github.io/sbied/stochsim/bsflu_data.txt") -> bsflu

rproc <- Csnippet("
  double N = 763;
  double t1 = rbinom(S,1-exp(-Beta*I/N*dt));
  double t2 = rbinom(I,1-exp(-mu_I*dt));
  double t3 = rbinom(R1,1-exp(-mu_R1*dt));
  double t4 = rbinom(R2,1-exp(-mu_R2*dt));
  S  -= t1;
  I  += t1 - t2;
  R1 += t2 - t3;
  R2 += t3 - t4;
")

init <- Csnippet("
  S = 762;
  I = 1;
  R1 = 0;
  R2 = 0;
")

dmeas <- Csnippet("
  lik = dpois(B,rho*R1+1e-6,give_log);
")

rmeas <- Csnippet("
  B = rpois(rho*R1+1e-6);
")

pomp(subset(bsflu,select=-C),
     times="day",t0=0,
     rprocess=euler.sim(rproc,delta.t=1/5),
     initializer=init,rmeasure=rmeas,dmeasure=dmeas,
     statenames=c("S","I","R1","R2"),
     paramnames=c("Beta","mu_I","mu_R1","mu_R2","rho")) -> flu

#' 
#' Let's generate a large number of simulated trajectories at some particular point in parameter space.
## ----bbs-mc-like-2-------------------------------------------------------
simulate(flu,params=c(Beta=3,mu_I=1/2,mu_R1=1/4,mu_R2=1/1.8,rho=0.9),
         nsim=5000,states=TRUE) -> x
matplot(time(flu),t(x["R1",1:50,]),type='l',lty=1,
        xlab="time",ylab=expression(R[1]),bty='l',col='blue')
lines(time(flu),obs(flu,"B"),lwd=2,col='black')

#' 
#' We can use the function `dmeasure` to evaluate the log likelihood of the data given the states, the model, and the parameters:
## ----bbs-mc-like-3,cache=T-----------------------------------------------
ell <- dmeasure(flu,y=obs(flu),x=x,times=time(flu),log=TRUE,
                params=c(Beta=3,mu_I=1/2,mu_R1=1/4,mu_R2=1/1.8,rho=0.9))
dim(ell)

#' According to the general equation for likelihood by direct simulation, we should sum up the log likelihoods across time:
## ----bbs-mc-like-4-------------------------------------------------------
ell <- apply(ell,1,sum)
summary(exp(ell))

#' 
#' - The variability in the individual likelihoods is high and therefore the likelihood esitmate is imprecise.
#' We will need many simulations to get an estimate of the likelihood sufficiently precise to be of any use in parameter estimation or model selection.
#' 
#' - What is the problem?
#' 
#' - Essentially, very few of the trajectories pass anywhere near the data and therefore almost all have extremely bad likelihoods.
#' Moreover, once a trajectory diverges from the data, it almost never comes back.
#' While the calculation is "correct" in that it will converge to the true likelihood as the number of simulations tends to $\infty$, we waste a lot of effort investigating trajectories of very low likelihood.
#' 
#' - This is a consequence of the fact that we are proposing trajectories in a way that is completely unconditional on the data.
#' 
#' - The problem will get much worse with longer data sets.

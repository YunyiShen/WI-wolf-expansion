data {
    int<lower = 0> N_year; // number of years
    int<lower = 0> min_count[N_year]; //winter minimum count
    int<lower = 0> max_count[N_year]; //winter maximum count
    int<lower = 0> H_t[N_year]; //harvest
    int<lower = 0> D_t[N_year]; //days culled
}

parameters {
    
    real<lower = 0, upper = 0.5> sigma_proc;
    real<lower = 0> gamma;
    real beta_0;
    real beta_1; //the "policy signal", useful in non-null's 
    //real linvK; // inverse carrying capacity
    real<lower = 0, upper = 1> o_min; //detection rate for min
    real<lower = 1, upper = 10> o_max; //detection multiplier for max
    real<lower = 0> sigma_obs_min; // observ error
    real<lower = 0> sigma_obs_max; // observ error
    real mu_0; //baseline year 
    
    // some rather local ones
    vector<lower = 0>[N_year] N_t; // true population
    vector<lower = 0>[N_year] psi_t_min; // mean observed
    vector<lower = 0>[N_year] psi_t_max;
    
}

model {
    // some useful local variables
    real mu_t; // expected population
    real r_t;// population growth rate

    // priors, hyper parameters from their supp
    sigma_proc ~ uniform(0 , 0.5);
    gamma ~ normal(1.06, 0.267261); // sqrt(1/14)
    beta_0 ~ normal(0 , 1e3);
    beta_1 ~ normal(0 , 1e3);
    sigma_obs_min ~ uniform(0,100);
    sigma_obs_max ~ uniform(0,100);

    o_min~uniform(0,1); // these two are slightly different but should not cause problem
    o_max~uniform(1,10); 
    
    mu_0 ~ normal(0,1e3);

    // linvK ~ normal(0,1000)

    // likelihood
    N_t[1] ~ lognormal(mu_0,sigma_proc);

    for(tt in 1:N_year){
        // this years observation 
        //print(psi_t_min);
        target += gamma_lpdf(psi_t_min[tt] | (N_t[tt]/sigma_obs_min)^2, N_t[tt]/((sigma_obs_min)^2) );
        target += gamma_lpdf(psi_t_max[tt] | (N_t[tt]/sigma_obs_max)^2, N_t[tt]/((sigma_obs_max)^2) );
        target += poisson_lpmf(min_count[tt] | o_min * psi_t_min[tt]);
        target += poisson_lpmf(max_count[tt] | o_max * psi_t_max[tt]);
        // things about grwoth 
        if(tt < N_year){
            //r_t = beta_0; // growth rate
            r_t = beta_0 + beta_1 * D_t[tt];
            mu_t = log(N_t[tt] * exp(r_t) - gamma * H_t[tt+1]); // exponential grwoth
            //print(tt);
            //print(mu_t);
            // mu_t = log(N_t[tt] * exp(r_t) * (1-exp(linvK) * N_t[tt]) - gamma * H_t[tt]) // logistic
            N_t[tt+1] ~ lognormal(mu_t, sigma_proc);
        }

    }

}




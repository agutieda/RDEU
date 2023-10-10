function estOutput = estimate_pooled(estInput)
% Estimate parameters of RUM model, given DMPL data, and compute their standard
% errors clustered at the subject level

% Compute maximum and minimum possible payoffs in each lottery
menuR = estInput.menuTab(1:40,:);
cMax = nan(40,1);
cMin = nan(40,1);
for jMenu = 1:40
    % Maximum possible payoff
    cMax(jMenu) = menuR.x1_L1(jMenu);
    if menuR.x2_L1(jMenu) > cMax(jMenu) && menuR.p_L1(jMenu) < 1
        cMax(jMenu) = menuR.x2_L1(jMenu);
    end
    if menuR.x1_L2(jMenu) > cMax(jMenu)
        cMax(jMenu) = menuR.x1_L2(jMenu);
    end
    if menuR.x2_L2(jMenu) > cMax(jMenu) && menuR.p_L2(jMenu) < 1
        cMax(jMenu) = menuR.x2_L2(jMenu);
    end
    % Minimum possible payoff
    cMin(jMenu) = menuR.x1_L1(jMenu);
    if menuR.x2_L1(jMenu) < cMin(jMenu) && menuR.p_L1(jMenu) < 1
        cMin(jMenu) = menuR.x2_L1(jMenu);
    end
    if menuR.x1_L2(jMenu) < cMin(jMenu)
        cMin(jMenu) = menuR.x1_L2(jMenu);
    end
    if menuR.x2_L2(jMenu) < cMin(jMenu) && menuR.p_L2(jMenu) < 1
        cMin(jMenu) = menuR.x2_L2(jMenu);
    end
end
estInput.cMax = cMax;
estInput.cMin = cMin;

% Define objective function
obj_fun = @(x) -loglike_fun(x, estInput);

% Optimize over a list of initial values using fminsearch
theta_hat_i_list = nan(size(estInput.theta_0));
loglike_i_list   = nan(size(estInput.theta_0, 1), 1);
for i = 1:size(estInput.theta_0, 1)
    [theta_hat_i_list(i, :), loglike_i_list(i)] = ...
        fminsearch(obj_fun, estInput.theta_0(i, :), estInput.opt_x0);
end

% Choose value with lowest log-likelihood
[~, i_min] = min(loglike_i_list);
theta_0 = theta_hat_i_list(i_min, :);

% Maximize log-likelihood function using a quasi-newton method
[theta_hat, ~, exitflag, ~, ~, hessian_loglike] = ...
    fminunc(obj_fun, theta_0, estInput.optFminunc_mle);

% Warn in case of non-convergence
if exitflag <= 0
    warning('MLE did not converge');
end

% Loglikelihood at MLE
[logLike, logLike_R, logLike_T, rho_L1_R, rho_L1_T, ...
    rhoObs_L1_R, rhoObs_L1_T, ] = loglike_fun(theta_hat, estInput);

% Compute robust standard errors of estimated parameters
cluster_var   = estInput.obsTab.subjectID;
Cov_theta_hat = compute_se(@loglike_fun, ...
    theta_hat, -hessian_loglike, cluster_var, 'robust', estInput);
se_theta_hat = diag(sqrt(Cov_theta_hat))' ;

% Display results
fprintf('Pooled Estimates:\n');
fprintf(...
    'mu_ra:%g sig_ra:%g mu_dr:%g sig_dr:%g logLike:%g \n', ...
    round(theta_hat(1),3), round(theta_hat(2),3), ...
    round(theta_hat(3),3), round(theta_hat(4),3), ...
    round(logLike,3));
fprintf('\n');

% Store results in structure
estOutput = struct( ...
    'theta_hat', theta_hat, ...
    'se_theta_hat', se_theta_hat, ...
    'logLike', logLike, ...
    'logLike_R', logLike_R, ...
    'logLike_T', logLike_T, ...
    'rho_L1_R', rho_L1_R, ...
    'rho_L1_T', rho_L1_T, ...
    'rhoObs_L1_R', rhoObs_L1_R, ...
    'rhoObs_L1_T', rhoObs_L1_T, ...
    'exitFlag', exitflag, ...
    'nObs', size(estInput.obsTab,1) );

end
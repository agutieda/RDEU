function est_output = estimate_subject(estInput)
% Estimate parameters of RDEU model using DMPL data by subject

obsTab = estInput.obsTab;
subjectList = unique(obsTab.subjectID);
nSubjects = length(subjectList);

% Initialize matrices to store results
theta_hat = nan(nSubjects, 5);
logLike = nan(nSubjects, 1);
logLike_R = nan(nSubjects, 1);
logLike_T = nan(nSubjects, 1);
exitFlag = nan(nSubjects, 1);
pdfCheck = nan(nSubjects, 1);
nObs_vec = nan(nSubjects, 1);

% Define integration interval, nodes and weights
rMin   = -10;
rMax   =  10;
nNodes = estInput.nNodes;
rNodes = linspace(rMin, rMax, nNodes)';
rNodes(rNodes==1) = 1 + 1e-12;
estInput.rWeights = ones(nNodes, 1) * (rMax - rMin)./ nNodes;
estInput.rNodes = rNodes;
estInput.nNodes = nNodes;

% Compute thresholds for every risk and time menu
estInput = compute_thresholds(estInput);

% Loop over subjects
for iSubj = 1:nSubjects

    % Get data for subject iSubj
    estInput_i = estInput;
    estInput_i.obsTab = obsTab(obsTab.subjectID == subjectList(iSubj), :);

    % Take initial values from switching points
    mu_ra_0_i  = estInput_i.riskEst_SP.avg_ra(iSubj);
    sig_ra_0_i = estInput_i.riskEst_SP.std_ra(iSubj);
    mu_dr_0_i  = estInput_i.timeEst_SP.avg_dr(iSubj);
    sig_dr_0_i = estInput_i.timeEst_SP.std_dr(iSubj);

    % Add to list of initial values
    if size(estInput_i.theta_0, 2) == 5
            theta_0_i = [ estInput_i.theta_0;
        mu_ra_0_i, sig_ra_0_i, mu_dr_0_i, sig_dr_0_i,     0;
        mu_ra_0_i, sig_ra_0_i, mu_dr_0_i, sig_dr_0_i,  0.99;
        mu_ra_0_i, sig_ra_0_i, mu_dr_0_i, sig_dr_0_i, -0.99;
        mu_ra_0_i, sig_ra_0_i, mu_dr_0_i, sig_dr_0_i,  0.50;
        mu_ra_0_i, sig_ra_0_i, mu_dr_0_i, sig_dr_0_i, -0.50;
        mu_ra_0_i, sig_ra_0_i, mu_dr_0_i, sig_dr_0_i,  0.25;
        mu_ra_0_i, sig_ra_0_i, mu_dr_0_i, sig_dr_0_i, -0.25;
        ];
    else
        theta_0_i = [ estInput_i.theta_0;
        mu_ra_0_i, sig_ra_0_i, mu_dr_0_i, sig_dr_0_i];
    end

    % Define objective function
    obj_fun_i = @(x) -loglike_fun(x, estInput_i);

    % Optimize over a list of initial values using fminsearch
    theta_hat_i_list = nan(size(theta_0_i));
    loglike_i_list   = nan(size(theta_0_i, 1), 1);
    for i = 1:size(theta_0_i, 1)

        [theta_hat_i_list(i, :), loglike_i_list(i)] = ...
            fminsearch(obj_fun_i, theta_0_i(i, :), estInput_i.opt_x0);

        [~, ~, ~, pdfCheck_i] = loglike_fun(theta_hat_i_list(i, :), estInput_i);

        if abs(pdfCheck_i-1)>0.01
            loglike_i_list(i) = nan;
        end

    end

    % Choose initial value with lowest log-likelihood
    [~, i_min] = min(loglike_i_list);
    theta_0_i = theta_hat_i_list(i_min, :);

    % Maximize log-likelihood function using a gradient-free method
    [theta_hat_i, ~, exitFlag(iSubj)] = ...
        fminsearch(obj_fun_i, theta_0_i, estInput_i.optFminsearch_mle);

    % Loglikelihood at MLE
    [logLike(iSubj), logLike_R(iSubj), logLike_T(iSubj), pdfCheck(iSubj)] = ...
        loglike_fun(theta_hat_i, estInput_i);

    % If discretized PDF doesn't add to 1, refine nodes
    if abs(pdfCheck(iSubj)-1) > 0.01 || theta_hat_i(2) < 0.05

        rMin   = theta_hat_i(1) - 10*theta_hat_i(2);
        rMax   = theta_hat_i(1) + 10*theta_hat_i(2);
        nNodes = estInput_i.nNodes;
        rNodes = linspace(rMin, rMax, nNodes)';
        rNodes(rNodes==1) = 1 + 1e-12;
        estInput_i.rWeights = ones(nNodes, 1) * (rMax - rMin)./ nNodes;
        estInput_i.rNodes = rNodes;
        estInput_i.nNodes = nNodes;

        % Compute thresholds for every risk and time menu again
        estInput_i = compute_thresholds(estInput_i);

        % Define objective function again
        obj_fun_i = @(x) -loglike_fun(x, estInput_i);

        % Maximize log-likelihood function using a gradient-free method
        [theta_hat_i, ~, exitFlag(iSubj)] = ...
            fminsearch(obj_fun_i, theta_hat_i, estInput_i.optFminsearch_mle);

        % Loglikelihood at MLE
        [logLike(iSubj), logLike_R(iSubj), logLike_T(iSubj), pdfCheck(iSubj)] = ...
            loglike_fun(theta_hat_i, estInput_i);

    end

    if size(theta_hat_i,2) == 4
        theta_hat_i = [theta_hat_i,0];
    end

    theta_hat(iSubj, :) = theta_hat_i;
    nObs_vec(iSubj) = size(estInput_i.obsTab,1);

    % Display results of for this subject
    fprintf(...
        'Subject = %d of 202 mu_ra:%g sig_ra:%g mu_dr:%g sig_dr:%g rho:%g logLike:%g pdfCheck:%g \n', ...
        iSubj, round(theta_hat_i(1),3), round(theta_hat_i(2),3), ...
        round(theta_hat_i(3),3), round(theta_hat_i(4),3), ...
        round(theta_hat_i(5),3), round(logLike(iSubj),3), ...
        round(pdfCheck(iSubj),4) );

end

% Store results in structure
est_output = struct(...
    'subjectList',subjectList,...
    'theta_hat', theta_hat, ...
    'logLike', logLike, ...
    'logLike_R', logLike_R, ...
    'logLike_T', logLike_T, ...
    'exitFlag', exitFlag, ...
    'pdfCheck', pdfCheck, ...
    'nObs', nObs_vec );

end
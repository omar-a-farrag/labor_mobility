% gender_education_costs_asec.m
% Structural Estimation for Gender x Education Cross-Tabulations
clear;

% Declare globals for the penalty function
global apply_penalty target_nu_A target_nu_B bet;

% Using the Windows paths you set
%in_dir = 'Z:/research-eme/omar/Gary/mobility_project/data/clean/flows_wages_gender_educ/';
%out_dir = 'Z:/research-eme/omar/Gary/mobility_project/output/regression_results/gender_educ_asec/';
in_dir = '/if/research-eme/omar/Gary/mobility_project/data/clean/flows_wages_gender_educ/';
out_dir = '/if/research-eme/omar/Gary/mobility_project/output/regression_results/gender_educ_asec/';


%% --- 1. GET POOLED BASELINE NU ---
disp('>>> EXTRACTING BASELINE NU FROM POOLED DATA...');
try
    % Adjust this path if running on Windows (Z:/) or Linux (/if/)
    all_results = readmatrix('Z:/research-eme/omar/Gary/mobility_project/output/acm_replication/results_go_all.csv');
    target_nu_A = all_results(1);
    target_nu_B = all_results(5);
    fprintf('Found Baseline Nu: %.2f (Panel A), %.2f (Panel B)\n', target_nu_A, target_nu_B);
catch
    % Fallback if the file moved
    target_nu_A = 1.88; 
    target_nu_B = 1.45;
    fprintf('Could not find pooled results. Using defaults: %.2f (A), %.2f (B)\n', target_nu_A, target_nu_B);
end

%% --- 2. LOOP THROUGH SUBGROUPS ---
groups = {'male_nocollege', 'male_college', 'female_nocollege', 'female_college'};
for g = 1:length(groups)
    
    % Wipe workspace but preserve globals and loop variables
    clearvars -except groups g in_dir out_dir target_nu_A target_nu_B apply_penalty bet;
    
    group_name = groups{g};
    disp('======================================================');
    fprintf('>>> RUNNING INTERSECTIONAL PIPELINE: %s\n', upper(group_name));
    disp('======================================================');
    
    % --- LOAD AND SANITIZE DATA ---
    mij_file = sprintf('%smij_raw_%s.csv', in_dir, group_name);
    waget_file = sprintf('%swaget_%s.csv', in_dir, group_name);
    
    mij_raw = readmatrix(mij_file);
    waget = readmatrix(waget_file);
    
    mij_raw(isnan(mij_raw)) = 0.01;
    mij_raw(mij_raw == 0) = 0.01;
    
    valid_wages = waget(~isnan(waget));
    if ~isempty(valid_wages)
        waget(isnan(waget)) = mean(valid_wages);
    end
    
    % --- DYNAMIC TIME SENSING ---
    isize = 6;
    T = size(mij_raw, 1) / isize; 
    fprintf('    Detected T = %d years in sample.\n', T);
    
    mij_n = zeros(isize, isize, T);
    mij = zeros(isize, isize, T);
    for t = 1:T
        row_start = (t-1)*isize + 1;
        row_end = t*isize;
        
        counts_for_year = mij_raw(row_start:row_end, 1:isize);
        mij_n(:,:,t) = counts_for_year;
        
        row_sums = sum(counts_for_year, 2);
        row_sums(row_sums == 0) = 1; 
        mij(:,:,t) = counts_for_year ./ repmat(row_sums, 1, isize);
    end
    
    % --- RUN 1: UNRESTRICTED ESTIMATION ---
    disp('   -> Estimating Unrestricted Model...');
    apply_penalty = 0; % Penalty OFF
    xin_ = [2; 10]; 
    %run('Z:/research-eme/omar/Gary/mobility_project/code/acm_estimation/estim_go.m');
    run('/if/research-eme/omar/Gary/mobility_project/code/acm_estimation/estim_go.m');

    out_file_unres = sprintf('%sresults_go_%s_unrestricted.csv', out_dir, group_name);
    writematrix(sonuc, out_file_unres);
    
    % --- RUN 2: RESTRICTED ESTIMATION (PANEL C) ---
    disp('   -> Estimating Restricted Model (Fixed Nu)...');
    apply_penalty = 1; % Penalty ON
    xin_ = [2; 10]; 
    %run('Z:/research-eme/omar/Gary/mobility_project/code/acm_estimation/estim_go.m');
    run('/if/research-eme/omar/Gary/mobility_project/code/acm_estimation/estim_go.m');

    out_file_res = sprintf('%sresults_go_%s_restricted.csv', out_dir, group_name);
    writematrix(sonuc, out_file_res);
end
disp('>>> ALL INTERSECTIONAL ESTIMATIONS COMPLETE!');
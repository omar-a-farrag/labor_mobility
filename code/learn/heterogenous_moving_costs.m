% heterogenous_moving_costs.m
% Master Replication Wrapper: ACM Baseline + Broad Demographic Sub-Groups
clear;

% Initialize globals to prevent "Ghost in the Machine" leaks
global apply_penalty target_nu_A target_nu_B bet;
apply_penalty = 0; 

%% --- 1. RUN ORIGINAL ACM (2010) ESTIMATION ---
disp('======================================================');
disp('>>> RUNNING ORIGINAL ACM (2010) DATA PIPELINE...');
disp('======================================================');
run('/if/research-eme/omar/Gary/mobility_project/code/acm_estimation/estim.m')
% run('Z:/research-eme/omar/Gary/mobility_project/code/acm_estimation/estim.m')
writematrix(sonuc, '/if/research-eme/omar/Gary/mobility_project/output/acm_replication/results_acm_original.csv');
% writematrix(sonuc, 'Z:/research-eme/omar/Gary/mobility_project/output/acm_replication/results_acm_original.csv');

%% --- 2. RUN MODERN IPUMS SUB-GROUP PIPELINE ---
% Notice 'all' is first! This is critical so we can capture its Nu for the penalty.
groups = {'all', 'male', 'female', 'nocollege', 'college', 'whitecollar', 'bluecollar'};

for g = 1:length(groups)
    
    % Wipe workspace but preserve globals and loop variables
    clearvars -except groups g target_nu_A target_nu_B apply_penalty bet;
    
    group_name = groups{g};
    
    disp('======================================================');
    fprintf('>>> RUNNING IPUMS PIPELINE: %s\n', upper(group_name));
    disp('======================================================');
    
    % 1. Determine which CSV files to load
    if strcmp(group_name, 'all')
        mij_file = '/if/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/mij_raw.csv';
        waget_file = '/if/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/waget.csv';
        % mij_file = 'Z:/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/mij_raw.csv';
        % waget_file = 'Z:/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/waget.csv';
    else
        mij_file = sprintf('/if/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/mij_raw_%s.csv', group_name);
        waget_file = sprintf('/if/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/waget_%s.csv', group_name);
        %mij_file = sprintf('Z:/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/mij_raw_%s.csv', group_name);
        %waget_file = sprintf('Z:/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/waget_%s.csv', group_name);
    end
    
    % 2. Load the Data
    mij_raw = readmatrix(mij_file);
    waget = readmatrix(waget_file);
    
    % --- THE MISSING DATA FIX ---
    mij_raw(isnan(mij_raw)) = 0.01;
    mij_raw(mij_raw == 0) = 0.01;
    
    valid_wages = waget(~isnan(waget));
    if ~isempty(valid_wages)
        waget(isnan(waget)) = mean(valid_wages);
    end
    
    % 3. Reshape Arrays with DYNAMIC TIME SENSING
    isize = 6;
    T = size(mij_raw, 1) / isize; 
    fprintf('    Detected T = %d years in sample.\n', T);
    
    mij_n = zeros(isize, isize, T);
    mij = zeros(isize, isize, T);
    for t = 1:T
        row_start = (t-1)*isize + 1;
        row_end = t*isize;
        
        counts_for_year = mij_raw(row_start:row_end, 1:isize);
        counts_for_year(counts_for_year == 0) = 0.01;
        mij_n(:,:,t) = counts_for_year;
        
        row_sums = sum(counts_for_year, 2);
        row_sums(row_sums == 0) = 1; 
        mij(:,:,t) = counts_for_year ./ repmat(row_sums, 1, isize);
    end
    
    % --- RUN 1: UNRESTRICTED ESTIMATION ---
    disp('   -> Estimating Unrestricted Model...');
    apply_penalty = 0; % Penalty OFF
    xin_ = [2; 10]; 
    run('/if/research-eme/omar/Gary/mobility_project/code/acm_estimation/estim_go.m');     
    % run('Z:/research-eme/omar/Gary/mobility_project/code/acm_estimation/estim_go.m');     

    out_file_unres = sprintf('/if/research-eme/omar/Gary/mobility_project/output/acm_replication/results_go_%s_unrestricted.csv', group_name);
    % out_file_unres = sprintf('Z:/research-eme/omar/Gary/mobility_project/output/acm_replication/results_go_%s_unrestricted.csv', group_name);
    writematrix(sonuc, out_file_unres);
    
    % --- DYNAMIC PENALTY CAPTURE ---
    % If we just ran the 'all' group, save its Nu to memory to use on the rest!
    if strcmp(group_name, 'all')
        target_nu_A = sonuc(1);
        target_nu_B = sonuc(5);
        fprintf('    *** Captured Baseline Nu: %.2f (A), %.2f (B) ***\n', target_nu_A, target_nu_B);
    end

    % --- RUN 2: RESTRICTED ESTIMATION (PANEL C) ---
    disp('   -> Estimating Restricted Model (Fixed Nu)...');
    apply_penalty = 1; % Penalty ON
    xin_ = [2; 10]; 
    run('/if/research-eme/omar/Gary/mobility_project/code/acm_estimation/estim_go.m');
    % run('Z:/research-eme/omar/Gary/mobility_project/code/acm_estimation/estim_go.m');

    out_file_res = sprintf('/if/research-eme/omar/Gary/mobility_project/output/acm_replication/results_go_%s_restricted.csv', group_name);
    % out_file_res = sprintf('Z:/research-eme/omar/Gary/mobility_project/output/acm_replication/results_go_%s_restricted.csv', group_name);
    writematrix(sonuc, out_file_res);
end
disp('======================================================');
disp('>>> ALL BROAD ESTIMATIONS COMPLETE! CSVs READY FOR PYTHON.');
disp('======================================================');

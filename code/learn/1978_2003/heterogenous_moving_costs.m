% heterogenous_moving_costs.m
% Master Replication Wrapper: ACM Baseline + 6 Demographic Sub-Groups
clear;

%% --- 1. RUN ORIGINAL ACM (2010) ESTIMATION ---
disp('======================================================');
disp('>>> RUNNING ORIGINAL ACM (2010) DATA PIPELINE...');
disp('======================================================');

%estim;
run('/if/research-eme/omar/Gary/mobility_project/code/acm_estimation/estim.m')
writematrix(sonuc, '/if/research-eme/omar/Gary/mobility_project/output/acm_replication/results_acm_original.csv');

%% --- 2. RUN MODERN IPUMS SUB-GROUP PIPELINE ---
groups = {'all', 'male', 'female', 'nocollege', 'college', 'whitecollar', 'bluecollar'};

for g = 1:length(groups)
    
    % CRITICAL FIX: Wipe the workspace clean to prevent matrix bleeding, 
    % but preserve our loop variables!
    clearvars -except groups g;
    
    group_name = groups{g};
    
    disp('======================================================');
    fprintf('>>> RUNNING IPUMS PIPELINE: %s\n', upper(group_name));
    disp('======================================================');
    
    % 1. Determine which CSV files to load
    if strcmp(group_name, 'all')
        mij_file = '/if/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/mij_raw.csv';
        waget_file = '/if/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/waget.csv';
    else
        mij_file = sprintf('/if/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/mij_raw_%s.csv', group_name);
        waget_file = sprintf('/if/research-eme/omar/Gary/mobility_project/data/clean/flows_and_wages/waget_%s.csv', group_name);
    end
    
    % 2. Load the Data
    mij_raw = readmatrix(mij_file);
    waget = readmatrix(waget_file);
    
    % --- THE MISSING DATA FIX ---
    % Stata exports perfectly empty cells as '.' which MATLAB imports as NaN.
    % NaN breaks the math, so we convert them to our 0.01 epsilon!
    mij_raw(isnan(mij_raw)) = 0.01;
    mij_raw(mij_raw == 0) = 0.01;
    
    % If a sector had ZERO people in a year, Stata couldn't compute a wage.
    % We fill missing wages with the subgroup's overall average to prevent NaN crashes.
    valid_wages = waget(~isnan(waget));
    if ~isempty(valid_wages)
        waget(isnan(waget)) = mean(valid_wages);
    end
    
    % 3. Reshape the 2D CSV into the 3D Arrays ACM expects
    T = 26;
    isize = 6;
    mij_n = zeros(isize, isize, T);
    mij = zeros(isize, isize, T);

    for t = 1:T
        row_start = (t-1)*isize + 1;
        row_end = t*isize;
        
        counts_for_year = mij_raw(row_start:row_end, 1:isize);

        % --- THE EPSILON FIX: Prevent Structural Zeroes ---
        counts_for_year(counts_for_year == 0) = 0.01;


        mij_n(:,:,t) = counts_for_year;
        
        row_sums = sum(counts_for_year, 2);
        row_sums(row_sums == 0) = 1; 
        mij(:,:,t) = counts_for_year ./ repmat(row_sums, 1, isize);
    end

    % 4. Call the Structural GMM Estimation Script
    xin_ = [2; 10]; 
    estim_go;       
    
    % 5. Save the 1x8 results vector for Python
    out_file = sprintf('/if/research-eme/omar/Gary/mobility_project/output/acm_replication/results_go_%s.csv', group_name);
    writematrix(sonuc, out_file);
end

disp('======================================================');
disp('>>> ALL 8 ESTIMATIONS COMPLETE! CSVs READY FOR PYTHON.');
disp('======================================================');
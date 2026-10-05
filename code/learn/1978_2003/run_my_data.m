
% run_my_data.m
% Master Replication Wrapper: ACM (2010) vs Lyn and Farrag (2026)
clear;

%% --- 1. RUN ORIGINAL ACM (2010) ESTIMATION ---
disp('======================================================');
disp('>>> RUNNING ORIGINAL ACM (2010) PIPELINE...');
disp('======================================================');
% Note: The original estim.m will automatically load its own 
% 'mij_data_lin1' and 'cpi6701.txt' matrices.
estim;

% Save the 1x8 results vector to CSV for Python
writematrix(sonuc, 'results_acm_original.csv');


%% --- 2. RUN MODERN IPUMS PIPELINE (GARY & OMAR) ---
disp('======================================================');
disp('>>> RUNNING FARRAG & LYN IPUMS PIPELINE...');
disp('======================================================');
clear; % Clear workspace so original ACM matrices don't contaminate our run

% Load the freshly built IPUMS data from Stata
mij_raw = readmatrix('mij_raw.csv');
waget = readmatrix('waget.csv');

T = 26;
isize = 6;
mij_n = zeros(isize, isize, T);
mij = zeros(isize, isize, T);

% Reshape our CSV data into the 3D Arrays the GMM expects
for t = 1:T
    row_start = (t-1)*isize + 1;
    row_end = t*isize;
    
    counts_for_year = mij_raw(row_start:row_end, 1:isize);
    mij_n(:,:,t) = counts_for_year;
    
    row_sums = sum(counts_for_year, 2);
    row_sums(row_sums == 0) = 1; 
    mij(:,:,t) = counts_for_year ./ repmat(row_sums, 1, isize);
end

% Set starting values and run our modified script
xin_ = [2; 10];
estim_go;

% Save our 1x8 results vector to CSV for Python
writematrix(sonuc, 'results_go_ipums.csv');

disp('======================================================');
disp('>>> ESTIMATIONS COMPLETE! CSVs READY FOR PYTHON.');
disp('======================================================');
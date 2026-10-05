import pandas as pd
import numpy as np
import subprocess
import os

def generate_table_1():
    # =========================================================================
    # 1. DYNAMIC PARAMETERS (Change these when running different eras!)
    # =========================================================================
    START_YEAR = 1978
    END_YEAR = 2003
    
    # Paths
    results_dir = '/if/research-eme/omar/Gary/mobility_project/output/acm_replication/'
    out_dir = '/if/research-eme/omar/Gary/mobility_project/output/tables/heterogenous_workers_asec/'
    
    print(f">>> Compiling Broad Table for {START_YEAR}-{END_YEAR}...")
    
    try:
        # Load Legacy ACM (Unrestricted only)
        acm_orig = np.genfromtxt(os.path.join(results_dir, 'results_acm_original.csv'), delimiter=',')
        
        # Load Unrestricted Results
        all_u = np.genfromtxt(os.path.join(results_dir, 'results_go_all_unrestricted.csv'), delimiter=',')
        m_u = np.genfromtxt(os.path.join(results_dir, 'results_go_male_unrestricted.csv'), delimiter=',')
        f_u = np.genfromtxt(os.path.join(results_dir, 'results_go_female_unrestricted.csv'), delimiter=',')
        nc_u = np.genfromtxt(os.path.join(results_dir, 'results_go_nocollege_unrestricted.csv'), delimiter=',')
        c_u = np.genfromtxt(os.path.join(results_dir, 'results_go_college_unrestricted.csv'), delimiter=',')
        wc_u = np.genfromtxt(os.path.join(results_dir, 'results_go_whitecollar_unrestricted.csv'), delimiter=',')
        bc_u = np.genfromtxt(os.path.join(results_dir, 'results_go_bluecollar_unrestricted.csv'), delimiter=',')
        
        # Load Restricted Results
        all_r = np.genfromtxt(os.path.join(results_dir, 'results_go_all_restricted.csv'), delimiter=',')
        m_r = np.genfromtxt(os.path.join(results_dir, 'results_go_male_restricted.csv'), delimiter=',')
        f_r = np.genfromtxt(os.path.join(results_dir, 'results_go_female_restricted.csv'), delimiter=',')
        nc_r = np.genfromtxt(os.path.join(results_dir, 'results_go_nocollege_restricted.csv'), delimiter=',')
        c_r = np.genfromtxt(os.path.join(results_dir, 'results_go_college_restricted.csv'), delimiter=',')
        wc_r = np.genfromtxt(os.path.join(results_dir, 'results_go_whitecollar_restricted.csv'), delimiter=',')
        bc_r = np.genfromtxt(os.path.join(results_dir, 'results_go_bluecollar_restricted.csv'), delimiter=',')
        
    except FileNotFoundError as e:
        print(f">>> ERROR: Could not find one or more files. {e}")
        return

    def fmt(arr, idx): 
        if np.isnan(arr[idx]): return "NaN"
        return f"{arr[idx]:.2f}"
    def fmt_t(arr, idx): 
        if np.isnan(arr[idx]): return "(NaN)"
        return f"({arr[idx]:.2f})"
    
    # Normal builder for IPUMS 4-Panel data
    def build_col(unres, res):
        return [
            '', fmt(unres, 0), fmt_t(unres, 1), fmt(unres, 2), fmt_t(unres, 3), 
            '', fmt(unres, 4), fmt_t(unres, 5), fmt(unres, 6), fmt_t(unres, 7),
            '', fmt(res, 0), fmt_t(res, 1), fmt(res, 2), fmt_t(res, 3),
            '', fmt(res, 4), fmt_t(res, 5), fmt(res, 6), fmt_t(res, 7)
        ]
        
    # Special builder for legacy ACM (puts dashes in restricted panels)
    def build_acm_col(arr):
        return [
            '', fmt(arr, 0), fmt_t(arr, 1), fmt(arr, 2), fmt_t(arr, 3), 
            '', fmt(arr, 4), fmt_t(arr, 5), fmt(arr, 6), fmt_t(arr, 7),
            '', '--', '--', '--', '--',
            '', '--', '--', '--', '--'
        ]

    data = {
        'Parameter': [
            '\\textbf{\\textit{Panel A: Unrestricted ($\\beta = 0.97$)}}',
            'Shock Dispersion ($\\nu$)', '\\quad\\textit{t-statistic}',
            'Moving Cost ($C$)', '\\quad\\textit{t-statistic}',
            
            '\\midrule \\textbf{\\textit{Panel B: Unrestricted ($\\beta = 0.90$)}}',
            'Shock Dispersion ($\\nu$)', '\\quad\\textit{t-statistic}',
            'Moving Cost ($C$)', '\\quad\\textit{t-statistic}',
            
            '\\midrule \\textbf{\\textit{Panel C: Restricted ($\\beta = 0.97$)}}',
            'Shock Dispersion ($\\nu$)', '\\quad\\textit{t-statistic}',
            'Moving Cost ($C$)', '\\quad\\textit{t-statistic}',
            
            '\\midrule \\textbf{\\textit{Panel D: Restricted ($\\beta = 0.90$)}}',
            'Shock Dispersion ($\\nu$)', '\\quad\\textit{t-statistic}',
            'Moving Cost ($C$)' , '\\quad\\textit{t-statistic}'
        ],
        'ACM (2010)': build_acm_col(acm_orig),
        'All (IPUMS)': build_col(all_u, all_r),
        'Male': build_col(m_u, m_r),
        'Female': build_col(f_u, f_r),
        'No College': build_col(nc_u, nc_r),
        'College+': build_col(c_u, c_r),
        'Blue Collar': build_col(bc_u, bc_r),
        'White Collar': build_col(wc_u, wc_r)
    }

    df = pd.DataFrame(data)
    latex_tabular = df.to_latex(index=False, escape=False, column_format='lcccccccc')
    latex_tabular = "\\resizebox{\\textwidth}{!}{%\n" + latex_tabular + "}"
    
    latex_document = f"""\\documentclass[11pt]{{article}}
\\usepackage[margin=1in]{{geometry}}
\\usepackage{{booktabs}}
\\usepackage{{caption}}
\\usepackage{{graphicx}}

\\begin{{document}}
\\begin{{table}}[htbp]
\\centering
\\caption{{Broad Structural Estimation and Sub-Group Heterogeneity ({START_YEAR}--{END_YEAR})}}
\\label{{tab:acm_broad_hetero_{START_YEAR}_{END_YEAR}}}
{latex_tabular}
\\vspace{{1ex}}
\\raggedright
\\footnotesize
\\textbf{{Notes:}} Data represents the {START_YEAR}-{END_YEAR} IPUMS ASEC panel restricted to full-time, full-year workers. Panels A and B jointly estimate $C$ and $\\nu$. Panels C and D restrict $\\nu$ to the 'All (IPUMS)' aggregate baseline to allow direct comparison of moving costs across demographic groups. The legacy ACM (2010) column only features unrestricted estimation.
\\end{{table}}
\\end{{document}}
"""
    
    os.makedirs(out_dir, exist_ok=True)
    base_filename = f'table_1_broad_demographics_{START_YEAR}_{END_YEAR}'
    tex_filename = os.path.join(out_dir, f'{base_filename}.tex')
    
    with open(tex_filename, 'w') as f:
        f.write(latex_document)
    print(f">>> SUCCESS: '{tex_filename}' generated.")

    print(">>> Compiling LaTeX to PDF...")
    try:
        os.chdir(out_dir)
        result = subprocess.run(['pdflatex', '-interaction=nonstopmode', f'{base_filename}.tex'], 
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if result.returncode == 0:
            print(f">>> SUCCESS: PDF created in {out_dir}!")
            for ext in ['.aux', '.log']:
                cleanup_file = base_filename + ext
                if os.path.exists(cleanup_file):
                    os.remove(cleanup_file)
        else:
            print(">>> ERROR: pdflatex failed.")
    except Exception as e:
        print(f">>> WARNING: Compilation failed. {e}")

if __name__ == "__main__":
    generate_table_1()

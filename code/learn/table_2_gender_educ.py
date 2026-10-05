import pandas as pd
import numpy as np
import subprocess
import os

def generate_table():
    # =========================================================================
    # 1. DYNAMIC PARAMETERS (Change these when running different eras!)
    # =========================================================================
    START_YEAR = 1978
    END_YEAR = 2003
    
    # Point this to the folder where you stored this specific era's CSVs
    results_dir = '/if/research-eme/omar/Gary/mobility_project/output/regression_results/gender_educ_asec/'
    out_dir = '/if/research-eme/omar/Gary/mobility_project/output/tables/heterogenous_workers_asec/'
    
    print(f">>> Compiling Table for {START_YEAR}-{END_YEAR}...")
    
    try:
        # Load Unrestricted Results
        m_no_col_u = np.genfromtxt(os.path.join(results_dir, 'results_go_male_nocollege_unrestricted.csv'), delimiter=',')
        m_col_u = np.genfromtxt(os.path.join(results_dir, 'results_go_male_college_unrestricted.csv'), delimiter=',')
        f_no_col_u = np.genfromtxt(os.path.join(results_dir, 'results_go_female_nocollege_unrestricted.csv'), delimiter=',')
        f_col_u = np.genfromtxt(os.path.join(results_dir, 'results_go_female_college_unrestricted.csv'), delimiter=',')
        
        # Load Restricted Results (Fixed Nu)
        m_no_col_r = np.genfromtxt(os.path.join(results_dir, 'results_go_male_nocollege_restricted.csv'), delimiter=',')
        m_col_r = np.genfromtxt(os.path.join(results_dir, 'results_go_male_college_restricted.csv'), delimiter=',')
        f_no_col_r = np.genfromtxt(os.path.join(results_dir, 'results_go_female_nocollege_restricted.csv'), delimiter=',')
        f_col_r = np.genfromtxt(os.path.join(results_dir, 'results_go_female_college_restricted.csv'), delimiter=',')
        
    except FileNotFoundError as e:
        print(f">>> ERROR: Could not find one or more files in {results_dir}. {e}")
        return

    def fmt(arr, idx): return f"{arr[idx]:.2f}"
    def fmt_t(arr, idx): return f"({arr[idx]:.2f})"
    
    def build_col(unres, res):
        return [
            '', fmt(unres, 0), fmt_t(unres, 1), fmt(unres, 2), fmt_t(unres, 3), 
            '', fmt(unres, 4), fmt_t(unres, 5), fmt(unres, 6), fmt_t(unres, 7),
            '', fmt(res, 0), fmt_t(res, 1), fmt(res, 2), fmt_t(res, 3),
            '', fmt(res, 4), fmt_t(res, 5), fmt(res, 6), fmt_t(res, 7)
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
            'Moving Cost ($C$)', '\\quad\\textit{t-statistic}'
        ],
        'Male: No College': build_col(m_no_col_u, m_no_col_r),
        'Male: College+': build_col(m_col_u, m_col_r),
        'Female: No College': build_col(f_no_col_u, f_no_col_r),
        'Female: College+': build_col(f_col_u, f_col_r)
    }

    df = pd.DataFrame(data)
    latex_tabular = df.to_latex(index=False, escape=False, column_format='lcccc')
    latex_tabular = "\\resizebox{\\textwidth}{!}{%\n" + latex_tabular + "}"
    
    # --- DYNAMIC LATEX DOCUMENT ---
    # Notice the {START_YEAR}--{END_YEAR} in the caption!
    latex_document = f"""\\documentclass[11pt]{{article}}
\\usepackage[margin=1in]{{geometry}}
\\usepackage{{booktabs}}
\\usepackage{{caption}}
\\usepackage{{graphicx}}

\\begin{{document}}
\\begin{{table}}[htbp]
\\centering
\\caption{{Intersectional Structural Heterogeneity: Gender by Education ({START_YEAR}--{END_YEAR})}}
\\label{{tab:acm_gender_educ_{START_YEAR}_{END_YEAR}}}
{latex_tabular}
\\vspace{{1ex}}
\\raggedright
\\footnotesize
\\textbf{{Notes:}} Data represents orthogonal cuts of the {START_YEAR}-{END_YEAR} IPUMS ASEC panel restricted to full-time, full-year workers. Panels A and B present unrestricted baseline estimates where parameters $C$ and $\\nu$ are jointly estimated. Panels C and D restrict the idiosyncratic shock dispersion ($\\nu$) to match the pooled aggregate baseline via penalty function estimation. This restriction aligns the scales of utility, allowing for a direct, 1-to-1 comparison of the moving cost parameter ($C$) across demographic groups.
\\end{{table}}
\\end{{document}}
"""
    
    os.makedirs(out_dir, exist_ok=True)
    
    # DYNAMIC FILE NAMING
    base_filename = f'table_2_gender_educ_{START_YEAR}_{END_YEAR}'
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
    generate_table()
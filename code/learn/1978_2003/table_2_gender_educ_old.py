import pandas as pd
import numpy as np
import subprocess
import os

def generate_table():
    # Define the new output directory
    out_dir = '/if/research-eme/omar/Gary/mobility_project/output/tables/heterogenous_workers_asec/'
    results_dir = '/if/research-eme/omar/Gary/mobility_project/output/regression_results/gender_educ_asec/'
    
    print(">>> Loading Intersectional MATLAB output...")
    try:
        m_no_col = np.genfromtxt(os.path.join(results_dir, 'results_go_male_nocollege.csv'), delimiter=',')
        m_col = np.genfromtxt(os.path.join(results_dir, 'results_go_male_college.csv'), delimiter=',')
        f_no_col = np.genfromtxt(os.path.join(results_dir, 'results_go_female_nocollege.csv'), delimiter=',')
        f_col = np.genfromtxt(os.path.join(results_dir, 'results_go_female_college.csv'), delimiter=',')
    except FileNotFoundError as e:
        print(f">>> ERROR: Could not find files. Run run_gender_educ.m first. {e}")
        return

    def fmt(arr, idx): return f"{arr[idx]:.2f}"
    def fmt_t(arr, idx): return f"({arr[idx]:.2f})"
    def build_col(arr):
        return [
            '', fmt(arr, 0), fmt_t(arr, 1), fmt(arr, 2), fmt_t(arr, 3), 
            '', fmt(arr, 4), fmt_t(arr, 5), fmt(arr, 6), fmt_t(arr, 7)
        ]

    data = {
        'Parameter': [
            '\\textbf{\\textit{Panel A: $\\beta = 0.97$}}',
            'Shock Dispersion ($\\nu$)', '\\quad\\textit{t-statistic}',
            'Moving Cost ($C$)', '\\quad\\textit{t-statistic}',
            '\\midrule \\textbf{\\textit{Panel B: $\\beta = 0.90$}}',
            'Shock Dispersion ($\\nu$)', '\\quad\\textit{t-statistic}',
            'Moving Cost ($C$)', '\\quad\\textit{t-statistic}'
        ],
        'Male: No College': build_col(m_no_col),
        'Male: College+': build_col(m_col),
        'Female: No College': build_col(f_no_col),
        'Female: College+': build_col(f_col)
    }

    df = pd.DataFrame(data)
    latex_tabular = df.to_latex(index=False, escape=False, column_format='lcccc')
    
    latex_document = f"""\\documentclass[11pt]{{article}}
\\usepackage[margin=1in]{{geometry}}
\\usepackage{{booktabs}}
\\usepackage{{caption}}

\\begin{{document}}
\\begin{{table}}[htbp]
\\centering
\\caption{{Intersectional Structural Heterogeneity: Gender by Education (1978--2003)}}
\\label{{tab:acm_gender_educ}}
{latex_tabular}
\\vspace{{1ex}}
\\raggedright
\\footnotesize
\\textbf{{Notes:}} Data represents purely orthogonal cuts of the 1978-2003 IPUMS ASEC panel. Moving costs ($C$) and shock dispersions ($\\nu$) are estimated by solving the structural Euler equations strictly within the specified demographic state space. Sample restricted to full-time, full-year workers.
\\end{{table}}
\\end{{document}}
"""
    
    # Save directly to the output folder
    tex_filename = os.path.join(out_dir, 'table_2_gender_educ.tex')
    with open(tex_filename, 'w') as f:
        f.write(latex_document)
    print(f">>> SUCCESS: '{tex_filename}' generated.")

    print(">>> Compiling LaTeX to PDF...")
    try:
        # We need to compile in the output directory so the aux files land there
        os.chdir(out_dir)
        result = subprocess.run(['pdflatex', '-interaction=nonstopmode', 'table_2_gender_educ.tex'], 
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if result.returncode == 0:
            print(f">>> SUCCESS: PDF created in {out_dir}!")
            for ext in ['.aux', '.log']:
                cleanup_file = 'table_2_gender_educ' + ext
                if os.path.exists(cleanup_file):
                    os.remove(cleanup_file)
        else:
            print(">>> ERROR: pdflatex failed.")
    except Exception as e:
        print(f">>> WARNING: Compilation failed. {e}")

if __name__ == "__main__":
    generate_table()
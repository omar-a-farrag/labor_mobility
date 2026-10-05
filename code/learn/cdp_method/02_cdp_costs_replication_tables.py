import os
import csv
import subprocess

class LaTeXTableBuilder:
    def __init__(self, project_root):
        self.results_dir = os.path.join(project_root, "output", "regression_results")
        self.tables_dir = os.path.join(project_root, "output", "tables")
        os.makedirs(self.tables_dir, exist_ok=True)

    def format_4col_esttab_to_latex(self, ds_name):
        csv_filename = f"cdp_estimates_{ds_name}.csv"
        tex_filename = f"table_cdp_{ds_name}.tex"
        
        csv_path = os.path.join(self.results_dir, csv_filename)
        tex_path = os.path.join(self.tables_dir, tex_filename)
        standalone_tex_path = os.path.join(self.tables_dir, f"standalone_{tex_filename}")

        if not os.path.exists(csv_path):
            return

        with open(csv_path, 'r', encoding='utf-8') as f:
            raw_rows = list(csv.reader(f))

        latex_body = []
        coeffs = {"cont_val": [None, None, None, None], "wage_diff": [None, None, None, None]}

        for row in raw_rows:
            if not any(row): continue
            
            clean_row = [cell.strip().replace('"', '').replace('=', '').replace('_', '\\_') for cell in row]
            while len(clean_row) < 5: clean_row.append("")
            clean_row = clean_row[:5]
            
            var_name = clean_row[0]
            
            if var_name == "future\\_cont\\_val":
                for i in range(4):
                    try: coeffs["cont_val"][i] = float(clean_row[i+1].replace('*', ''))
                    except ValueError: pass
            elif var_name == "future\\_wage\\_diff":
                for i in range(4):
                    try: coeffs["wage_diff"][i] = float(clean_row[i+1].replace('*', ''))
                    except ValueError: pass

            # EXPLICITLY LABEL THE RATIO HERE
            if var_name == "future\\_wage\\_diff": clean_row[0] = r"Wage Difference ($\Delta \ln w_{t+1}$) [Ratio $\beta/\nu$]"
            elif var_name == "future\\_cont\\_val": clean_row[0] = r"Continuation Value ($\Delta \ln \mu_{t+1}$)"
            elif var_name == "v\\_wage": clean_row[0] = r"CF Resid: Wage"
            elif var_name == "v\\_cont": clean_row[0] = r"CF Resid: Cont. Value"
            elif var_name == "\\_cons": clean_row[0] = "Constant"
            elif var_name == "N": clean_row[0] = "Observations"
            
            latex_body.append(" & ".join(clean_row) + r" \\")

        beta_str = ["-", "-", "-", "-"]
        nu_str = ["-", "-", "-", "-"]
        
        for i in range(4):
            if coeffs["cont_val"][i] is not None and coeffs["wage_diff"][i] is not None:
                beta = coeffs["cont_val"][i]
                beta_str[i] = f"{beta:.4f}"
                if coeffs["wage_diff"][i] != 0:
                    nu = beta / coeffs["wage_diff"][i]
                    nu_str[i] = f"{nu:.4f}"
                    
        if ds_name == "macro":
            data_desc = "\\textbf{Macro data} aggregates transitions strictly by origin and destination sector. "
        else:
            data_desc = "\\textbf{Granular data} disaggregates transition flows by worker education and collar type. "

        # HEAVILY EXPANDED FOOTNOTE
        footnote_text = (
            "\\footnotesize \\textit{Notes:} Standard errors in parentheses. * $p<0.10$, ** $p<0.05$, *** $p<0.01$. " +
            "This table estimates the CDP (2019) differenced Euler equation. " + data_desc +
            "\\textbf{Option 1 (Internal Lags):} Models 3 and 4 attempt to address endogeneity using $t-1$ internal lagged wages and continuation values. " +
            "As demonstrated by the negative or weak wage coefficients (which represent the ratio $\\beta/\\nu$), internal lags fail to properly identify the model, " +
            "resulting in mathematically invalid negative shock dispersions ($\\nu$). " +
            "\\textbf{Literature Benchmarks:} CDP (2019) abandoned internal lags in favor of Trade Shocks to cleanly estimate $\\nu = 1.88$. " +
            "ACM (2010) identify average moving costs of 6 to 13 times annual wages."
        )

        table_title = f"Option 1: Structural Estimation of Mobility Costs ({ds_name.title()} Data)"
        
        latex_table = f"""\\begin{{table}}[htbp]
\\centering
\\caption{{{table_title}}}
\\label{{tab:cdp_{ds_name}}}
\\resizebox{{\\textwidth}}{{!}}{{ 
\\begin{{tabular}}{{l c c c c}}
\\toprule
& (1) & (2) & (3) & (4) \\\\
& OLS & PPML & 2SLS & PPML-IV \\\\
\\midrule
"""
        start_idx = 0
        for idx, line in enumerate(latex_body):
            if "Wage Difference" in line or "future" in line:
                start_idx = idx
                break
                
        for line in latex_body[start_idx:-1]:
            latex_table += f"{line}\n"
        
        latex_table += f"\\midrule\n{latex_body[-1]}\n\\midrule\n"
        latex_table += "\\multicolumn{5}{l}{\\textbf{Implied Structural Parameters}} \\\\\n"
        latex_table += f"Discount Factor ($\\beta$) & {beta_str[0]} & {beta_str[1]} & {beta_str[2]} & {beta_str[3]} \\\\\n"
        latex_table += f"Shock Dispersion ($\\nu$) & {nu_str[0]} & {nu_str[1]} & {nu_str[2]} & {nu_str[3]} \\\\\n"
        latex_table += "\\bottomrule\n"
        
        latex_table += f"\\multicolumn{{5}}{{p{{16.5cm}}}}{{{footnote_text}}} \\\\\n"
        latex_table += """\\end{tabular}
}
\\end{table}"""

        with open(tex_path, 'w', encoding='utf-8') as f: f.write(latex_table)
        standalone_doc = f"\\documentclass[11pt]{{article}}\n\\usepackage{{booktabs}}\n\\usepackage{{geometry}}\n\\usepackage{{graphicx}}\n\\geometry{{margin=1in}}\n\\begin{{document}}\n{latex_table}\n\\end{{document}}"
        with open(standalone_tex_path, 'w', encoding='utf-8') as f: f.write(standalone_doc)

        print(f">>> Compiling PDF for {tex_filename}...")
        try:
            subprocess.run(['pdflatex', '-interaction=nonstopmode', f"standalone_{tex_filename}"],
                           cwd=self.tables_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        except Exception as e: print(f">>> Error during compilation: {e}")

if __name__ == "__main__":
    PROJECT_ROOT = "/if/research-eme/omar/Gary/mobility_project"
    builder = LaTeXTableBuilder(PROJECT_ROOT)
    builder.format_4col_esttab_to_latex("macro")
    builder.format_4col_esttab_to_latex("granular")

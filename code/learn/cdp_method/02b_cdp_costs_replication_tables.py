import os
import csv
import subprocess

class CostMatrixBuilder:
    def __init__(self, project_root):
        self.results_dir = os.path.join(project_root, "output", "regression_results")
        self.tables_dir = os.path.join(project_root, "output", "tables")
        os.makedirs(self.tables_dir, exist_ok=True)

    def generate_latex_matrix(self, ds_name, model_name):
        matrix_csv = os.path.join(self.results_dir, f"cost_matrix_{model_name}_{ds_name}.csv")
        reg_csv = os.path.join(self.results_dir, f"restricted_{model_name}_{ds_name}.csv")
        tex_path = os.path.join(self.tables_dir, f"table_cost_{model_name}_{ds_name}.tex")
        standalone_tex_path = os.path.join(self.tables_dir, f"standalone_table_cost_{model_name}_{ds_name}.tex")

        if not os.path.exists(matrix_csv) or not os.path.exists(reg_csv): return

        model_titles = {"ols": "OLS (Logs)", "ppml": "PPML (Levels)", "iv_ols": "2SLS (Lagged IV)", "iv_ppml": "PPML-IV (Lagged CF)"}
        clean_model = model_titles.get(model_name, model_name)

        beta_over_nu_coeff = ""
        beta_over_nu_se = ""
        
        with open(reg_csv, 'r', encoding='utf-8') as f:
            reg_rows = list(csv.reader(f))
            for i, row in enumerate(reg_rows):
                if not any(row): continue
                clean_row = [cell.strip().replace('"', '').replace('=', '') for cell in row]
                if clean_row and "future_wage_diff" in clean_row[0]:
                    beta_over_nu_coeff = clean_row[1]
                    next_row = [cell.strip().replace('"', '').replace('=', '') for cell in reg_rows[i+1]]
                    beta_over_nu_se = next_row[1]
                    break

        try:
            coeff_float = float(beta_over_nu_coeff.replace('*', ''))
            nu_val = 0.96 / coeff_float if coeff_float != 0 else 0
            nu_str = f"{nu_val:.4f}"
        except ValueError:
            nu_str = "Error"

        with open(matrix_csv, 'r', encoding='utf-8') as f:
            matrix_rows = list(csv.reader(f))
        
        sector_names = {"1": "Agric/Min", "2": "Construct", "3": "Manufac", "4": "Trade", "5": "Service", "6": "Trans/Util"}
        latex_body = ""
        for row in matrix_rows[1:]:
            origin_id = row[0]
            origin_name = sector_names.get(origin_id, origin_id)
            formatted_costs = []
            for val in row[1:]:
                try: formatted_costs.append(f"{float(val):.2f}")
                except ValueError: formatted_costs.append("-")
            latex_body += f"{origin_name} & " + " & ".join(formatted_costs) + r" \\" + "\n"

        data_desc = "\\textbf{Macro data} aggregates transitions by broad sector. " if ds_name == "macro" else "\\textbf{Granular data} controls for worker demographic heterogeneity. "
        
        # HEAVILY EXPANDED FOOTNOTE
        footnote_text = (
            f"\\footnotesize \\textit{{Notes:}} Origin sectors are rows; destination sectors are columns. " +
            f"Values represent the utility cost of moving ($C_{{jk}}$), absorbed via Fixed Effects following the CDP (2019) differenced Euler equation. " +
            f"The discount factor is restricted to $\\beta = 0.96$. " +
            data_desc + f"This matrix relies on the \\textbf{{{clean_model}}} specification. " +
            f"\\textbf{{Option 1 (Internal Lags):}} If the instrumented specifications yield negative moving costs or a negative $\\nu$, it mathematically indicates that internal lagged wages fail to identify the structural parameters. " +
            f"\\textbf{{Literature Benchmarks:}} ACM (2010) estimate an average inter-sectoral moving cost of 6 to 13 times the annual wage. CDP (2019) estimate $\\nu = 1.88$ using trade shocks."
        )

        table_title = f"Option 1: Estimated Pecuniary Moving Costs ($C_{{jk}}$) - {clean_model} on {ds_name.title()} Data"
        
        latex_table = f"""\\begin{{table}}[htbp]
\\centering
\\caption{{{table_title}}}
\\label{{tab:costs_{model_name}_{ds_name}}}
\\resizebox{{\\textwidth}}{{!}}{{ 
\\begin{{tabular}}{{l c c c c c c}}
\\toprule
Origin $\\downarrow$ / Dest $\\rightarrow$ & Agric/Min & Construct & Manufac & Trade & Service & Trans/Util \\\\
\\midrule
{latex_body}
\\midrule
\\multicolumn{{7}}{{l}}{{\\textbf{{Structural Parameters (Restricted Model)}}}} \\\\
\\multicolumn{{7}}{{l}}{{Calibrated Discount Factor ($\\beta$) = 0.96}} \\\\
\\multicolumn{{7}}{{l}}{{Ratio of Discount to Dispersion ($\\beta/\\nu$) = {beta_over_nu_coeff} {beta_over_nu_se}}} \\\\
\\multicolumn{{7}}{{l}}{{Implied Shock Dispersion ($\\nu$) = {nu_str}}} \\\\
\\bottomrule
\\multicolumn{{7}}{{p{{16.5cm}}}}{{{footnote_text}}} \\\\
\\end{{tabular}}
}}
\\end{{table}}"""

        with open(tex_path, 'w', encoding='utf-8') as f: f.write(latex_table)
        standalone_doc = f"\\documentclass[11pt]{{article}}\n\\usepackage{{booktabs}}\n\\usepackage{{geometry}}\n\\usepackage{{graphicx}}\n\\geometry{{margin=1in}}\n\\begin{{document}}\n{latex_table}\n\\end{{document}}"
        with open(standalone_tex_path, 'w', encoding='utf-8') as f: f.write(standalone_doc)

        print(f">>> Compiling PDF for {model_name} on {ds_name}...")
        try:
            subprocess.run(['pdflatex', '-interaction=nonstopmode', f"standalone_table_cost_{model_name}_{ds_name}.tex"],
                           cwd=self.tables_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        except Exception as e: print(f">>> Error during compilation: {e}")

if __name__ == "__main__":
    PROJECT_ROOT = "/if/research-eme/omar/Gary/mobility_project"
    builder = CostMatrixBuilder(PROJECT_ROOT)
    for ds in ["macro", "granular"]:
        for model in ["ols", "ppml", "iv_ols", "iv_ppml"]:
            builder.generate_latex_matrix(ds, model)

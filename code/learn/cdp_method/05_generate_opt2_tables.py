import os
import csv
import subprocess

class Option2TableBuilder:
    def __init__(self, project_root):
        self.results_dir = os.path.join(project_root, "output", "regression_results")
        self.tables_dir = os.path.join(project_root, "output", "tables")
        os.makedirs(self.tables_dir, exist_ok=True)

    def build_estimates_table(self, tf_name):
        csv_path = os.path.join(self.results_dir, f"opt2_restricted_estimates_{tf_name}.csv")
        tex_path = os.path.join(self.tables_dir, f"table_opt2_estimates_{tf_name}.tex")
        pdf_name = f"standalone_opt2_estimates_{tf_name}"
        
        if not os.path.exists(csv_path):
            print(f"ERROR: Could not find {csv_path}")
            return

        with open(csv_path, 'r', encoding='utf-8') as f:
            raw_rows = list(csv.reader(f))

        latex_body = ""
        nu_str = "-"
        wage_val = None

        for row in raw_rows:
            if not any(row): continue
            clean_row = [cell.strip().replace('"', '').replace('=', '').replace('_', '\\_') for cell in row]
            if len(clean_row) < 2: continue
            
            var_name = clean_row[0]
            val = clean_row[1]
            
            if var_name == "future\\_wage\\_diff":
                clean_row[0] = r"Wage Difference ($\Delta \ln w_{t+1}$) [Ratio $\beta/\nu$]"
                try: wage_val = float(val.replace('*', ''))
                except ValueError: pass
            elif var_name == "v\\_wage\\_trade": clean_row[0] = r"CF Resid: Wage (Trade IV)"
            elif var_name == "\\_cons": clean_row[0] = "Constant"
            elif var_name == "N": clean_row[0] = "Observations"
            
            if "Standard errors" not in clean_row[0] and "pj0" not in clean_row[0] and "Origin and Destination" not in clean_row[0]:
                latex_body += " & ".join(clean_row[:2]) + r" \\" + "\n"

        if wage_val is not None and wage_val != 0:
            nu_str = f"{(0.96 / wage_val):.4f}"

        title_tf = "1992-2015" if tf_name == "full" else "1993-2007 (CDP Era)"
        
        footnote_text = (
            "\\footnotesize \\textit{Notes:} Standard errors in parentheses. * $p<0.10$, ** $p<0.05$, *** $p<0.01$. " +
            "The model replicates the CDP (2019) differenced Euler equation using PPML-CF. " +
            "Following the spatial literature, the discount factor is calibrated to $\\beta = 0.96$. " +
            "\\textbf{The China Shock IV:} The wage coefficient represents the structural ratio $\\beta/\\nu$. It is instrumented using the exogenous supply shock of China's exports. " +
            "\\textbf{Literature Benchmark:} CDP (2019) estimate an idiosyncratic shock dispersion of $\\nu = 1.88$."
        )
        
        latex_table = f"""\\begin{{table}}[htbp]
\\centering
\\caption{{Option 2: China Shock IV Structural Estimates ({title_tf})}}
\\begin{{tabular}}{{l c}}
\\toprule
& PPML-CF (Levels) \\\\
\\midrule
{latex_body}
\\midrule
\\multicolumn{{2}}{{l}}{{\\textbf{{Implied Structural Parameters}}}} \\\\
Calibrated Discount Factor ($\\beta$) & 0.9600 \\\\
Shock Dispersion ($\\nu$) & {nu_str} \\\\
\\bottomrule
\\multicolumn{{2}}{{p{{13cm}}}}{{{footnote_text}}} \\\\
\\end{{tabular}}
\\end{{table}}"""

        with open(tex_path, 'w') as f: f.write(latex_table)
        self.compile_pdf(latex_table, pdf_name)

    def build_cost_matrix(self, tf_name):
        matrix_csv = os.path.join(self.tables_dir, f"opt2_cost_matrix_{tf_name}.csv")
        reg_csv = os.path.join(self.results_dir, f"opt2_restricted_estimates_{tf_name}.csv")
        tex_path = os.path.join(self.tables_dir, f"table_opt2_costs_{tf_name}.tex")
        pdf_name = f"standalone_opt2_costs_{tf_name}"

        if not os.path.exists(matrix_csv) or not os.path.exists(reg_csv): 
            print(f"ERROR: Missing Matrix files for {tf_name}")
            return

        beta_over_nu_coeff, beta_over_nu_se = "", ""
        with open(reg_csv, 'r') as f:
            reg_rows = list(csv.reader(f))
            for i, row in enumerate(reg_rows):
                clean_row = [c.strip().replace('"', '').replace('=', '') for c in row]
                if clean_row and "future_wage_diff" in clean_row[0]:
                    beta_over_nu_coeff = clean_row[1]
                    beta_over_nu_se = [c.strip().replace('"', '').replace('=', '') for c in reg_rows[i+1]][1]
                    break

        try:
            nu_val = 0.96 / float(beta_over_nu_coeff.replace('*', ''))
            nu_str = f"{nu_val:.4f}"
        except: nu_str = "Error"

        sector_names = {"1": "Agric/Min", "2": "Construct", "3": "Manufac", "4": "Trade", "5": "Service", "6": "Trans/Util"}
        latex_body = ""
        
        with open(matrix_csv, 'r') as f:
            for row in list(csv.reader(f))[1:]:
                origin_name = sector_names.get(row[0], row[0])
                costs = [f"{float(v):.2f}" if v else "-" for v in row[1:]]
                latex_body += f"{origin_name} & " + " & ".join(costs) + r" \\" + "\n"

        title_tf = "1992-2015" if tf_name == "full" else "1993-2007 (CDP Era)"
        
        footnote_text = (
            "\\footnotesize \\textit{Notes:} Origin sectors are rows; destination sectors are columns. " +
            "Values represent the utility cost of moving ($C_{jk}$), expressed in log-wage multiples, absorbed via Fixed Effects following CDP (2019). " +
            "\\textbf{Literature Benchmarks:} ACM (2010) estimate an average moving cost of 6 to 13 times the annual wage. CDP (2019) estimate $\\nu = 1.88$."
        )
        
        latex_table = f"""\\begin{{table}}[htbp]
\\centering
\\caption{{Option 2: Estimated Pecuniary Moving Costs ($C_{{jk}}$) - {title_tf}}}
\\resizebox{{\\textwidth}}{{!}}{{ 
\\begin{{tabular}}{{l c c c c c c}}
\\toprule
Origin $\\downarrow$ / Dest $\\rightarrow$ & Agric/Min & Construct & Manufac & Trade & Service & Trans/Util \\\\
\\midrule
{latex_body}
\\midrule
\\multicolumn{{7}}{{l}}{{\\textbf{{Structural Parameters (Restricted PPML-CF)}}}} \\\\
\\multicolumn{{7}}{{l}}{{Calibrated Discount Factor ($\\beta$) = 0.96}} \\\\
\\multicolumn{{7}}{{l}}{{Ratio of Discount to Dispersion ($\\beta/\\nu$) = {beta_over_nu_coeff} {beta_over_nu_se}}} \\\\
\\multicolumn{{7}}{{l}}{{Implied Shock Dispersion ($\\nu$) = {nu_str}}} \\\\
\\bottomrule
\\multicolumn{{7}}{{p{{16.5cm}}}}{{{footnote_text}}} \\\\
\\end{{tabular}}
}}
\\end{{table}}"""

        with open(tex_path, 'w') as f: f.write(latex_table)
        self.compile_pdf(latex_table, pdf_name)

    def compile_pdf(self, latex_content, pdf_name):
        standalone_doc = f"\\documentclass[11pt]{{article}}\n\\usepackage{{booktabs}}\n\\usepackage{{geometry}}\n\\usepackage{{graphicx}}\n\\geometry{{margin=1in}}\n\\begin{{document}}\n{latex_content}\n\\end{{document}}"
        tex_file = os.path.join(self.tables_dir, f"{pdf_name}.tex")
        with open(tex_file, 'w') as f: f.write(standalone_doc)
        try:
            subprocess.run(['pdflatex', '-interaction=nonstopmode', f"{pdf_name}.tex"], cwd=self.tables_dir, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
            print(f">>> SUCCESS: Compiled {pdf_name}.pdf")
        except Exception as e: 
            print(f">>> FAILED to compile {pdf_name}.pdf: {e}")

if __name__ == "__main__":
    PROJECT_ROOT = "/if/research-eme/omar/Gary/mobility_project"
    builder = Option2TableBuilder(PROJECT_ROOT)
    for tf in ["full", "strict"]:
        builder.build_estimates_table(tf)
        builder.build_cost_matrix(tf)

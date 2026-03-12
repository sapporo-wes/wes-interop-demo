#!/usr/bin/env python3
"""
aggregate.py — Combine per-site SNP summary TSVs and compute Fisher's exact test.

Usage:
    python3 aggregate.py summary_jpt.tsv summary_ceu.tsv \
        --output combined_results.tsv \
        --plot allele_freq_comparison.png
"""

import argparse
import csv
import sys
from pathlib import Path

try:
    import matplotlib.pyplot as plt
    import matplotlib.patches as mpatches
    import numpy as np
    from scipy.stats import fisher_exact
except ImportError:
    print("Install dependencies: pip install scipy matplotlib numpy", file=sys.stderr)
    sys.exit(1)


def read_summary(path: Path) -> dict:
    """Read a site summary TSV into a dict keyed by SNP_ID."""
    rows = {}
    with open(path) as f:
        reader = csv.DictReader(f, delimiter="\t")
        for row in reader:
            rows[row["#SNP_ID"]] = row
    return rows


def compute_fisher(ac_a: int, an_a: int, ac_b: int, an_b: int) -> tuple[float, float]:
    """
    Fisher's exact test on a 2x2 allele count table:
        [[AC_A, AN_A - AC_A],
         [AC_B, AN_B - AC_B]]
    Returns (odds_ratio, p_value).
    """
    table = [
        [ac_a, an_a - ac_a],
        [ac_b, an_b - ac_b],
    ]
    odds_ratio, p_value = fisher_exact(table)
    return odds_ratio, p_value


def fmt_p(p: float) -> str:
    if p < 1e-300:
        return "<1e-300"
    if p < 0.001:
        return f"{p:.2e}"
    return f"{p:.4f}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("site_a", help="Summary TSV from site A (e.g. JPT)")
    parser.add_argument("site_b", help="Summary TSV from site B (e.g. CEU)")
    parser.add_argument("--output", default="combined_results.tsv", help="Output TSV path")
    parser.add_argument("--plot", default="allele_freq_comparison.png", help="Output plot path")
    args = parser.parse_args()

    data_a = read_summary(Path(args.site_a))
    data_b = read_summary(Path(args.site_b))

    snp_ids = sorted(set(data_a) | set(data_b))

    results = []
    for snp_id in snp_ids:
        if snp_id not in data_a or snp_id not in data_b:
            print(f"Warning: {snp_id} missing from one site, skipping", file=sys.stderr)
            continue

        a = data_a[snp_id]
        b = data_b[snp_id]

        ac_a, an_a = int(a["AC"]), int(a["AN"])
        ac_b, an_b = int(b["AC"]), int(b["AN"])
        af_a = ac_a / an_a if an_a > 0 else 0.0
        af_b = ac_b / an_b if an_b > 0 else 0.0

        or_val, p_val = compute_fisher(ac_a, an_a, ac_b, an_b)

        site_a_label = a.get("SITE", "A")
        site_b_label = b.get("SITE", "B")

        results.append({
            "SNP_ID": snp_id,
            "REF": a["REF"],
            "ALT": a["ALT"],
            f"AF_{site_a_label}": f"{af_a:.4f}",
            f"AC_{site_a_label}": ac_a,
            f"AN_{site_a_label}": an_a,
            f"AF_{site_b_label}": f"{af_b:.4f}",
            f"AC_{site_b_label}": ac_b,
            f"AN_{site_b_label}": an_b,
            "OR": f"{or_val:.3f}" if or_val != float("inf") else "Inf",
            "Fisher_p": fmt_p(p_val),
        })

    if not results:
        print("No overlapping SNPs found.", file=sys.stderr)
        sys.exit(1)

    # Write TSV
    with open(args.output, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=results[0].keys(), delimiter="\t")
        writer.writeheader()
        writer.writerows(results)
    print(f"Written: {args.output}")

    # Plot
    fig, ax = plt.subplots(figsize=(9, 5))

    snps = [r["SNP_ID"] for r in results]
    site_a_label = list(data_a.values())[0].get("SITE", "Site A")
    site_b_label = list(data_b.values())[0].get("SITE", "Site B")
    af_a_vals = [float(r[f"AF_{site_a_label}"]) for r in results]
    af_b_vals = [float(r[f"AF_{site_b_label}"]) for r in results]

    x = np.arange(len(snps))
    width = 0.35

    bars_a = ax.bar(x - width / 2, af_a_vals, width, label=site_a_label, color="#E06C75")
    bars_b = ax.bar(x + width / 2, af_b_vals, width, label=site_b_label, color="#61AFEF")

    ax.set_xlabel("SNP")
    ax.set_ylabel("ALT Allele Frequency")
    ax.set_title("Population-differentiated SNP frequencies\n(1000 Genomes Project)")
    ax.set_xticks(x)
    ax.set_xticklabels(snps, rotation=15, ha="right")
    ax.set_ylim(0, 1.1)
    ax.legend()

    # Annotate Fisher p-values
    for i, r in enumerate(results):
        ax.text(i, max(af_a_vals[i], af_b_vals[i]) + 0.05,
                f"p={r['Fisher_p']}", ha="center", fontsize=8, color="#555")

    fig.tight_layout()
    fig.savefig(args.plot, dpi=150)
    print(f"Written: {args.plot}")

    # Print summary to stdout
    print(f"\n{'SNP':<12} {'AF_'+site_a_label:<10} {'AF_'+site_b_label:<10} {'OR':<8} {'Fisher_p'}")
    print("-" * 55)
    for r in results:
        print(f"{r['SNP_ID']:<12} {r[f'AF_{site_a_label}']:<10} {r[f'AF_{site_b_label}']:<10} {r['OR']:<8} {r['Fisher_p']}")


if __name__ == "__main__":
    main()

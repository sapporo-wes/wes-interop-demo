#!/usr/bin/env bash
# submit.sh — Submit the SNP frequency workflow to both WES sites and aggregate results.
# Usage: bash scripts/submit.sh
#
# Workflow: workflow/snp-freq.smk (Snakemake)
# Params:   params/jpt_params_smk.json  (Sapporo — Japanese site)
#           params/ceu_params_smk.json  (WESkit  — German site)
set -euo pipefail

SAPPORO_ENDPOINT="${SAPPORO_ENDPOINT:-http://localhost:1122}"
WESKIT_ENDPOINT="${WESKIT_ENDPOINT:-http://localhost:7777}"
RESULTS_DIR="results"

mkdir -p "$RESULTS_DIR"

poll_until_done() {
    local endpoint="$1"
    local run_id="$2"
    local label="$3"
    while true; do
        STATE=$(curl -s "$endpoint/runs/$run_id/status" | jq -r .state)
        echo "[$label] $STATE"
        case "$STATE" in
            COMPLETE) return 0 ;;
            EXECUTOR_ERROR|SYSTEM_ERROR|CANCELED)
                echo "[$label] Run failed: $STATE" >&2
                curl -s "$endpoint/runs/$run_id" | jq '{exit_code: .run_log.exit_code, stderr: .run_log.stderr}' >&2
                return 1 ;;
        esac
        sleep 15
    done
}

echo "==> Submitting to Japanese site (Sapporo, Snakemake)..."
RUN_JP=$(curl -fsSL -X POST "$SAPPORO_ENDPOINT/runs" \
    -H "Content-Type: application/json" \
    -d @params/jpt_params_smk.json | jq -r .run_id)
echo "    run_id: $RUN_JP"

echo "==> Submitting to German site (WESkit, Snakemake)..."
RUN_DE=$(curl -fsSL -X POST "$WESKIT_ENDPOINT/ga4gh/wes/v1/runs" \
    -H "Content-Type: application/json" \
    -d @params/ceu_params_smk.json | jq -r .run_id)
echo "    run_id: $RUN_DE"

echo "==> Polling..."
poll_until_done "$SAPPORO_ENDPOINT" "$RUN_JP" "JPT"
poll_until_done "$WESKIT_ENDPOINT"  "$RUN_DE" "CEU"

echo "==> Downloading outputs..."
curl -fsSL -o "$RESULTS_DIR/summary_jpt.tsv" \
    "$SAPPORO_ENDPOINT/runs/$RUN_JP/outputs/summary.tsv"
curl -fsSL -o "$RESULTS_DIR/summary_ceu.tsv" \
    "$WESKIT_ENDPOINT/ga4gh/wes/v1/runs/$RUN_DE/outputs/summary.tsv"

echo "==> Aggregating..."
python3 scripts/aggregate.py \
    "$RESULTS_DIR/summary_jpt.tsv" \
    "$RESULTS_DIR/summary_ceu.tsv" \
    --output "$RESULTS_DIR/combined_results.tsv" \
    --plot "$RESULTS_DIR/allele_freq_comparison.png"

echo ""
echo "Done. Results in $RESULTS_DIR/"

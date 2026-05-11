#!/usr/bin/env bash
# submit.sh — Submit the SNP frequency workflow to both WES sites and aggregate results.
# Usage: bash scripts/submit.sh
#
# Workflow: workflow/snp-freq.smk (Snakemake)
# Params:   params/jpt_params_smk.json  (Sapporo — Japanese site)
#           params/ceu_params_smk.json  (WESkit  — German site)
set -euo pipefail

SAPPORO_ENDPOINT="${SAPPORO_ENDPOINT:-http://localhost:1122}"
WESKIT_ENDPOINT="${WESKIT_ENDPOINT:-https://192.168.49.2:30132}"
RESULTS_DIR="results"
JPT_PARAMS="params/jpt_params_smk.json"
CEU_PARAMS="params/ceu_params_smk.json"
SMK_WORKFLOW="workflow/snp-freq.smk"
SMK_CONDA_ENV="workflow/envs/bcftools.yaml"

mkdir -p "$RESULTS_DIR"

poll_until_done() {
    local endpoint="$1"
    local run_id="$2"
    local label="$3"
    shift 3
    while true; do
        STATE=$(curl -s "$@" "$endpoint/runs/$run_id/status" | jq -r .state)
        echo "[$label] $STATE"
        case "$STATE" in
            COMPLETE) return 0 ;;
            EXECUTOR_ERROR|SYSTEM_ERROR|CANCELED)
                echo "[$label] Run failed: $STATE" >&2
                curl -s "$@" "$endpoint/runs/$run_id" | jq '{exit_code: .run_log.exit_code, stderr: .run_log.stderr}' >&2
                return 1 ;;
        esac
        sleep 15
    done
}

echo "==> Submitting to Japanese site (Sapporo, Snakemake)..."
RUN_JP=$(curl -fsSL -X POST "$SAPPORO_ENDPOINT/runs" \
    -H "Accept: application/json" \
    -F workflow_type="$(jq -r .workflow_type "$JPT_PARAMS")" \
    -F workflow_type_version="$(jq -r .workflow_type_version "$JPT_PARAMS")" \
    -F workflow_url="$(jq -r .workflow_url "$JPT_PARAMS")" \
    -F workflow_engine="$(jq -r .workflow_engine "$JPT_PARAMS")" \
    -F workflow_engine_parameters="$(jq -c .workflow_engine_parameters "$JPT_PARAMS")" \
    -F workflow_params="$(jq -c .workflow_params "$JPT_PARAMS")" \
    -F tags="$(jq -c .tags "$JPT_PARAMS")" \
    -F "workflow_attachment=@${SMK_WORKFLOW};filename=snp-freq.smk" \
    -F "workflow_attachment=@${SMK_CONDA_ENV};filename=bcftools.yaml" | jq -r .run_id)
echo "    run_id: $RUN_JP"

echo "==> Submitting to German site (WESkit, Snakemake)..."
RUN_DE=$(curl -fsSL -X POST "$WESKIT_ENDPOINT/ga4gh/wes/v1/runs" \
    --cacert ~/interoperability/helm-deployment/certs/weskit.crt \
    -H "Accept: application/json" \
    -F workflow_type="$(jq -r .workflow_type "$CEU_PARAMS")" \
    -F workflow_type_version="$(jq -r .workflow_type_version "$CEU_PARAMS")" \
    -F workflow_url="$(jq -r .workflow_url "$CEU_PARAMS")" \
    -F workflow_engine="$(jq -r .workflow_engine "$CEU_PARAMS")" \
    -F workflow_engine_parameters="$(jq -c .workflow_engine_parameters "$CEU_PARAMS")" \
    -F workflow_params="$(jq -c .workflow_params "$CEU_PARAMS")" \
    -F tags="$(jq -c .tags "$CEU_PARAMS")" \
    -F "workflow_attachment=@${SMK_WORKFLOW};filename=snp-freq.smk" \
    -F "workflow_attachment=@${SMK_CONDA_ENV};filename=bcftools.yaml" | jq -r .run_id)
echo "    run_id: $RUN_DE"

echo "==> Polling..."
poll_until_done "$SAPPORO_ENDPOINT" "$RUN_JP" "JPT"
poll_until_done "$WESKIT_ENDPOINT/ga4gh/wes/v1" "$RUN_DE" "CEU" \
    --cacert ~/interoperability/helm-deployment/certs/weskit.crt

echo "==> Downloading outputs..."
curl -fsSL -o "$RESULTS_DIR/summary_jpt.tsv" \
    "$SAPPORO_ENDPOINT/runs/$RUN_JP/outputs/summary.tsv"
curl -fsSL --cacert ~/interoperability/helm-deployment/certs/weskit.crt -o "$RESULTS_DIR/summary_ceu.tsv" \
    "$WESKIT_ENDPOINT/weskit/v1/runs/$RUN_DE/outputs/summary.tsv"

echo "==> Aggregating..."
python3 scripts/aggregate.py \
    "$RESULTS_DIR/summary_jpt.tsv" \
    "$RESULTS_DIR/summary_ceu.tsv" \
    --output "$RESULTS_DIR/combined_results.tsv" \
    --plot "$RESULTS_DIR/allele_freq_comparison.png"

echo ""
echo "Done. Results in $RESULTS_DIR/"

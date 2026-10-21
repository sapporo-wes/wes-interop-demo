#!/usr/bin/env bash
# submit_sapporo_only.sh — Cross-check: run BOTH populations on Sapporo and compare
# against the mixed Sapporo (JPT) + WESkit (CEU) reference results.
# Usage: bash scripts/submit_sapporo_only.sh
#
# Workflow: workflow/snp-freq.smk (Snakemake)
# Params:   params/jpt_params_sapporo.json  (Sapporo)
#           params/ceu_params_sapporo.json  (Sapporo)
# Reference: example-results/ (or $REFERENCE_DIR)
# Output:    run-logs/<date>_sapporo-only/ (or $RESULTS_DIR), laid out as
#            service-info.json, {JPT,CEU}/{request/,post_response.json,client.log,
#            run_log.json,outputs_listing.json,summary.tsv} and combined/
#
# The client-side records in run-logs/2026-10-09_sapporo-only/ were made with
# the same per-site steps as submit_site below. The server run directories,
# environment.txt, host-config/ and the aggregation there were done on the
# Sapporo host and are not part of this script.
set -euo pipefail

SAPPORO_ENDPOINT="${SAPPORO_ENDPOINT:-http://localhost:1122}"
RESULTS_DIR="${RESULTS_DIR:-run-logs/$(date -u +%F)_sapporo-only}"
REFERENCE_DIR="${REFERENCE_DIR:-example-results}"
JPT_PARAMS="params/jpt_params_sapporo.json"
CEU_PARAMS="params/ceu_params_sapporo.json"
SMK_WORKFLOW="workflow/snp-freq.smk"
SMK_CONDA_ENV="workflow/envs/bcftools.yaml"

WES="$SAPPORO_ENDPOINT"
ts() { date -u +%Y-%m-%dT%H:%M:%SZ; }

mkdir -p "$RESULTS_DIR/combined"

# submit_site <params.json> <POP>: submit one run, wait for it, and keep the
# request, POST response, status trace, run log and summary in $RESULTS_DIR/<POP>/.
submit_site() {
    local params="$1" label="$2"
    local out="$RESULTS_DIR/$label"
    mkdir -p "$out/request"
    cp "$params" "$out/request/params.json"
    cp "$SMK_WORKFLOW" "$SMK_CONDA_ENV" "$out/request/"
    (cd "$out/request" && sha256sum params.json snp-freq.smk bcftools.yaml > SHA256SUMS)
    local p="$out/request/params.json"

    echo "submitted_at: $(ts)" > "$out/client.log"
    curl -fsS -X POST "$WES/runs" \
        -H "Accept: application/json" \
        -F workflow_type="$(jq -r .workflow_type "$p")" \
        -F workflow_type_version="$(jq -r .workflow_type_version "$p")" \
        -F workflow_url="$(jq -r .workflow_url "$p")" \
        -F workflow_engine="$(jq -r .workflow_engine "$p")" \
        -F workflow_engine_parameters="$(jq -c .workflow_engine_parameters "$p")" \
        -F workflow_params="$(jq -c .workflow_params "$p")" \
        -F tags="$(jq -c .tags "$p")" \
        -F "workflow_attachment=@$out/request/snp-freq.smk;filename=snp-freq.smk" \
        -F "workflow_attachment=@$out/request/bcftools.yaml;filename=bcftools.yaml" \
        > "$out/post_response.json"
    local run_id state
    run_id="$(jq -r .run_id "$out/post_response.json")"
    echo "run_id: $run_id" | tee -a "$out/client.log"

    while true; do
        state="$(curl -fsS "$WES/runs/$run_id/status" | jq -r .state)"
        echo "$(ts) $state" >> "$out/client.log"
        echo "[$label] $state"
        case "$state" in COMPLETE|EXECUTOR_ERROR|SYSTEM_ERROR|CANCELED) break ;; esac
        sleep 10
    done
    echo "finished_at: $(ts) state: $state" >> "$out/client.log"

    curl -fsS "$WES/runs/$run_id" | jq . > "$out/run_log.json"
    if [[ "$state" != COMPLETE ]]; then
        echo "[$label] Run failed: $state" >&2
        jq '{exit_code: .run_log.exit_code, stderr: .run_log.stderr}' "$out/run_log.json" >&2
        return 1
    fi
    curl -fsS "$WES/runs/$run_id/outputs" | jq . > "$out/outputs_listing.json"
    curl -fsS -o "$out/summary.tsv" "$WES/runs/$run_id/outputs/summary.tsv"
}

curl -fsS "$WES/service-info" | jq . > "$RESULTS_DIR/service-info.json"

# Runs are sequential, as in the 2026-10-09 run and the WESkit-only cross-check.
echo "==> Submitting JPT to Sapporo..."
submit_site "$JPT_PARAMS" JPT

echo "==> Submitting CEU to Sapporo..."
submit_site "$CEU_PARAMS" CEU

echo "==> Aggregating..."
# Use uv for aggregate.py's dependencies when available; else plain python3.
if command -v uv >/dev/null; then
    PY=(uv run --no-project --with scipy --with matplotlib --with numpy python3)
else
    PY=(python3)
fi
"${PY[@]}" scripts/aggregate.py \
    "$RESULTS_DIR/JPT/summary.tsv" \
    "$RESULTS_DIR/CEU/summary.tsv" \
    --output "$RESULTS_DIR/combined/combined_results.tsv" \
    --plot "$RESULTS_DIR/combined/allele_freq_comparison.png"

echo ""
echo "==> Comparing against $REFERENCE_DIR/ ..."
FAIL=0
# reference file : result file
for pair in "summary_jpt.tsv:JPT/summary.tsv" \
            "summary_ceu.tsv:CEU/summary.tsv" \
            "combined_results.tsv:combined/combined_results.tsv"; do
    ref="$REFERENCE_DIR/${pair%%:*}"; res="$RESULTS_DIR/${pair#*:}"
    if diff -u "$ref" "$res" > "$res.diff"; then
        echo "  IDENTICAL  $res"
        rm -f "$res.diff"
    else
        echo "  DIFFERS    $res  (see $res.diff)"
        FAIL=1
    fi
done

echo ""
if [[ $FAIL -eq 0 ]]; then
    echo "PASS: Sapporo-only results match the Sapporo+WESkit reference."
else
    echo "FAIL: results differ from reference." >&2
    exit 1
fi

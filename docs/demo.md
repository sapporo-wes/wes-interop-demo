# Demo: Federated SNP Frequency Analysis

## Scientific context

Population genetics studies require comparing allele frequencies across cohorts. When cohort data is held under data governance agreements (e.g. national biobanks), raw sequencing data cannot be centralised. WES provides a standard interface to submit analysis workflows to each site, compute locally, and return only summary statistics.

This demo compares four textbook population-differentiated SNPs between:

- **JPT** — Japanese in Tokyo (1000 Genomes Project, n=104)
- **CEU** — Utah residents with Northern/Western European ancestry (n=99)

| SNP | Gene | Phenotype association | Expected JPT freq | Expected CEU freq |
|---|---|---|---|---|
| rs3827760 | EDARV370A | Hair/sweat gland morphology | ~70% | ~0% |
| rs671 | ALDH2 | Alcohol metabolism | ~25% | ~0% |
| rs4988235 | LCT | Lactase persistence | ~2% | ~74% |
| rs1426654 | SLC24A5 | Skin pigmentation | ~0% | ~100% |

## Infrastructure

```
┌─────────────────────────┐          ┌─────────────────────────┐
│     Japanese site       │          │      German site         │
│  Sapporo WES (AWS EC2)  │          │  WESkit (collaborator)   │
│                         │          │                          │
│  data: 1000G JPT VCF    │          │  data: 1000G CEU VCF     │
│  workflow: snp-freq.cwl │          │  workflow: snp-freq.cwl  │
│  output: summary_jpt.tsv│          │  output: summary_ceu.tsv │
└──────────┬──────────────┘          └──────────┬───────────────┘
           │                                    │
           └──────────────┬─────────────────────┘
                          ▼
                   Researcher / AI agent
                   aggregate.py
                   → combined_results.tsv
                   → allele_freq_comparison.png
```

## Workflow

Each site runs [`workflow/snp-freq.cwl`](../workflow/snp-freq.cwl), which:

1. Subsets the local VCF to site-specific samples and target SNP regions (`bcftools view`)
2. Computes allele counts and frequencies (`bcftools +fill-tags`)
3. Extracts a summary TSV (`bcftools query`)

**Output schema** (`summary.tsv`):

```
#SNP_ID  REF  ALT  AC  AN  AF
rs3827760  T  C  145  208  0.697
...
```

No per-sample genotypes. The data custodian at each site can inspect the workflow and output before release.

## Data governance step

Sapporo supports pre-approving executable workflows via `executable_workflows.json`. The data custodian registers `snp-freq.cwl` by its URL; any other workflow URL is rejected with HTTP 400. This ensures only the reviewed, approved workflow can run against the protected data.

## Step-by-step: shell script mode

### 1. Set endpoints

```bash
export SAPPORO_ENDPOINT=https://wes-jp.example.org
export WESKIT_ENDPOINT=https://wes-de.example.org
```

### 2. Submit to Sapporo (Japanese site)

```bash
RUN_JP=$(curl -s -X POST $SAPPORO_ENDPOINT/runs \
  -H "Content-Type: application/json" \
  -d @params/jpt_params.json | jq -r .run_id)
echo "JP run: $RUN_JP"
```

### 3. Submit to WESkit (German site)

```bash
# WESkit uses the same GA4GH WES API
RUN_DE=$(curl -s -X POST $WESKIT_ENDPOINT/ga4gh/wes/v1/runs \
  -H "Content-Type: application/json" \
  -d @params/ceu_params.json | jq -r .run_id)
echo "DE run: $RUN_DE"
```

### 4. Poll both until complete

```bash
for ENDPOINT RUN in "$SAPPORO_ENDPOINT $RUN_JP" "$WESKIT_ENDPOINT $DE_RUN"; do
  while true; do
    STATE=$(curl -s $ENDPOINT/runs/$RUN/status | jq -r .state)
    echo "$ENDPOINT: $STATE"
    case $STATE in COMPLETE|EXECUTOR_ERROR|SYSTEM_ERROR|CANCELED) break ;; esac
    sleep 15
  done
done
```

### 5. Download outputs

```bash
curl -s -o results/summary_jpt.tsv "$SAPPORO_ENDPOINT/runs/$RUN_JP/outputs/summary.tsv"
curl -s -o results/summary_ceu.tsv "$WESKIT_ENDPOINT/ga4gh/wes/v1/runs/$RUN_DE/outputs/summary.tsv"
```

### 6. Aggregate

```bash
python3 scripts/aggregate.py results/summary_jpt.tsv results/summary_ceu.tsv \
  --output results/combined_results.tsv \
  --plot results/allele_freq_comparison.png
```

## Step-by-step: AI agent mode

Set the two endpoints in your environment, then ask the agent:

> "Submit `workflow/snp-freq.cwl` with `params/jpt_params.json` to `$SAPPORO_ENDPOINT` and `params/ceu_params.json` to `$WESKIT_ENDPOINT`. Wait for both to complete, download `summary.tsv` from each, then run `scripts/aggregate.py` and report the results."

The agent uses [`docs/agent-skill.md`](https://github.com/sapporo-wes/sapporo-service/blob/main/docs/agent-skill.md) for the Sapporo side and the WESkit equivalent for the German side.

## Expected results

After aggregation, `combined_results.tsv` should show:

| SNP | AF_JPT | AF_CEU | OR | Fisher_p |
|---|---|---|---|---|
| rs3827760 | 0.697 | 0.003 | >100 | <1e-30 |
| rs671 | 0.254 | 0.000 | ∞ | <1e-15 |
| rs4988235 | 0.019 | 0.741 | 0.007 | <1e-30 |
| rs1426654 | 0.004 | 0.998 | 0.004 | <1e-50 |

All four SNPs show highly significant population differentiation — as expected from the literature.

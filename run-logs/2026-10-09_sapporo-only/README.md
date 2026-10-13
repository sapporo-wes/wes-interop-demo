# Sapporo-only run, 2026-10-09

Both populations (JPT and CEU) were run on a single Sapporo WES instance and
submitted through the GA4GH WES API. The aim is to compare against the
federated results in `example-results/` (v1.0.0: JPT on Sapporo, CEU on
WESkit, June 2026). The WESkit-only counterpart is in
`../2026-10-01_weskit-only/`.

## Result

All outputs are byte-identical to `example-results/` in v1.0.0:

| File | Compared with | Result |
|---|---|---|
| `JPT/summary.tsv` | `example-results/summary_jpt.tsv` | identical |
| `CEU/summary.tsv` | `example-results/summary_ceu.tsv` | identical |
| `combined/combined_results.tsv` | `example-results/combined_results.tsv` | identical |

The same three files are also identical to those of the WESkit-only run.
The plot (`combined/allele_freq_comparison.png`) is not compared, because its
bytes depend on the matplotlib build.

## Why this run exists

The Sapporo-side run directory from the June federated run was not kept. The
AWS instance was terminated on 2026-06-17, its root volume was deleted with
it, and no snapshot or backup existed. This run rebuilds that site as closely
as possible and keeps the complete records.

## Setup

- **Host:** AWS EC2 `m5.large` (2 vCPU, 7.6 GiB), `ap-northeast-1`, Ubuntu 24.04.5 LTS
  (`ami-0739e5f3b35c608e5`). Provisioned by `host-config/provision.sh`.
- **WES server:** Sapporo 2.2.5. Workflows run natively without Docker through
  `host-config/run.native.sh`, as on the June site.
- **Engine:** Snakemake 9.22.0. Sapporo and Snakemake are pinned to the newest
  releases available when the June site was built (2026-06-05).
- **Workflow:** repository tag `v1.0.0` (`b7c8c95`). `snp-freq.smk` and
  `bcftools.yaml` are sent as `workflow_attachment`.
- **Parameters:** `params/jpt_params_sapporo.json` and
  `params/ceu_params_sapporo.json`, byte-identical to `*/request/params.json`.
- **Tool environment:** Snakemake builds a conda env from `bcftools.yaml`
  (bcftools 1.21, htslib 1.24). The full package list with checksums is in
  `*/conda_env_explicit.txt`.
- **Input data:** 1000 Genomes 20190312 GRCh38 biallelic SNV/indel release,
  chr2/12/15, merged. JPT has 104 samples and CEU has 99. File checksums
  are in `environment.txt`.
- **Client:** requests were sent from a workstation through an SSH tunnel to
  Sapporo's local port, so URLs in the logs show `127.0.0.1:1122`. The
  per-site steps (submit, poll, fetch the run log and outputs) are the ones in
  `scripts/submit_sapporo_only.sh`.

## Runs

| Site | run_id | Submitted (UTC) | Ended (UTC) | State | Exit |
|---|---|---|---|---|---|
| JPT | `f41bc83b-3ddb-4df0-afd1-7381a098c723` | 2026-10-09T06:24:29Z | 2026-10-09T06:24:48 | COMPLETE | 0 |
| CEU | `2af829aa-0220-45ed-a5bb-dd7ec201d6dd` | 2026-10-09T06:24:50Z | 2026-10-09T06:25:09 | COMPLETE | 0 |

## Layout

```
service-info.json            GET /service-info at run time
environment.txt              host, software versions, input checksums
host-config/                 provision.sh, run.native.sh, sapporo.service, pip freeze
JPT/ and CEU/
  request/                   exact params + attachments sent (with SHA256SUMS)
  post_response.json         POST /runs response
  client.log                 submission time and status trace
  run_log.json               GET /runs/{id} (full WES run log incl. stderr)
  outputs_listing.json       GET /runs/{id}/outputs
  summary.tsv                GET /runs/{id}/outputs/summary.tsv
  server_run_dir/            Sapporo run directory (minus the conda env),
                             incl. stderr.log, cmd.txt, run_request.json,
                             ro-crate-metadata.json (Workflow Run RO-Crate)
  conda_env_explicit.txt     conda list --explicit --md5 of the tool env
  genotype_intermediates.sha256  checksums of the intermediate VCFs
combined/                    aggregate.py output (TSV + plot)
```

## Notes and deviations

1. **The `rocrate` library was pinned to 0.15.0.** The first pair of runs
   (`4d5695ca-…`, `21d86057-…`) produced identical summaries. RO-Crate
   generation failed in both, because `rocrate` 0.16.0 (released 2026-10-06)
   removed `WORKFLOW_PROFILE`, which Sapporo imports. We pinned 0.15.0, the
   release that was current in June, and re-ran. The runs listed above are the
   re-runs.
2. **The Snakemake version in `service-info.json` is wrong for this host.** It
   lists v9.16.3, which is Sapporo's built-in value for its Docker image. The
   native executor runs the host's Snakemake 9.22.0, as shown in the
   `stderr.log` header.
3. **Genotype-level intermediates are included.** These are
   `subset.raw.vcf.gz`, `subset.vcf.gz` and `tagged.vcf.gz` under `exe/` and
   `outputs/`. They hold per-sample genotypes at the 3 target SNPs for public
   1000 Genomes samples. They are kept so the run directory and its RO-Crate
   are complete. Note that the WES `/outputs` endpoint served them alongside
   `summary.tsv`, because the native executor publishes every Snakemake output.
   Their SHA-256 checksums are in `genotype_intermediates.sha256`.
4. **The conda env directory is not included** because it is about 1.5 GB. The
   env spec (`.snakemake/conda/*.yaml`) and the explicit package list are
   included.
5. **Repeated runs give the same intermediate VCF records.** The files differ
   byte-for-byte only in the `##bcftools_*Command` header lines, which hold the
   run path and a date.
6. **Aggregation ran on the Sapporo host.** `aggregate.py` from v1.0.0 was run
   with the run's conda env (`bcftools.yaml` includes scipy, numpy and
   matplotlib). Versions are in `combined/AGGREGATION_ENV.txt`.

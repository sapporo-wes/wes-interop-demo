# Next Steps

## Status

Sapporo end-to-end test complete as of 2026-03-16 (commit `9edea12`):

- **Snakemake workflow** (`workflow/snp-freq.smk`) validated locally and via Sapporo WES API
- Sapporo submission confirmed working: `workflow_engine_parameters` as dict, `--cores all` required, `workflow_attachment_obj` for conda env
- `SAPPORO_EXTRA_DOCKER_ARGS` feature added to sapporo-service (PR #55 open) — required to mount data directories into inner Snakemake containers
- CWL workflow preserved as reference; aggregation script validated
- WESkit submission params drafted: `params/ceu_params_smk.json` (attachment mechanism TBD with collaborators)

---

## 1. Deploy Sapporo on AWS EC2 (Japanese site)

Follow `infra/ec2-setup.md`.

Key tasks:
- Launch EC2 instance (recommend t3.large+, Ubuntu 24.04)
- Install Docker
- Download `compose.yml` from sapporo-service; set `SAPPORO_EXTRA_DOCKER_ARGS=-v /data:/data`
- Merge chr2, chr12, chr15 1000G VCFs into `/data/1000g/ALL.chr2_12_15.phase3.vcf.gz` (see `infra/ec2-setup.md` §3)
- Start Sapporo with `docker compose up -d`
- Confirm `GET /service-info` returns healthy response
- Set `SAPPORO_ENDPOINT` in `scripts/submit.sh`

**Blocked on**: sapporo-service PR #55 being merged (or manually patching `run.sh`)

---

## 2. Obtain WESkit API Access (German site)

Contact collaborators for:
- WESkit base URL
- Auth token / credentials
- Confirm WES API path (expected: `/ga4gh/wes/v1`)
- Confirm Snakemake engine name and version accepted by WESkit
- **Confirm how to attach extra files** (e.g. `workflow/envs/bcftools.yaml`) alongside the Snakefile — `workflow_attachment_obj` is Sapporo-specific and may not be supported by WESkit

Once available:
- Update `params/ceu_params_smk.json` with real endpoint, credentials, and correct attachment mechanism
- Update `scripts/submit.sh` `WESKIT_ENDPOINT` variable
- Run a test submission with the synthetic VCF to confirm connectivity

---

## 3. Prepare Real 1000 Genomes Data

For each site, prepare the input VCF:

**Both sites:**
- Download 1000G phase 3 per-chromosome VCFs for chr2, chr12, chr15 from [IGSR](https://www.internationalgenome.org/)
- Merge with `bcftools concat` into `ALL.chr2_12_15.phase3.vcf.gz` (see `infra/ec2-setup.md` §3 for exact commands)
- Place merged VCF at `/data/1000g/ALL.chr2_12_15.phase3.vcf.gz` with `.tbi` index

**JPT (Japanese site — EC2):**
- Create `data/jpt_samples.txt` with JPT sample IDs from 1000G phase 3 panel

**CEU (German site — WESkit):**
- Create `data/ceu_samples.txt` with CEU sample IDs from 1000G phase 3 panel

---

## 4. End-to-End Demo Run

Once both sites are live with real data:

```bash
export SAPPORO_ENDPOINT=http://<ec2-ip>:1122
export WESKIT_ENDPOINT=https://<weskit-host>/ga4gh/wes/v1
bash scripts/submit.sh
```

Expected output:
- `results/combined_results.tsv` — allele frequencies for 4 SNPs across JPT and CEU
- `results/allele_freq_comparison.png` — bar chart
- Fisher's exact test p-values matching `tests/expected/combined_results.tsv` (sign)

---

## 5. Zenodo Archival

After the demo is validated end-to-end:

- Create a Zenodo deposit for the `sapporo-wes/wes-interop-demo` repository
- Add DOI badge to `README.md`
- Tag the release (e.g. `v1.0.0`) and link from Zenodo

---

## 6. Follow-on: MCP Server (Optional)

As discussed in sapporo-service issue #52, an MCP server (`sapporo-wes/sapporo-mcp`) could wrap the WES REST API for richer agent integration. This is a separate project, blocked on nothing in this repo.

Relevant prior discussion: `sapporo-service` issue #52, `docs/agent-skill.md`.

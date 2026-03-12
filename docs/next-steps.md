# Next Steps

## Status

Local testing complete as of 2026-03-12 (commit `6b665ca`):

- CWL workflow validated with `cwltool --no-container` and Docker (`bcftools:1.21--h3a4d415_1`)
- Aggregation script validated with synthetic JPT/CEU data
- Expected outputs committed to `tests/expected/`

---

## 1. Deploy Sapporo on AWS EC2 (Japanese site)

Follow `infra/ec2-setup.md`.

Key tasks:
- Launch EC2 instance (recommend t3.medium+, Amazon Linux 2 or Ubuntu 22.04)
- Install Docker and Docker Compose
- Clone this repo; mount 1000G JPT VCF under `/data`
- Start Sapporo with `docker compose up -d`
- Confirm `GET /service-info` returns healthy response
- Set `SAPPORO_ENDPOINT` in `scripts/submit.sh`

---

## 2. Obtain WESkit API Access (German site)

Contact collaborators for:
- WESkit base URL
- Auth token / credentials
- Confirm WES API path (expected: `/ga4gh/wes/v1`)
- Confirm supported workflow engines (cwltool assumed)

Once available:
- Update `params/ceu_params.json` with real endpoint and credentials
- Update `scripts/submit.sh` `CEU_ENDPOINT` variable
- Run a test submission with the synthetic VCF to confirm connectivity

---

## 3. Prepare Real 1000 Genomes Data

For each site, prepare the input VCF:

**JPT (Japanese site):**
- Download 1000G phase 3 JPT samples from [IGSR](https://www.internationalgenome.org/)
- Chromosomes 2, 12, 15 (cover all four target SNPs)
- Bgzip + tabix index the VCF
- Upload to EC2 under `/data/jpt/`
- Create `params/jpt_samples.txt` listing JPT sample IDs

**CEU (German site):**
- Download 1000G phase 3 CEU samples
- Same chromosomes
- Prepare `params/ceu_samples.txt` listing CEU sample IDs

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

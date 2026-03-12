# wes-interop-demo

A federated bioinformatics demonstration using two WES implementations:

- **Japanese site** — [Sapporo](https://github.com/sapporo-wes/sapporo-service) on AWS EC2
- **German site** — [WESkit](https://weskit.bihealth.org/) on collaborator infrastructure

## Scenario

A researcher compares allele frequencies of population-differentiated SNPs between Japanese (JPT) and European (CEU) cohorts from the [1000 Genomes Project](https://www.internationalgenome.org/). Raw WGS data cannot leave each site. Each site runs an identical CWL workflow locally, computes summary statistics, and returns only aggregate allele counts — no per-sample data leaves the site.

The researcher (or an AI agent) submits workflows to both WES endpoints, waits for results, and aggregates them into a population comparison.

## Repository structure

```
workflow/         CWL workflow and tool definitions
data/             Target SNP positions, sample lists
params/           WES run parameters for each site
scripts/          Aggregation script, submission shell script
docs/             Narrative, setup guides
infra/            EC2 deployment for the Sapporo/Japanese site
```

## Quick start

See [docs/demo.md](docs/demo.md) for the full walkthrough.

## Requirements

- `curl`, `jq`, `python3` with `scipy` and `matplotlib`
- Access to a Sapporo WES endpoint (Japanese site)
- Access to a WESkit endpoint (German site)

## Zenodo

This repository will be archived on Zenodo upon publication.

## License

Apache 2.0

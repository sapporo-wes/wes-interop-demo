# Data

## target_snps.bed

Four population-differentiated SNPs (GRCh38). Used to subset VCFs to target regions.

## Sample lists

`jpt_samples.txt` and `ceu_samples.txt` contain 1000 Genomes Project phase 3 sample IDs.
Download them from the 1000 Genomes FTP:

```bash
# All phase 3 samples with population labels
curl -O http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/integrated_call_samples_v3.20130502.ALL.panel

# Extract JPT sample IDs
awk '$2 == "JPT" {print $1}' integrated_call_samples_v3.20130502.ALL.panel > jpt_samples.txt

# Extract CEU sample IDs
awk '$2 == "CEU" {print $1}' integrated_call_samples_v3.20130502.ALL.panel > ceu_samples.txt
```

## VCF files (site-local, not in this repo)

The four target SNPs span chromosomes 2, 12, and 15. Each site downloads the three
per-chromosome VCFs and merges them into a single file. Both JPT and CEU samples are
present in the 1000 Genomes multi-sample VCFs; the workflow subsets to site-specific
samples using the sample list.

```bash
BASE=http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502

# Download chr2, chr12, chr15
for CHR in 2 12 15; do
  curl -O ${BASE}/ALL.chr${CHR}.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz
  curl -O ${BASE}/ALL.chr${CHR}.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz.tbi
done

# Merge into a single indexed VCF
bcftools concat --allow-overlaps \
  ALL.chr2.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz \
  ALL.chr12.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz \
  ALL.chr15.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz \
  --output-type z --output ALL.chr2_12_15.phase3.vcf.gz
tabix -p vcf ALL.chr2_12_15.phase3.vcf.gz
```

Place the merged file at `/data/1000g/ALL.chr2_12_15.phase3.vcf.gz` on each site's server.
This is the path referenced in `params/jpt_params_smk.json` and `params/ceu_params_smk.json`.

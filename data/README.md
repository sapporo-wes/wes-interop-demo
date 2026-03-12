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

Each site downloads the relevant 1000 Genomes VCF slices to local storage.
These are **not committed** to this repo — they live at each data site.

### Japanese site (JPT)

```bash
# chr2 (covers rs3827760 and rs4988235)
curl -O http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/ALL.chr2.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz
curl -O http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/ALL.chr2.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz.tbi

# chr12 (covers rs671)
curl -O http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/ALL.chr12.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz
curl -O http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/ALL.chr12.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz.tbi

# chr15 (covers rs1426654)
curl -O http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/ALL.chr15.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz
curl -O http://ftp.1000genomes.ebi.ac.uk/vol1/ftp/release/20130502/ALL.chr15.phase3_shapeit2_mvncall_integrated_v5b.20130502.genotypes.vcf.gz.tbi
```

### German site (CEU)

Same VCF files — both populations are included in the 1000 Genomes multi-sample VCFs.
The workflow subsets to site-specific samples using the sample list.

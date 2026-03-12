#!/usr/bin/env bash
set -euo pipefail
OUTDIR="$(dirname "$0")/data"
mkdir -p "$OUTDIR"

# --- synthetic VCF (10 samples, 4 target SNPs, GRCh38 coords matching data/target_snps.bed) ---
cat > "$OUTDIR/test.vcf" << 'VCF'
##fileformat=VCFv4.2
##FILTER=<ID=PASS,Description="All filters passed">
##contig=<ID=chr2,length=242193529>
##contig=<ID=chr12,length=133275309>
##contig=<ID=chr15,length=101991189>
##FORMAT=<ID=GT,Number=1,Type=String,Description="Genotype">
#CHROM	POS	ID	REF	ALT	QUAL	FILTER	INFO	FORMAT	S01	S02	S03	S04	S05	S06	S07	S08	S09	S10
chr2	108999271	rs3827760	T	C	.	PASS	.	GT	1/1	1/1	1/1	1/1	1/1	0/1	0/1	0/1	0/0	0/0
chr2	135851284	rs4988235	C	T	.	PASS	.	GT	0/1	0/0	0/0	0/0	0/0	0/0	0/0	0/0	0/0	0/0
chr12	111803912	rs671	G	A	.	PASS	.	GT	1/1	0/1	0/1	0/1	0/0	0/0	0/0	0/0	0/0	0/0
chr15	48128819	rs1426654	G	A	.	PASS	.	GT	0/0	0/0	0/0	0/0	0/0	0/0	0/0	0/0	0/0	0/0
VCF

# bgzip + tabix using Docker
docker run --rm \
  -v "$OUTDIR:/data" \
  quay.io/biocontainers/bcftools:1.21--h3a4b0d4_0 \
  bash -c "bcftools sort /data/test.vcf | bgzip -c > /data/test.vcf.gz && tabix -p vcf /data/test.vcf.gz"

echo "Created: $OUTDIR/test.vcf.gz + .tbi"

# --- sample list (all 10 samples = "JPT" site for test) ---
printf 'S01\nS02\nS03\nS04\nS05\nS06\nS07\nS08\nS09\nS10\n' > "$OUTDIR/test_samples.txt"
echo "Created: $OUTDIR/test_samples.txt"

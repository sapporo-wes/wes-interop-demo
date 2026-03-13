# snp-freq.smk — SNP allele frequency summary
#
# Computes AC/AN/AF for target SNPs from a population VCF.
# Only aggregate statistics are output — no per-sample genotypes.
#
# Config keys (passed via --configfile in the WES request):
#   vcf      path to bgzipped, tabix-indexed multi-sample VCF
#   samples  path to text file with one sample ID per line
#   regions  path to BED file of target SNP positions (BED format, 0-based)
#   site_id  string label for output (e.g. "JPT" or "CEU")

VCF     = config["vcf"]
SAMPLES = config["samples"]
REGIONS = config["regions"]
SITE_ID = config["site_id"]


rule all:
    input:
        "summary.tsv",


rule subset:
    """Subset multi-sample VCF to site-specific samples and target SNP regions."""
    input:
        vcf=VCF,
        tbi=VCF + ".tbi",
        samples=SAMPLES,
        regions=REGIONS,
    output:
        "subset.vcf.gz",
    conda:
        "envs/bcftools.yaml"
    shell:
        "bcftools view "
        "--samples-file {input.samples} "
        "--regions-file {input.regions} "
        "--output-type z "
        "--output {output} "
        "{input.vcf}"


rule fill_tags:
    """Compute AC, AN, AF INFO tags from the subsetted VCF."""
    input:
        "subset.vcf.gz",
    output:
        "tagged.vcf.gz",
    conda:
        "envs/bcftools.yaml"
    shell:
        "bcftools +fill-tags {input} "
        "--output-type z "
        "--output {output} "
        "-- --tags=AC,AN,AF"


rule query:
    """Extract summary TSV (SNP_ID, REF, ALT, AC, AN, AF, SITE). No per-sample data."""
    input:
        "tagged.vcf.gz",
    output:
        "summary.tsv",
    params:
        site_id=SITE_ID,
    conda:
        "envs/bcftools.yaml"
    shell:
        "printf '#SNP_ID\\tREF\\tALT\\tAC\\tAN\\tAF\\tSITE\\n' > {output} && "
        "bcftools query "
        "--format '%ID\\t%REF\\t%ALT\\t%AC\\t%AN\\t%AF\\t{params.site_id}\\n' "
        "{input} >> {output}"

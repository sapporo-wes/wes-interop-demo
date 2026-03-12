#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: Workflow

label: SNP allele frequency summary
doc: |
  Computes allele frequency summary statistics for a set of target SNPs
  from a population VCF. Designed for federated use: only aggregate
  counts (AC, AN, AF) are output — no per-sample genotypes.

requirements:
  StepInputExpressionRequirement: {}
  InlineJavascriptRequirement: {}

inputs:
  vcf:
    type: File
    secondaryFiles:
      - .tbi
    doc: "Bgzipped, tabix-indexed multi-sample VCF (local site data)"

  samples:
    type: File
    doc: "Text file with one sample ID per line (site-specific population)"

  regions:
    type: File
    doc: "BED file of target SNP positions"

  site_id:
    type: string
    doc: "Site identifier for output labelling (e.g. JPT or CEU)"

outputs:
  summary:
    type: File
    outputSource: query/summary
    doc: "TSV: SNP_ID, REF, ALT, AC, AN, AF — no per-sample data"

steps:
  subset:
    run: tools/bcftools-subset.cwl
    in:
      vcf: vcf
      samples: samples
      regions: regions
    out: [subset_vcf]

  fill_tags:
    run: tools/bcftools-fill-tags.cwl
    in:
      vcf: subset/subset_vcf
    out: [tagged_vcf]

  query:
    run: tools/bcftools-query.cwl
    in:
      vcf: fill_tags/tagged_vcf
      site_id: site_id
    out: [summary]

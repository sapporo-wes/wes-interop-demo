#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: bcftools query — extract summary TSV
doc: |
  Extracts SNP_ID, REF, ALT, AC, AN, AF into a tab-delimited summary file.
  This is the only output that leaves the site — no per-sample data.

requirements:
  DockerRequirement:
    dockerPull: quay.io/biocontainers/bcftools:1.21--h3a4b0d4_0
  InlineJavascriptRequirement: {}
  ShellCommandRequirement: {}

arguments:
  - shellQuote: false
    valueFrom: |
      echo -e "#SNP_ID\tREF\tALT\tAC\tAN\tAF\tSITE" > summary.tsv &&
      bcftools query
      --regions-file $(inputs.regions.path)
      --format '%ID\t%REF\t%ALT\t%AC\t%AN\t%AF\t$(inputs.site_id)\n'
      $(inputs.vcf.path) >> summary.tsv

baseCommand: bash
arguments:
  - -c

inputs:
  vcf:
    type: File

  regions:
    type: File

  site_id:
    type: string

outputs:
  summary:
    type: File
    outputBinding:
      glob: summary.tsv

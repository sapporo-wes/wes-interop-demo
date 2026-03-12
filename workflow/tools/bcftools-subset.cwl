#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: bcftools view — subset samples and target regions
doc: |
  Subsets a multi-sample VCF to the specified samples and genomic regions.

hints:
  DockerRequirement:
    dockerPull: quay.io/biocontainers/bcftools:1.21--h3a4b0d4_0

baseCommand: bcftools
arguments:
  - view
  - --output-type=z
  - --output=subset.vcf.gz

inputs:
  vcf:
    type: File
    secondaryFiles:
      - .tbi
    inputBinding:
      position: 100

  samples:
    type: File
    inputBinding:
      prefix: --samples-file
      position: 1

  regions:
    type: File
    inputBinding:
      prefix: --regions-file
      position: 2

outputs:
  subset_vcf:
    type: File
    outputBinding:
      glob: subset.vcf.gz

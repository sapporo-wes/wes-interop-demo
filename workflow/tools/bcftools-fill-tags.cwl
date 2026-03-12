#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: bcftools +fill-tags — compute AC, AN, AF
doc: |
  Adds allele count (AC), allele number (AN), and allele frequency (AF)
  INFO tags to the VCF. These are the only values extracted as output.

requirements:
  DockerRequirement:
    dockerPull: quay.io/biocontainers/bcftools:1.21--h3a4b0d4_0

baseCommand: bcftools
arguments:
  - +fill-tags
  - --output-type=z
  - --output=tagged.vcf.gz
  - --
  - --tags=AC,AN,AF

inputs:
  vcf:
    type: File
    inputBinding:
      position: 100

outputs:
  tagged_vcf:
    type: File
    outputBinding:
      glob: tagged.vcf.gz

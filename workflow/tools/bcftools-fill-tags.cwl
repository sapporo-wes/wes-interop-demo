#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: bcftools +fill-tags — compute AC, AN, AF
doc: |
  Adds allele count (AC), allele number (AN), and allele frequency (AF)
  INFO tags to the VCF. These are the only values extracted as output.
  Command: bcftools +fill-tags <vcf> --output-type=z --output=tagged.vcf.gz -- --tags=AC,AN,AF

hints:
  DockerRequirement:
    dockerPull: quay.io/biocontainers/bcftools:1.21--h3a4d415_1

baseCommand: bcftools

arguments:
  - position: 1
    valueFrom: "+fill-tags"
  - position: 3
    valueFrom: "--output-type=z"
  - position: 4
    valueFrom: "--output=tagged.vcf.gz"
  - position: 10
    valueFrom: "--"
  - position: 11
    valueFrom: "--tags=AC,AN,AF"

inputs:
  vcf:
    type: File
    inputBinding:
      position: 2

outputs:
  tagged_vcf:
    type: File
    outputBinding:
      glob: tagged.vcf.gz

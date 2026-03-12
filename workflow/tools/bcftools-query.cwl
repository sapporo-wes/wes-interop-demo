#!/usr/bin/env cwl-runner
cwlVersion: v1.0
class: CommandLineTool

label: bcftools query — extract summary TSV
doc: |
  Extracts SNP_ID, REF, ALT, AC, AN, AF into a tab-delimited summary file.
  Input VCF must already have AC/AN/AF INFO tags (from bcftools +fill-tags).
  This is the only output that leaves the site — no per-sample data.

hints:
  DockerRequirement:
    dockerPull: quay.io/biocontainers/bcftools:1.21--h3a4b0d4_0

requirements:
  InlineJavascriptRequirement: {}

baseCommand: [bash, -c]

arguments:
  - valueFrom: |
      ${
        var site = inputs.site_id;
        var vcf = inputs.vcf.path;
        return (
          "printf '#SNP_ID\\tREF\\tALT\\tAC\\tAN\\tAF\\tSITE\\n' > summary.tsv && " +
          "bcftools query " +
          "--format '%ID\\t%REF\\t%ALT\\t%AC\\t%AN\\t%AF\\t" + site + "\\n' " +
          vcf + " >> summary.tsv"
        );
      }

inputs:
  vcf:
    type: File

  site_id:
    type: string

outputs:
  summary:
    type: File
    outputBinding:
      glob: summary.tsv

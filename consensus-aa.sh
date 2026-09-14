#!/usr/bin/env bash
set -euo pipefail
SAMPLE_DIR=${1:?Usage: $0 SAMPLE_DIR REFERENCE}
REF=$(realpath "${2:?Usage: $0 SAMPLE_DIR REFERENCE}")
GFF="${REF%.fasta}.gff3"
BAM=$(realpath "$SAMPLE_DIR/trimmed.sorted.bam")
cd "$SAMPLE_DIR"
samtools mpileup -aa -A -d 0 -B -Q 0 --reference "$REF" "$BAM" | ivar variants -p consensus_level -q 20 -t 0.50 -m 20 -r "$REF" -g "$GFF"
printf "REGION\tPOS\tREF\tALT\tALT_FREQ\tTOTAL_DP\tGFF_FEATURE\tREF_AA\tALT_AA\tPOS_AA\n" > consensus_variants_annotated.tsv
tail -n +2 consensus_level.tsv | cut -f1,2,3,4,11,12,15,17,19,20 >> consensus_variants_annotated.tsv
echo "Created $SAMPLE_DIR/consensus_variants_annotated.tsv"

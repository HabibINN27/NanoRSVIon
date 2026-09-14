#!/usr/bin/env bash
set -euo pipefail
INPUT="${1:-}"
if [[ -z "$INPUT" ]]; then INPUT=$(find . -type f -name minority_variants.tsv -printf "%T@ %p\n" | sort -nr | head -1 | cut -d" " -f2-); fi
[[ -f "$INPUT" ]] || { echo "Error: minority_variants.tsv not found" >&2; exit 1; }
OUTDIR=$(dirname "$INPUT")
for DEPTH in 200 500; do
 OUT="$OUTDIR/minority_variants.AF20-50.depth${DEPTH}.tsv"
 awk -F"\t" -v D="$DEPTH" "BEGIN{OFS=\"\t\"} NR==1{for(i=1;i<=NF;i++)h[\$i]=i; print; next} \$(h[\"ALT_FREQ\"])>=0.20 && \$(h[\"ALT_FREQ\"])<0.50 && \$(h[\"ALT_QUAL\"])>=20 && \$(h[\"TOTAL_DP\"])>=D{print}" "$INPUT" > "$OUT"
 echo "Depth >=${DEPTH}x: $(awk "NR>1{n++}END{print n+0}" "$OUT") candidate(s)"
 echo "Output: $OUT"
done

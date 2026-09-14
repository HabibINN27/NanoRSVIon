#!/usr/bin/env bash
set -Eeuo pipefail
usage(){ cat <<'EOF'
Usage: rsv-subclade.sh --run-dir RUN [--run-dir RUN ...] --references REFS.fasta [--outdir DIR]
REFS.fasta headers should include labels, e.g. >ref1|subclade=ON1.
Requires MAFFT and IQ-TREE (iqtree2 or iqtree).
EOF
}
RUNS=(); REFS=""; OUTDIR=""
while (($#)); do case "$1" in
  --run-dir) RUNS+=("$2"); shift 2;; --references) REFS="$2"; shift 2;;
  --outdir) OUTDIR="$2"; shift 2;; -h|--help) usage; exit 0;;
  *) echo "Unknown option: $1" >&2; usage >&2; exit 2;; esac; done
[[ ${#RUNS[@]} -gt 0 && -s "$REFS" ]] || { usage >&2; exit 2; }
command -v mafft >/dev/null || { echo 'ERROR: MAFFT is required' >&2; exit 1; }
IQ="$(command -v iqtree2 || command -v iqtree || true)"; [[ -n "$IQ" ]] || { echo 'ERROR: IQ-TREE is required' >&2; exit 1; }
OUTDIR="${OUTDIR:-rsv_subclade_$(date +%Y%m%d_%H%M%S)}"; mkdir -p "$OUTDIR"
cp "$REFS" "$OUTDIR/references.fasta"; SAMPLES="$OUTDIR/samples.fasta"; : > "$SAMPLES"
MANIFEST="$OUTDIR/subclade_input_manifest.tsv"; printf 'sample\trun\trsv_type\tconsensus\n' > "$MANIFEST"
for run in "${RUNS[@]}"; do
  [[ -d "$run" ]] || { echo "WARNING: missing run: $run" >&2; continue; }
  for sample in "$run"/*; do
    [[ -d "$sample" && -s "$sample/consensus.masked.fasta" ]] || continue
    name="$(basename "$sample")"; safe="${name//[^A-Za-z0-9_.-]/_}"
    type="$(awk -F '\t' '$1=="rsv_type"{print $2}' "$sample/run_manifest.tsv" 2>/dev/null || true)"
    awk -v id="sample_${safe}" 'BEGIN{p=0} /^>/{print ">" id; p=1; next} p{print}' "$sample/consensus.masked.fasta" >> "$SAMPLES"
    printf '%s\t%s\t%s\t%s\n' "$name" "$(basename "$run")" "${type:-NA}" "$sample/consensus.masked.fasta" >> "$MANIFEST"
  done
done
[[ -s "$SAMPLES" ]] || { echo 'ERROR: no consensus files found' >&2; exit 1; }
cat "$OUTDIR/references.fasta" "$SAMPLES" > "$OUTDIR/all_sequences.fasta"
mafft --auto --thread -1 "$OUTDIR/all_sequences.fasta" > "$OUTDIR/alignment.fasta" 2> "$OUTDIR/mafft.log"
"$IQ" --auto -m MFP -B 1000 --alrt 1000 -T AUTO --prefix "$OUTDIR/rsv_subclade" "$OUTDIR/alignment.fasta" > "$OUTDIR/iqtree.log" 2>&1
printf 'sample\trsv_type\tassigned_subclade\tbootstrap_support\tnote\n' > "$OUTDIR/subclade_assignments.tsv"
tail -n +2 "$MANIFEST" | while IFS=$'\t' read -r sample run type consensus; do
  printf '%s\t%s\t%s\t%s\t%s\n' "$sample" "$type" 'REVIEW_TREE' 'see_tree' 'Assignment requires curated reference labels and phylogenetic review' >> "$OUTDIR/subclade_assignments.tsv"
done
echo "Tree written to $OUTDIR/rsv_subclade.treefile"
echo "Review $OUTDIR/subclade_assignments.tsv; reference headers must include |subclade=LABEL"

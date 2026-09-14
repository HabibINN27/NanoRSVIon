# RSV Nanopore Consensus Pipeline

Version 1.0.0 — an interactive Bash pipeline for assembling RSV-A and RSV-B amplicon Nanopore reads into a masked consensus FASTA.

## What it does

The pipeline runs minimap2 alignment, iVar primer trimming, Medaka polishing/variant calling/annotation in Docker, bcftools filtering, and depth-based masking.

It is intended for research use. It has not been independently validated here for clinical diagnosis or patient-management decisions.

## Requirements

- Linux with Bash 4+
- Docker, accessible either through the `docker` group or passwordless `sudo docker`
- The tools listed in `environment.yml`: minimap2, samtools, iVar, bcftools, htslib/tabix
- Internet access the first time the Medaka image is pulled
- Sufficient CPU, RAM, disk space, and permissions for the output directory

Create the Conda environment:

```bash
conda env create -f environment.yml
conda activate rsv-nanopore
```

The pipeline uses a pinned Medaka image by default. To use a deliberately different tested image, set `MEDAKA_IMAGE` explicitly.

### Optional: Nextclade lineage assignment

If a separate Conda environment named `viral` exists with Nextclade installed, the pipeline automatically calls it after consensus generation to assign an RSV-A/RSV-B lineage:

```bash
conda create -n viral -c bioconda -c conda-forge nextclade
```

If that environment or Nextclade is not present, lineage assignment is skipped and the rest of the run is unaffected.

### Optional: subclade tree utility (`rsv-subclade.sh`)

`rsv-subclade.sh` builds a MAFFT/IQ-TREE subclade tree from one or more completed run directories. It requires MAFFT and IQ-TREE (`iqtree2` or `iqtree`) on `PATH`:

```bash
conda install -n rsv-nanopore -c bioconda mafft iqtree
```

It is not called automatically by the main pipeline; run it separately once you have completed sample runs.

## Run

From this directory:

```bash
./rsv-nanopore
```

The interactive prompts select RSV type, primer scheme, minimum depth, CPU threads, and the basecalling model:

- HAC: `r1041_e82_400bps_hac_v5.0.0`
- SUP: `r1041_e82_400bps_sup_v5.0.0`

For automation, threads and model can be supplied on the command line:

```bash
./rsv-nanopore --threads 12 --model sup
./rsv-nanopore --threads 8 --model hac --keep
```

Use `./rsv-nanopore --help` for the available options.

Primer schemes can be selected interactively: packaged RSV-750, an ARTIC BED found in the current/home directory (or entered by path), or any other custom BED path.

FASTQ files are currently discovered in the top level of `$HOME`, or of the directory given by `--input-dir`. Reference, primer and GFF3 files are discovered in `$HOME` and the current directory only; `--input-dir` does not relocate them. Run the command from this directory when using the packaged assets.

## Minority variants

The interactive run can optionally call minority variants with iVar after primer trimming. Default settings are 20–<50% allele frequency, ≥200× total depth, ≥20 alternate reads present on both strands, base quality ≥20, excluding the outermost 100 bp of the reference. Each threshold can be overridden via the matching `MINORITY_*` environment variable. Results are written separately as `minority_variants.tsv` (raw iVar output) and `minority_variants.filtered.tsv` (after the filter above); they do not alter the consensus. Treat low-frequency Nanopore calls as research-level findings and confirm important variants independently.

`vm1.sh` is a small standalone helper that re-filters an existing `minority_variants.tsv` to the 20–50% allele-frequency band at two depth thresholds (200x/500x); run it manually against a run's output when needed.

## Outputs

A timestamped `nanopore_output_YYYYMMDD_HHMMSS/` directory is created. Each sample has its own directory containing, among other files:

- `consensus.masked.fasta` — final depth-masked consensus
- `consensus.filtered.vcf.gz` and its index — filtered variants
- `flagstat.txt` — alignment statistics
- `depth.txt` and `mask.bed` — coverage and masked intervals

Temporary `medaka_out/` files are removed by default. Use `--keep` to retain them.

## Packaged reference and primer assets

The directory includes the following local assets:

| RSV type | Reference | Primer BED |
|---|---|---|
| RSV-A | `PP109421.1.fasta` (accession PP109421.1) | `RSV_750_primers_PP109421.bed` |
| RSV-B | `OP975389.1.fasta` (accession OP975389.1) | `RSV_750_primers_OP975389.bed` |

**Primer coordinates.** The packaged BED files give primer positions on the matching reference. They were derived from the published primer sequences (Supplementary Table 2 of the RSV-750 scheme) by locating each primer on the reference, allowing for IUPAC ambiguity codes and strain mismatches. Column 5 is the pool number; the RSV-B scheme is 26 amplicons split evenly across two pools.

**Known limitation of the RSV-B scheme.** `RSV_750_primers_OP975389.bed` contains 52 of the 53 RSV-B primers. The amplicon-1 left primer (`RSVB_750__1_LEFT2`) is omitted because its binding site lies upstream of where OP975389.1 begins: this reference is 5'-truncated by roughly 40 nucleotides relative to the full RSV-B genome, starting inside the leader region rather than at the genome terminus. Amplicon 1 therefore has no left primer to trim against, and the 5' end of the reference is not primer-trimmed. The region is non-coding (NS1 begins at position 57), but the first ~30 bases of RSV-B consensus sequences should be interpreted with this in mind. Using a full-length RSV-B reference would resolve it.

Seven RSV-B primers match this reference with 1-5 mismatches and are retained at full length, since iVar soft-clips the primer footprint regardless of mismatch.

The `.fai` files are FASTA indexes corresponding to the packaged references. `SHA256SUMS` records the exact files used for this release. Confirm that the references and primer scheme are appropriate for your study and cite their original sources before redistribution.

## Reproducibility and rights

The source code and bundled assets remain copyright of Habib Benainouna. See `LICENSE` for the redistribution terms. Keep the accession/provenance information and checksum file when copying the package.

## Citation

See `CITATION.cff`. Changes are tracked in `CHANGELOG.md`.

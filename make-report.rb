#!/usr/bin/env ruby
# Per-sample QC summary + coverage plot.
# Depth threshold is passed in from the pipeline (ARGV[2]) so the reported
# breadth matches the threshold actually used for masking, instead of a
# hardcoded 50x.
sample=ARGV.fetch(0)
ref=ARGV[1] || "reference"
thr=(ARGV[2] || 50).to_i
depth=File.join(sample,"depth.txt")
flag=File.join(sample,"flagstat.txt")
aa=File.join(sample,"consensus_variants_annotated.tsv")
rows=File.readlines(depth).map{|l| x=l.split; [x[1].to_i,x[2].to_i]}
mean=rows.sum{|x|x[1]}.to_f/rows.length
breadth=rows.count{|x|x[1]>=thr}.to_f/rows.length*100
low=rows.count{|x|x[1]<thr}
total=(File.read(flag)[/^(\d+) \+ \d+ in total/,1]||0).to_i
mapped=(File.read(flag)[/^\s*(\d+) \+ \d+ mapped/,1]||0).to_i
aa_n=File.exist?(aa) ? [File.readlines(aa).length-1,0].max : 0
syn=0
nonsyn=0
if File.exist?(aa)
  File.foreach(aa).with_index{|l,i| next if i==0; a=l.chomp.split("\t"); next if a.length<9; a[7]==a[8] ? syn+=1 : nonsyn+=1}
end
out=File.join(sample,"qc_summary.tsv")
File.write(out, ["metric\tvalue",
  "total_reads\t#{total}",
  "mapped_reads\t#{mapped}",
  "mapping_percent\t#{total>0 ? (mapped.to_f/total*100).round(2) : 0}",
  "mean_depth\t#{mean.round(2)}",
  "depth_threshold\t#{thr}",
  "breadth_at_threshold_percent\t#{breadth.round(2)}",
  "positions_below_threshold\t#{low}",
  "consensus_aa_table_rows\t#{aa_n}",
  "consensus_synonymous\t#{syn}",
  "consensus_nonsynonymous\t#{nonsyn}"].join("\n")+"\n")
if File.exist?(aa)
  File.write(File.join(sample,"consensus_nonsynonymous.tsv"), File.readlines(aa).select.with_index{|l,i| i==0 || (a=l.chomp.split("\t")).length>=9 && a[7]!=a[8]}.join)
  File.write(File.join(sample,"consensus_synonymous.tsv"), File.readlines(aa).select.with_index{|l,i| i==0 || (a=l.chomp.split("\t")).length>=9 && a[7]==a[8]}.join)
end
# Coverage plot is produced solely by make-coverage.rb (the previous inline
# linear-scale SVG here was overwritten by it immediately and has been removed).
cov=File.join(File.dirname(File.expand_path(__FILE__)),"make-coverage.rb")
if File.executable?(cov)
  ok=system(cov, sample, ref, thr.to_s)
  warn "WARNING: make-coverage.rb failed for #{sample}" unless ok
else
  warn "WARNING: #{cov} not found or not executable; coverage.svg not generated"
end
puts "Created qc_summary.tsv, consensus_synonymous.tsv, consensus_nonsynonymous.tsv"

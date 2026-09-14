#!/usr/bin/env ruby
# Renders a log-scale coverage plot (coverage.svg) for one sample.
# Gene (G/F) marker boxes are read from the GFF3 matching the reference
# FASTA (same basename, .gff3 extension) instead of being hardcoded to
# one subtype's coordinates, so RSV-A and RSV-B samples both get correct
# gene boundaries, and a missing/unmatched GFF3 just omits the boxes
# instead of drawing them in the wrong place.

sample = ARGV.fetch(0)
ref    = ARGV.fetch(1)

depth = File.readlines(File.join(sample, "depth.txt")).map { |l| a = l.split; [a[1].to_i, a[2].to_f] }
len   = depth.last[0]
max   = depth.map(&:last).max
threshold = (ARGV[2] || 100).to_i
left, top = 120, 120
plot_w, plot_h = 1500, 570
logmax = Math.log10([max, threshold].max)
y = ->(v) { top + plot_h - Math.log10([v, 1].max) / logmax * plot_h }
step = [depth.length / 1200, 1].max
points = depth.each_slice(step).map { |g|
  "#{(left + g.first[0].to_f / len * plot_w).round(1)},#{y.call(g.sum { |z| z[1] } / g.length).round(1)}"
}.join(" ")

grid = [1, 10, 100, 1000, 10000, 100000, 1000000].select { |v| v <= 10**logmax }.map { |v|
  yy = y.call(v)
  "<line x1=\"#{left}\" y1=\"#{yy}\" x2=\"#{left + plot_w}\" y2=\"#{yy}\" stroke=\"#cbd5e1\"/><text x=\"#{left - 12}\" y=\"#{yy + 6}\" text-anchor=\"end\">#{v}×</text>"
}.join

xmarks = (0..7).map { |i|
  pos = (len * i / 7.0).round
  xx = left + pos.to_f / len * plot_w
  "<line x1=\"#{xx}\" y1=\"#{top + plot_h}\" x2=\"#{xx}\" y2=\"#{top + plot_h + 8}\" stroke=\"#334155\"/><text x=\"#{xx}\" y=\"#{top + plot_h + 32}\" text-anchor=\"middle\">#{pos}</text>"
}.join

# Read gene coordinates from the GFF3 matching this reference instead of
# hardcoding one subtype's numbers (was: RSV-B numbers used for every sample).
gff_path = ref.sub(/\.fasta\z/, ".gff3")
genes = {}
if File.exist?(gff_path)
  File.foreach(gff_path) do |line|
    next if line.start_with?("#")
    cols = line.chomp.split("\t")
    next unless cols.length >= 9 && cols[2] == "gene"
    name = cols[8][/gene=([^;]+)/, 1]
    genes[name] = [cols[3].to_i, cols[4].to_i] if name
  end
end

gene_boxes = [["G", "#f59e0b"], ["F", "#2563eb"]].map { |name, color|
  next nil unless genes[name]
  gstart, gend = genes[name]
  gx = left + gstart.to_f / len * plot_w
  gw = (gend - gstart).to_f / len * plot_w
  "<rect x=\"#{gx}\" y=\"#{top + plot_h + 105}\" width=\"#{gw}\" height=\"32\" fill=\"#{color}\"/><text x=\"#{gx + gw / 2}\" y=\"#{top + plot_h + 127}\" text-anchor=\"middle\" fill=\"white\">#{name}</text>"
}.compact.join
gene_label = genes.empty? ? "" : "<text x=\"#{left - 15}\" y=\"#{top + plot_h + 125}\" text-anchor=\"end\" font-weight=\"bold\">Genes</text>"

barcode = File.basename(sample)
title = "Genome coverage — #{barcode}"
sub = "Reference #{File.basename(ref)} • Log-scale depth • Threshold #{threshold}×"

svg = <<~SVG
  <svg xmlns="http://www.w3.org/2000/svg" width="1700" height="900"><style>text{font-family:Arial,sans-serif;fill:#0f172a}.title{font-size:30px;font-weight:bold}.sub{font-size:18px;fill:#475569}.axis{font-size:22px;font-weight:bold}</style><rect width="100%" height="100%" fill="white"/><text class="title" x="850" y="45" text-anchor="middle">#{title}</text><text class="sub" x="850" y="78" text-anchor="middle">#{sub}</text>#{grid}<line x1="#{left}" y1="#{y.call(threshold)}" x2="#{left + plot_w}" y2="#{y.call(threshold)}" stroke="#dc2626" stroke-width="3" stroke-dasharray="10,8"/><text x="#{left + plot_w - 5}" y="#{y.call(threshold) - 10}" text-anchor="end" fill="#dc2626">Threshold #{threshold}×</text><polyline points="#{points}" fill="none" stroke="#0f766e" stroke-width="2.5"/><line x1="#{left}" y1="#{top + plot_h}" x2="#{left + plot_w}" y2="#{top + plot_h}" stroke="#334155" stroke-width="2"/><line x1="#{left}" y1="#{top}" x2="#{left}" y2="#{top + plot_h}" stroke="#334155" stroke-width="2"/>#{xmarks}<text class="axis" x="#{left + plot_w / 2}" y="#{top + plot_h + 75}" text-anchor="middle">Nucleotide position</text><text class="axis" transform="translate(30 #{top + plot_h / 2}) rotate(-90)" text-anchor="middle">Coverage depth (log scale, ×)</text>#{gene_label}#{gene_boxes}<rect x="#{left}" y="#{top}" width="#{plot_w}" height="#{plot_h}" fill="none" stroke="#334155"/></svg>
SVG

File.write(File.join(sample, "coverage.svg"), svg)
puts "Created #{sample}/coverage.svg#{genes.empty? ? " (no matching GFF3 found — gene markers omitted)" : ""}"

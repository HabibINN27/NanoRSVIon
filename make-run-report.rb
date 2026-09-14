#!/usr/bin/env ruby
require 'csv'
base=ARGV.fetch(0)
title=File.basename(base)
rows=[]
thresholds=[]
Dir[File.join(base,'*')].select{|p| File.directory?(p)}.sort_by{|p| File.basename(p).to_i}.each do |s|
  name=File.basename(s); m={}; q={}
  (File.readlines(File.join(s,'run_manifest.tsv')) rescue []).each{|l| a=l.chomp.split("\t",2); m[a[0]]=a[1]}
  (File.readlines(File.join(s,'qc_summary.tsv')) rescue []).each{|l| a=l.chomp.split("\t",2); q[a[0]]=a[1]}
  clade='Not assigned'; nc=File.join(s,'nextclade_report.csv')
  if File.file?(nc)
    begin
      r=CSV.read(nc,col_sep:';',headers:true).first; clade=r['clade'] || clade
    rescue StandardError; end
  end
  breadth=q['breadth_at_threshold_percent']||q['breadth_at_50x_percent']||'NA'
  thr=q['depth_threshold']||'50'
  thresholds << thr
  rows << [name,m['rsv_type']||'NA',clade,q['mapping_percent']||'NA',q['mean_depth']||'NA',breadth]
end
thr_label=thresholds.uniq.size==1 ? thresholds.first : 'threshold'
html=<<~HTML
<!doctype html><html><head><meta charset="utf-8"><title>#{title}</title>
<style>body{font-family:Arial,sans-serif;margin:32px;color:#172033}h1{color:#123b68}table{border-collapse:collapse;width:100%;font-size:13px}th{background:#123b68;color:white}td,th{border:1px solid #ccd3dd;padding:7px;text-align:left}tr:nth-child(even){background:#f4f7fa}.note{color:#566}</style></head>
<body><h1>RSV sequencing run report</h1><p><b>Run:</b> #{title}</p><p class="note">Lineages assigned by Nextclade; inspect QC status before publication.</p>
<table><tr><th>Barcode</th><th>RSV type</th><th>Lineage</th><th>Mapping %</th><th>Mean depth</th><th>Breadth ≥#{thr_label}×</th></tr>
#{rows.map{|r| '<tr>'+r.map{|x| "<td>#{x}</td>"}.join+'</tr>'}.join}
</table></body></html>
HTML
File.write(File.join(base,'run_report.html'),html)
puts "Created #{File.join(base,'run_report.html')}"

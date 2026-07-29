#!/usr/bin/env crystal
require "./asciidoctor_kroki"
require "option_parser"

input_file = ""
output_file = ""

OptionParser.parse do |parser|
  parser.banner = "Usage: asciicrystal-kroki [options] file.adoc"
  parser.on("-o FILE", "--out-file FILE", "Output HTML file (default: stdout)") { |f| output_file = f }
  parser.on("-h", "--help", "Show help") { puts parser; exit 0 }
  parser.on("-v", "--version", "Show version") { puts "asciicrystal-kroki #{AsciicrystalKroki::VERSION}"; exit 0 }
  parser.unknown_args { |args| input_file = args.first? || "" }
end

if input_file.empty?
  STDERR.puts "Error: no input file specified."
  STDERR.puts "Usage: asciicrystal-kroki [options] file.adoc"
  exit 1
end

unless File.exists?(input_file)
  STDERR.puts "Error: file '#{input_file}' does not exist."
  exit 1
end

# Load and convert the document with Kroki extensions
html = AsciicrystalKroki.convert_file(input_file, {"safe" => "safe"})

if output_file.empty?
  puts html
else
  File.write(output_file, html)
  puts "HTML generated: #{output_file}"
end

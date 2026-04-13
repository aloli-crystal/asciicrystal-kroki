require "./asciidoctor_kroki/encoder"
require "./asciidoctor_kroki/extension"

module AsciidoctorKroki
  VERSION = "0.10.2"

  # Version of the Ruby asciidoctor-kroki gem used as reference.
  UPSTREAM_VERSION = "0.10.2"

  # Load an AsciiDoc source string with Kroki extensions enabled.
  #
  # This is a convenience wrapper around `Asciidoctor.load` that:
  # 1. Loads the document without parsing
  # 2. Creates and activates an extensions registry with Kroki processors
  # 3. Parses the document (which runs TreeProcessors and BlockMacroProcessors)
  #
  # Returns the parsed Document.
  def self.load(source : String, options : Hash(String, String) = {} of String => String) : Asciidoctor::Document
    options["parse"] = "false"
    doc = Asciidoctor.load(source, options)
    activate_extensions(doc)
    reader = doc.reader.not_nil!
    Asciidoctor::Parser.parse(reader, doc)
    doc.parsed = true
    doc
  end

  # Load an AsciiDoc file with Kroki extensions enabled.
  def self.load_file(filename : String, options : Hash(String, String) = {} of String => String) : Asciidoctor::Document
    source = File.read(filename)
    options["docfile"] = File.expand_path(filename)
    options["docdir"] = File.dirname(File.expand_path(filename))
    options["docname"] = File.basename(filename, File.extname(filename))
    options["docfilesuffix"] = File.extname(filename)
    load(source, options)
  end

  # Convert an AsciiDoc source string to HTML with Kroki extensions enabled.
  def self.convert(source : String, options : Hash(String, String) = {} of String => String) : String
    doc = load(source, options)
    converter = doc.converter.not_nil!
    converter.convert(doc)
  end

  # Convert an AsciiDoc file to HTML with Kroki extensions enabled.
  def self.convert_file(filename : String, options : Hash(String, String) = {} of String => String) : String
    doc = load_file(filename, options)
    converter = doc.converter.not_nil!
    converter.convert(doc)
  end

  # Activate Kroki extensions on a document.
  protected def self.activate_extensions(doc : Asciidoctor::Document) : Nil
    registry = Asciidoctor::Extensions::Registry.new
    group = KrokiExtensionGroup.new
    group.activate(registry)
    registry.activate(doc)
    doc.extensions = registry
  end
end

require "crystal-asciidoctor"
require "./encoder"

module AsciidoctorKroki
  # Supported diagram types recognized by Kroki.
  DIAGRAM_TYPES = %w[
    plantuml mermaid ditaa graphviz dot
    blockdiag seqdiag actdiag nwdiag packetdiag rackdiag
    c4plantuml erd nomnoml svgbob
    vega vegalite wavedrom pikchr d2 dbml
    structurizr excalidraw wireviz tikz bytefield bpmn
  ]

  # Set of diagram types for fast lookup.
  DIAGRAM_TYPES_SET = DIAGRAM_TYPES.to_set

  # Default Kroki server URL.
  DEFAULT_SERVER_URL = "https://kroki.io"

  # Default output format.
  DEFAULT_FORMAT = "svg"

  # ------------------------------------------------------------------
  # TreeProcessor -- walks the AST after parsing and replaces diagram
  # blocks with pass blocks containing <img> tags pointing to Kroki.
  #
  # This approach is used because the crystal-asciidoctor parser does
  # not yet invoke BlockProcessor extensions for custom block names.
  # The parser preserves the original style in attributes["style"]
  # (e.g., "plantuml") even when the block context is :listing.
  # ------------------------------------------------------------------

  class KrokiTreeProcessor < Asciidoctor::Extensions::TreeProcessor
    def process(document : Asciidoctor::Document) : Asciidoctor::Document?
      process_blocks(document)
      document
    end

    private def process_blocks(parent : Asciidoctor::AbstractBlock) : Nil
      parent.blocks.each_with_index do |block, i|
        if block.is_a?(Asciidoctor::Block)
          diagram_type = block.attributes["style"]?
          if diagram_type && DIAGRAM_TYPES_SET.includes?(diagram_type)
            replacement = convert_diagram_block(block, parent, diagram_type)
            if replacement
              parent.blocks[i] = replacement
            end
          end
        end

        # Recurse into child blocks
        process_blocks(block)
      end
    end

    private def convert_diagram_block(block : Asciidoctor::Block, parent : Asciidoctor::AbstractBlock, diagram_type : String) : Asciidoctor::Block?
      source = block.source
      return nil if source.strip.empty?

      doc = block.document
      server_url = doc.attr("kroki-server-url") || DEFAULT_SERVER_URL
      format = block.attributes["format"]? || doc.attr("kroki-default-format") || DEFAULT_FORMAT

      url = Encoder.build_url(server_url, diagram_type, format, source)

      alt_text = block.attributes["alt"]? || diagram_type
      title = block.attributes["title"]? || block.title
      width = block.attributes["width"]?
      height = block.attributes["height"]?

      html = String.build do |io|
        io << %(<div class="imageblock kroki">)
        io << %(<div class="content">)
        io << %(<img src="#{HTML.escape(url)}" alt="#{HTML.escape(alt_text)}")
        io << %( width="#{HTML.escape(width)}") if width
        io << %( height="#{HTML.escape(height)}") if height
        io << %(>)
        io << %(</div>)
        if title
          io << %(<div class="title">#{HTML.escape(title)}</div>)
        end
        io << %(</div>)
      end

      block = create_pass_block(parent, html, {} of String => String)
      # Ensure no substitutions are applied to the raw HTML.
      # Setting subs_list to a non-empty list prevents the content method
      # from falling back to default specialcharacters substitutions.
      block.subs_list = [:none] of Symbol
      block
    end
  end

  # ------------------------------------------------------------------
  # BlockMacroProcessor -- handles diagram_type::target[attributes]
  # ------------------------------------------------------------------

  class KrokiBlockMacroProcessor < Asciidoctor::Extensions::BlockMacroProcessor
    def initialize(name : String)
      super(name)
    end

    def process(parent : Asciidoctor::AbstractBlock, target : String, attributes : Hash(String, String)) : Asciidoctor::AbstractBlock | Asciidoctor::Inline | Nil
      diagram_type = @name.not_nil!
      doc = parent.document
      server_url = doc.attr("kroki-server-url") || DEFAULT_SERVER_URL
      format = attributes["format"]? || doc.attr("kroki-default-format") || DEFAULT_FORMAT

      # The target is the diagram source file path -- read it if possible,
      # otherwise use target as literal source text.
      source = begin
        path = parent.normalize_system_path(target)
        if File.exists?(path)
          File.read(path)
        else
          target
        end
      rescue
        target
      end

      url = Encoder.build_url(server_url, diagram_type, format, source)

      alt_text = attributes["alt"]? || diagram_type
      title = attributes["title"]?

      html = String.build do |io|
        io << %(<div class="imageblock kroki">)
        io << %(<div class="content">)
        io << %(<img src="#{HTML.escape(url)}" alt="#{HTML.escape(alt_text)}">)
        io << %(</div>)
        if title
          io << %(<div class="title">#{HTML.escape(title)}</div>)
        end
        io << %(</div>)
      end

      block = create_pass_block(parent, html, {} of String => String)
      block.subs_list = [:none] of Symbol
      block
    end
  end

  # ------------------------------------------------------------------
  # InlineMacroProcessor -- handles diagram_type:source[attributes]
  # ------------------------------------------------------------------

  class KrokiInlineMacroProcessor < Asciidoctor::Extensions::InlineMacroProcessor
    def initialize(name : String)
      super(name)
    end

    def process(parent : Asciidoctor::AbstractBlock, target : String, attributes : Hash(String, String)) : Asciidoctor::AbstractBlock | Asciidoctor::Inline | Nil
      diagram_type = @name.not_nil!
      doc = parent.document
      server_url = doc.attr("kroki-server-url") || DEFAULT_SERVER_URL
      format = attributes["format"]? || doc.attr("kroki-default-format") || DEFAULT_FORMAT

      url = Encoder.build_url(server_url, diagram_type, format, target)
      alt_text = attributes["alt"]? || diagram_type

      html = %(<img src="#{HTML.escape(url)}" alt="#{HTML.escape(alt_text)}" class="kroki">)
      create_inline(parent, :quoted, html, {"type" => :pass} of String => String | Symbol)
    end
  end

  # ------------------------------------------------------------------
  # Extension Group -- registers all processors at once
  # ------------------------------------------------------------------

  class KrokiExtensionGroup < Asciidoctor::Extensions::Group
    def activate(registry : Asciidoctor::Extensions::Registry) : Nil
      # TreeProcessor for handling [plantuml]/[mermaid]/etc. delimited blocks
      registry.tree_processor(KrokiTreeProcessor.new)

      # Block macros for diagram_type::file.puml[] syntax
      DIAGRAM_TYPES.each do |diagram_type|
        registry.block_macro(KrokiBlockMacroProcessor.new(diagram_type))
        registry.inline_macro(KrokiInlineMacroProcessor.new(diagram_type))
      end
    end
  end

  # Register the extension group globally.
  def self.register : Nil
    Asciidoctor::Extensions.register(:kroki, KrokiExtensionGroup)
  end

  # Unregister the extension group globally.
  def self.unregister : Nil
    Asciidoctor::Extensions.unregister(:kroki)
  end
end

require "./spec_helper"

describe AsciidoctorKroki::Encoder do
  describe ".encode" do
    it "encodes diagram source text as deflate + base64url" do
      source = "A -> B: Hello"
      encoded = AsciidoctorKroki::Encoder.encode(source)

      # Result should be a non-empty URL-safe base64 string
      encoded.should_not be_empty
      encoded.should_not contain("+")
      encoded.should_not contain("/")
      encoded.should_not contain("=")
    end

    it "produces deterministic output" do
      source = "digraph G { A -> B }"
      a = AsciidoctorKroki::Encoder.encode(source)
      b = AsciidoctorKroki::Encoder.encode(source)
      a.should eq(b)
    end

    it "round-trips through decode" do
      source = "participant Alice\nparticipant Bob\nAlice -> Bob: Hello"
      encoded = AsciidoctorKroki::Encoder.encode(source)
      decoded = AsciidoctorKroki::Encoder.decode(encoded)
      decoded.should eq(source)
    end

    it "handles empty string" do
      encoded = AsciidoctorKroki::Encoder.encode("")
      decoded = AsciidoctorKroki::Encoder.decode(encoded)
      decoded.should eq("")
    end

    it "handles multi-line diagram source" do
      source = <<-PLANTUML
      @startuml
      Alice -> Bob: Authentication Request
      Bob --> Alice: Authentication Response
      @enduml
      PLANTUML
      encoded = AsciidoctorKroki::Encoder.encode(source)
      decoded = AsciidoctorKroki::Encoder.decode(encoded)
      decoded.should eq(source)
    end
  end

  describe ".build_url" do
    it "builds a correct Kroki URL for plantuml" do
      source = "A -> B"
      url = AsciidoctorKroki::Encoder.build_url("https://kroki.io", "plantuml", "svg", source)
      url.should start_with("https://kroki.io/plantuml/svg/")
      url.size.should be > "https://kroki.io/plantuml/svg/".size
    end

    it "builds a correct URL for mermaid with png format" do
      source = "graph TD; A-->B;"
      url = AsciidoctorKroki::Encoder.build_url("https://kroki.io", "mermaid", "png", source)
      url.should start_with("https://kroki.io/mermaid/png/")
    end

    it "uses custom server URL" do
      source = "digraph { A -> B }"
      url = AsciidoctorKroki::Encoder.build_url("https://my-kroki.example.com", "graphviz", "svg", source)
      url.should start_with("https://my-kroki.example.com/graphviz/svg/")
    end

    it "builds URLs for all supported diagram types" do
      AsciidoctorKroki::DIAGRAM_TYPES.each do |diagram_type|
        url = AsciidoctorKroki::Encoder.build_url("https://kroki.io", diagram_type, "svg", "test")
        url.should start_with("https://kroki.io/#{diagram_type}/svg/")
      end
    end
  end
end

describe AsciidoctorKroki do
  describe "KrokiTreeProcessor" do
    it "converts a plantuml block to an img tag" do
      input = <<-ADOC
      = Test Document

      [plantuml]
      ----
      Alice -> Bob: Hello
      ----
      ADOC

      html = AsciidoctorKroki.convert(input, {"safe" => "safe", "header_footer" => "false"})
      html.should contain("kroki.io/plantuml/svg/")
      html.should contain("<img src=")
      html.should contain("class=\"imageblock kroki\"")
    end

    it "converts a mermaid block to an img tag" do
      input = <<-ADOC
      = Test

      [mermaid]
      ----
      graph TD
        A --> B
      ----
      ADOC

      html = AsciidoctorKroki.convert(input, {"safe" => "safe", "header_footer" => "false"})
      html.should contain("kroki.io/mermaid/svg/")
      html.should contain("<img src=")
    end

    it "respects kroki-server-url attribute" do
      input = <<-ADOC
      = Test
      :kroki-server-url: https://my-kroki.example.com

      [plantuml]
      ----
      A -> B
      ----
      ADOC

      html = AsciidoctorKroki.convert(input, {"safe" => "safe", "header_footer" => "false"})
      html.should contain("my-kroki.example.com/plantuml/svg/")
    end

    it "respects kroki-default-format attribute" do
      input = <<-ADOC
      = Test
      :kroki-default-format: png

      [plantuml]
      ----
      A -> B
      ----
      ADOC

      html = AsciidoctorKroki.convert(input, {"safe" => "safe", "header_footer" => "false"})
      html.should contain("kroki.io/plantuml/png/")
    end

    it "converts a ditaa block" do
      input = <<-ADOC
      = Test

      [ditaa]
      ----
      +--------+   +-------+
      |        |-->|       |
      |  cBLU  |   | cPNK  |
      +--------+   +-------+
      ----
      ADOC

      html = AsciidoctorKroki.convert(input, {"safe" => "safe", "header_footer" => "false"})
      html.should contain("kroki.io/ditaa/svg/")
    end

    it "converts a graphviz block" do
      input = <<-ADOC
      = Test

      [graphviz]
      ----
      digraph G {
        A -> B
        B -> C
      }
      ----
      ADOC

      html = AsciidoctorKroki.convert(input, {"safe" => "safe", "header_footer" => "false"})
      html.should contain("kroki.io/graphviz/svg/")
    end

    it "preserves non-diagram listing blocks" do
      input = <<-ADOC
      = Test

      [source,crystal]
      ----
      puts "Hello"
      ----
      ADOC

      html = AsciidoctorKroki.convert(input, {"safe" => "safe", "header_footer" => "false"})
      html.should_not contain("kroki.io")
      html.should contain("Hello")
    end

    it "encodes the diagram source in the URL" do
      source = "A -> B"
      input = <<-ADOC
      [plantuml]
      ----
      #{source}
      ----
      ADOC

      html = AsciidoctorKroki.convert(input, {"safe" => "safe", "header_footer" => "false"})
      expected_encoded = AsciidoctorKroki::Encoder.encode(source)
      html.should contain(expected_encoded)
    end
  end

  describe "DIAGRAM_TYPES" do
    it "includes all expected diagram types" do
      AsciidoctorKroki::DIAGRAM_TYPES.should contain("plantuml")
      AsciidoctorKroki::DIAGRAM_TYPES.should contain("mermaid")
      AsciidoctorKroki::DIAGRAM_TYPES.should contain("ditaa")
      AsciidoctorKroki::DIAGRAM_TYPES.should contain("graphviz")
      AsciidoctorKroki::DIAGRAM_TYPES.should contain("dot")
      AsciidoctorKroki::DIAGRAM_TYPES.should contain("d2")
      AsciidoctorKroki::DIAGRAM_TYPES.should contain("excalidraw")
      AsciidoctorKroki::DIAGRAM_TYPES.should contain("bpmn")
      AsciidoctorKroki::DIAGRAM_TYPES.size.should eq(27)
    end
  end
end

class GpuTextSearch < Formula
  desc "Ultra-high-performance GPU-accelerated text search using Metal compute shaders"
  homepage "https://github.com/teenu/gpu-text-search"
  url "https://github.com/teenu/gpu-text-search.git",
      tag:      "v1.0.0",
      revision: "e09c5dc5b2c63bba15d079eb2cb81b964dd807e0"
  license "MIT"
  head "https://github.com/teenu/gpu-text-search.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on :macos => :ventura
  uses_from_macos "swift" => :build

  def install
    args = ["--disable-sandbox", "-c", "release"]
    system "swift", "build", *args
    bin.install ".build/release/search-cli" => "gpu-text-search"
    
    # Install the Metal resource bundle
    lib.install ".build/release/GPUTextSearch_SearchEngine.bundle"
    
    # Install documentation  
    doc.install "README.md"
    doc.install "LICENSE"
  end

  test do
    # Create test file with various patterns
    test_content = <<~TEST
      Hello World! This is a GPU Text Search test.
      GATTACA is a famous DNA sequence from the movie.
      ATCGATCGATCG repeating DNA patterns for testing.
      Unicode test: 🧬 DNA sequencing with émojis.
      Performance test with multiple GATTACA sequences.
      Another GATTACA sequence for pattern matching.
    TEST
    (testpath/"test.txt").write test_content
    
    # Test basic pattern search
    output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'GPU' --quiet")
    assert_equal "1", output.strip
    
    # Test DNA sequence matching (bioinformatics use case)
    gattaca_output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'GATTACA' --quiet")
    assert_equal "3", gattaca_output.strip
    
    # Test case sensitivity
    case_output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'hello' --quiet")
    assert_equal "0", case_output.strip
    
    # Test help command functionality
    help_output = shell_output("#{bin}/gpu-text-search --help")
    assert_match "High-performance GPU-accelerated text search tool", help_output
    
    # Test verbose output includes performance metrics
    verbose_output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'test' --verbose")
    assert_match "Search Results", verbose_output
    assert_match "matches found", verbose_output
    
    # Test no matches scenario
    no_match_output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'NOTFOUND' --quiet")
    assert_equal "0", no_match_output.strip
  end
end

class GpuTextSearch < Formula
  desc "Ultra-high-performance GPU-accelerated text search using Metal compute shaders"
  homepage "https://github.com/teenu/gpu-text-search"
  url "https://github.com/teenu/gpu-text-search/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "62ec3ea4126a8daa61c493e7ee34354f7b20dbd67076cc4c55b5784674f169c0"
  license "MIT"
  version "1.0.0"
  head "https://github.com/teenu/gpu-text-search.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on :macos => :ventura

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin.install ".build/release/search-cli" => "gpu-text-search"
    
    # Install the resource bundle in the lib directory where Swift can find it
    lib.install ".build/release/GPUTextSearch_SearchEngine.bundle"
    
    # Install documentation
    doc.install "README.md", "CHANGELOG.md", "LICENSE"
    doc.install "Documentation" if Dir.exist?("Documentation")
    
    # Install examples and validation scripts for testing
    if Dir.exist?("examples")
      (share/"gpu-text-search").install "examples"
    end
    
    # Install test files and validation scripts
    if File.exist?("test_file.txt")
      (share/"gpu-text-search").install "test_file.txt"
    end
    if File.exist?("unicode_test.txt")
      (share/"gpu-text-search").install "unicode_test.txt"
    end
    if File.exist?("quick_test.sh")
      (share/"gpu-text-search").install "quick_test.sh"
    end
    if Dir.exist?("Validation")
      (share/"gpu-text-search").install "Validation"
    end
  end

  test do
    # Create a comprehensive test file with DNA-like sequences
    test_content = <<~TEST
      Hello World! This is a GPU Text Search test.
      GATTACA is a famous DNA sequence from the movie.
      ATCGATCGATCG repeating DNA patterns for testing.
      Unicode test: 🧬 DNA sequencing with émojis.
      Performance test with multiple GATTACA sequences.
      Another GATTACA sequence for pattern matching.
    TEST
    (testpath/"test.txt").write test_content
    
    # Test basic functionality
    output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'GPU' --quiet")
    assert_equal "1", output.strip
    
    # Test GATTACA pattern (should find 3 matches)
    gattaca_output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'GATTACA' --quiet")
    assert_equal "3", gattaca_output.strip
    
    # Test DNA pattern matching
    dna_output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'ATCG' --quiet")
    assert_equal "3", dna_output.strip
    
    # Test help command
    help_output = shell_output("#{bin}/gpu-text-search --help")
    assert_match "High-performance GPU-accelerated text search tool", help_output
    
    # Test verbose output (should include GPU info and performance metrics)
    verbose_output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'test' --verbose")
    assert_match "GPU:", verbose_output
    assert_match "Search Results", verbose_output
    assert_match "Throughput", verbose_output
    
    # Test benchmark functionality 
    benchmark_output = shell_output("#{bin}/gpu-text-search benchmark #{testpath}/test.txt 'DNA' --iterations 5")
    assert_match "Benchmark Results", benchmark_output
    assert_match "Average time", benchmark_output
    
    # Test Unicode support
    unicode_output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt '🧬' --quiet")
    assert_equal "1", unicode_output.strip
    
    # Test that no matches returns 0
    no_match_output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'NOTFOUND' --quiet")
    assert_equal "0", no_match_output.strip
  end
end

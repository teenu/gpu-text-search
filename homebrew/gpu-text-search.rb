class GpuTextSearch < Formula
  desc "Ultra-high-performance GPU-accelerated text search using Metal compute shaders"
  homepage "https://github.com/yourusername/gpu-text-search"
  url "https://github.com/yourusername/gpu-text-search/archive/refs/tags/v2.1.0.tar.gz"
  sha256 "dc9d7183db6872ec6a4f085b238e92021d6c4b57c494c0015cdc25b4cb425ee1"
  license "MIT"
  head "https://github.com/yourusername/gpu-text-search.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on :macos => :ventura

  def install
    system "swift", "build", "--disable-sandbox", "-c", "release"
    bin.install ".build/release/search-cli" => "gpu-text-search"
    
    # Install documentation
    doc.install "README.md", "CHANGELOG.md", "LICENSE"
    doc.install "Documentation" if Dir.exist?("Documentation")
    
    # Install examples and validation scripts
    share.install "quick_test.sh" if File.exist?("quick_test.sh")
    share.install "test_file.txt" if File.exist?("test_file.txt")
  end

  test do
    # Create a test file
    (testpath/"test.txt").write "Hello World! This is a GPU Text Search test."
    
    # Test basic functionality
    output = shell_output("#{bin}/gpu-text-search test.txt 'GPU' --quiet")
    assert_equal "1", output.strip
    
    # Test help command
    assert_match "High-performance GPU-accelerated text search tool", 
                 shell_output("#{bin}/gpu-text-search --help")
    
    # Test verbose output (should include GPU info)
    verbose_output = shell_output("#{bin}/gpu-text-search test.txt 'test' --verbose")
    assert_match "GPU:", verbose_output
    assert_match "Search Results", verbose_output
  end
end\n

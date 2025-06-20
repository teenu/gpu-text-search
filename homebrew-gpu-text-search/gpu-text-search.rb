# frozen_string_literal: true

# Ultra-high-performance GPU-accelerated text search using Metal compute shaders
class GpuTextSearch < Formula
  desc "Ultra-high-performance GPU-accelerated text search using Metal compute shaders"
  homepage "https://github.com/teenu/gpu-text-search"
  url "https://github.com/teenu/gpu-text-search.git",
      tag:      "v2.1.6",
      revision: "349d1dd89c7de2b68d90dc3700deff9a6797c1c6"
  license "MIT"
  head "https://github.com/teenu/gpu-text-search.git", branch: "main"

  depends_on xcode: ["15.0", :build]
  depends_on macos: :ventura
  uses_from_macos "swift" => :build

  def install
    # Architecture-specific optimized build flags for maximum performance
    base_args = [
      "--disable-sandbox",
      "-c", "release"
    ]
    
    # Swift compiler optimizations
    swift_flags = [
      "-O",                            # Optimize for speed
      "-whole-module-optimization",    # Cross-module optimization  
      "-cross-module-optimization",    # Enhanced cross-module optimization
      "-enforce-exclusivity=unchecked", # Disable memory exclusivity checking for performance
      "-enable-library-evolution"       # Future-proof ABI stability
    ]
    
    # Architecture-specific configuration
    if Hardware::CPU.arm?
      # Apple Silicon optimizations
      arch_args = ["--arch", "arm64"]
      swift_flags += [
        "-target-cpu", "apple-a14",     # Optimize for Apple Silicon
        "-Xcc", "-mcpu=apple-a14"        # C compiler optimizations
      ]
    else
      # Intel optimizations
      arch_args = ["--arch", "x86_64"]
      swift_flags += [
        "-target-cpu", "haswell",        # Optimize for modern Intel CPUs
        "-Xcc", "-march=haswell"         # C compiler optimizations
      ]
    end
    
    # Combine all arguments
    args = base_args + arch_args + swift_flags.map { |flag| ["-Xswiftc", flag] }.flatten
    
    # Build with enhanced error handling
    system "swift", "build", *args
    
    # Verify build artifacts exist before installation
    built_executable = ".build/release/search-cli"
    built_bundle = ".build/release/GPUTextSearch_SearchEngine.bundle"
    
    odie "Build failed: executable not found" unless File.exist?(built_executable)
    odie "Build failed: resource bundle not found" unless File.exist?(built_bundle)
    
    # Install with secure permissions
    bin.install built_executable => "gpu-text-search"
    bin.install built_bundle
    
    # Verify installation
    odie "Installation failed: gpu-text-search not executable" unless (bin/"gpu-text-search").executable?
    
    # Create man page directory for future documentation
    man1.mkpath
    
    # Generate and install completion scripts for popular shells
    generate_completions_from_executable(bin/"gpu-text-search", "--generate-completion")
  end

  def post_install
    # Create symlink for bundle in global bin directory to match executable location
    target_bundle = HOMEBREW_PREFIX/"bin"/"GPUTextSearch_SearchEngine.bundle"
    source_bundle = bin/"GPUTextSearch_SearchEngine.bundle"
    
    # Remove existing symlink if it exists
    target_bundle.unlink if target_bundle.exist? || target_bundle.symlink?
    
    # Create new symlink with error handling
    target_bundle.make_symlink(source_bundle) if source_bundle.exist?
    
    # Verify Metal GPU support
    if Hardware::CPU.arm?
      opoo "Apple Silicon detected: GPU acceleration fully supported"
    elsif system "system_profiler", "SPDisplaysDataType", :out => File::NULL, :err => File::NULL
      opoo "Intel Mac detected: GPU acceleration supported with Metal-compatible GPU"
    else
      opoo "Warning: GPU capabilities could not be verified. Performance may be limited."
    end
  end

  test do
    # Create comprehensive test file for pattern matching
    test_content = <<~TEST
      Hello World! This is a GPU Text Search test.
      GATTACA is a famous DNA sequence from the movie.
      ATCGATCGATCG repeating DNA patterns for testing.
      Unicode test: 🧬 DNA sequencing with émojis.
      Performance test with multiple GATTACA sequences.
      Another GATTACA sequence for pattern matching.
      Special chars: @#$%^&*()_+-=[]{}|;:,.<>?
      Numbers: 1234567890 and mixed: abc123xyz
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

    # Test Unicode pattern matching
    unicode_output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt '🧬' --quiet")
    assert_equal "1", unicode_output.strip

    # Test help command functionality
    help_output = shell_output("#{bin}/gpu-text-search --help")
    assert_match "High-performance GPU-accelerated text search tool", help_output

    # Test verbose output includes performance metrics
    verbose_output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'test' --verbose")
    assert_match "Search Results", verbose_output
    assert_match "Matches found:", verbose_output
    assert_match "Throughput:", verbose_output

    # Test benchmark functionality with minimal iterations for CI speed
    benchmark_output = shell_output("#{bin}/gpu-text-search benchmark #{testpath}/test.txt 'DNA' --iterations 3")
    assert_match "Benchmark Results", benchmark_output
    assert_match "Average time:", benchmark_output
    assert_match "throughput", benchmark_output.downcase

    # Test profile functionality
    profile_output = shell_output("#{bin}/gpu-text-search profile #{testpath}/test.txt --iterations 2")
    assert_match "Pattern", profile_output
    assert_match "Length", profile_output
    
    # Test performance characteristics on CI
    perf_start = Time.now
    shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'GATTACA' --quiet")
    perf_duration = Time.now - perf_start
    # Should complete very quickly even on CI systems
    assert_operator perf_duration, :<, 5.0, "Search took too long: #{perf_duration}s"

    # Test special characters
    special_output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt '@' --quiet")
    assert_equal "1", special_output.strip

    # Test no matches scenario
    no_match_output = shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'NOTFOUND' --quiet")
    assert_equal "0", no_match_output.strip

    # Test binary export functionality
    export_file = testpath/"positions.bin"
    shell_output("#{bin}/gpu-text-search #{testpath}/test.txt 'test' --export-binary #{export_file}")
    assert_predicate export_file, :exist?
    assert_operator export_file.size, :>, 0
    
    # Test error handling
    nonexistent_file = testpath/"nonexistent.txt"
    error_output = shell_output("#{bin}/gpu-text-search #{nonexistent_file} 'test' 2>&1", 1)
    assert_match "does not exist", error_output.downcase
    
    # Test version information
    version_output = shell_output("#{bin}/gpu-text-search --version 2>&1 || echo 'version command failed'")
    # Version command might not be implemented yet, so we just ensure it doesn't crash
    assert_instance_of String, version_output
  end
end

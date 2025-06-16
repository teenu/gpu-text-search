# GPU Text Search Examples

This directory contains practical examples showing how to use GPU Text Search for various use cases.

## 🧬 **Bioinformatics Examples**

### Genome Analysis
```bash
# Find all occurrences of GATTACA sequence
gpu-text-search genome.fasta "GATTACA" --verbose

# Profile multiple genetic patterns
gpu-text-search sequences.fasta --profile --patterns "ATCG,GCTA,TAGA,CAGT"

# Export match positions for downstream analysis
gpu-text-search large_genome.fasta "GATTACA" --export-binary gattaca_positions.bin

# Benchmark performance on different sequence patterns
gpu-text-search genome.fasta "ATCGN" --benchmark --iterations 50
```

### Primer Design Workflow
```bash
# Search for primer sequences across multiple files
for primer in "ATCGCTAG" "GCTATCGA" "TAGCATGC"; do
    echo "Testing primer: $primer"
    gpu-text-search target_sequences.fasta "$primer" --quiet
done

# Find optimal primers with performance analysis
gpu-text-search sequences.fasta --profile --patterns "$(cat primer_candidates.txt)"
```

## 🤖 **AI/ML Data Processing**

### RAG Document Preprocessing
```bash
# Find all mentions of AI concepts in research corpus
gpu-text-search research_papers.txt "neural network" --export-binary neural_mentions.bin

# Profile entity extraction performance
gpu-text-search large_corpus.txt --profile --patterns "transformer,attention,bert,gpt"

# Batch process multiple documents
find documents/ -name "*.txt" -exec gpu-text-search {} "artificial intelligence" --quiet \;
```

### Training Data Preparation
```bash
# Extract specific patterns for training data
gpu-text-search training_corpus.txt "machine learning" --verbose --limit 10000

# Performance analysis for different model terms
gpu-text-search papers.txt --benchmark --iterations 20 "deep learning"
```

## 📊 **Data Science & Analytics**

### Log Analysis
```bash
# Find all error patterns in large log files
gpu-text-search server.log "ERROR" --warmup --verbose

# Profile different error types
gpu-text-search application.log --profile --patterns "ERROR,WARN,FATAL,EXCEPTION"

# Export error positions for timeline analysis
gpu-text-search system.log "ERROR" --export-binary error_timeline.bin
```

### Text Mining
```bash
# Search for specific terms in document collections
gpu-text-search documents.txt "climate change" --benchmark --iterations 10

# Batch analysis of multiple patterns
cat patterns.txt | while read pattern; do
    echo "Searching for: $pattern"
    gpu-text-search corpus.txt "$pattern" --quiet
done
```

## 🛠 **Development & DevOps**

### Code Analysis
```bash
# Find function calls across codebase
gpu-text-search source_code.txt "function_name(" --verbose

# Search for security patterns
gpu-text-search code_dump.txt --profile --patterns "password,secret,api_key,token"
```

### Performance Monitoring
```bash
# Monitor search performance over time
date=$(date +%Y%m%d_%H%M%S)
gpu-text-search large_file.txt "pattern" --benchmark --iterations 100 --csv > "benchmark_$date.csv"
```

## 🔬 **Research Applications**

### Literature Analysis
```bash
# Search academic papers for methodology terms
gpu-text-search papers.txt --profile --patterns "methodology,analysis,results,conclusion"

# Find citations and references
gpu-text-search academic_corpus.txt --benchmark "et al" --iterations 25
```

### Data Validation
```bash
# Cross-validate results with traditional tools
echo "GPU Text Search:"
time gpu-text-search large_file.txt "pattern" --quiet

echo "grep comparison:"
time grep -c "pattern" large_file.txt
```

## 📈 **Performance Examples**

### Benchmarking Scripts
```bash
#!/bin/bash
# Comprehensive performance test

echo "GPU Text Search Performance Analysis"
echo "===================================="

patterns=("error" "success" "warning" "info" "debug")
file="large_dataset.txt"

for pattern in "${patterns[@]}"; do
    echo "Testing pattern: $pattern"
    gpu-text-search "$file" "$pattern" --benchmark --iterations 10 --csv >> results.csv
done

echo "Results saved to results.csv"
```

### Hardware Comparison
```bash
# Test on different Apple Silicon models
system_profiler SPHardwareDataType | grep "Model Name"
gpu-text-search test_file.txt "benchmark" --verbose --warmup
```

## 🚀 **Integration Examples**

### Python Integration
```python
import subprocess
import json

def gpu_search(file_path, pattern):
    """Wrapper for GPU Text Search"""
    result = subprocess.run([
        'gpu-text-search', file_path, pattern, '--quiet'
    ], capture_output=True, text=True)
    
    return int(result.stdout.strip()) if result.stdout.strip() else 0

# Usage
matches = gpu_search('data.txt', 'target_pattern')
print(f"Found {matches} matches")
```

### Shell Script Automation
```bash
#!/bin/bash
# Automated analysis pipeline

INPUT_FILE="$1"
PATTERNS_FILE="$2"
OUTPUT_DIR="results"

mkdir -p "$OUTPUT_DIR"

while IFS= read -r pattern; do
    echo "Processing pattern: $pattern"
    
    # Search and export results
    gpu-text-search "$INPUT_FILE" "$pattern" \
        --export-binary "$OUTPUT_DIR/${pattern//[^a-zA-Z0-9]/_}.bin"
    
    # Get performance metrics
    gpu-text-search "$INPUT_FILE" "$pattern" \
        --benchmark --iterations 5 --csv >> "$OUTPUT_DIR/performance.csv"
        
done < "$PATTERNS_FILE"

echo "Analysis complete. Results in $OUTPUT_DIR/"
```

## 📋 **Best Practices**

### For Large Files (>1GB)
```bash
# Use warmup for consistent performance
gpu-text-search large_file.txt "pattern" --warmup --verbose

# Monitor memory usage
top -pid $(pgrep gpu-text-search) -l 1
```

### For Batch Processing
```bash
# Process multiple files efficiently
find . -name "*.txt" -print0 | \
    xargs -0 -I {} gpu-text-search {} "pattern" --quiet
```

### For High-Precision Timing
```bash
# Use benchmark mode for accurate measurements
gpu-text-search file.txt "pattern" --benchmark --iterations 100 --csv
```

## 🎯 **Use Case Templates**

Copy and modify these templates for your specific needs:

- **bioinformatics_template.sh**: Genome analysis workflow
- **ml_preprocessing.py**: AI/ML data preparation
- **log_analysis.sh**: System log monitoring
- **performance_test.sh**: Comprehensive benchmarking

Each template includes:
- Setup instructions
- Sample data preparation
- Command examples
- Results interpretation
- Performance optimization tips

## 💡 **Tips for Optimization**

1. **Use `--warmup`** for large files to get peak performance
2. **Profile multiple patterns** with `--profile` for efficiency
3. **Export binary results** for downstream processing
4. **Benchmark changes** to measure performance impact
5. **Monitor GPU usage** during intensive operations

## 🤝 **Contributing Examples**

Have a great use case? Share it:

1. Create a new example file
2. Include clear documentation
3. Add sample data (if possible)
4. Submit a pull request

See [CONTRIBUTING.md](../.github/CONTRIBUTING.md) for guidelines.

---

**Need help with your specific use case?** Open an issue and we'll help you optimize your workflow! 🚀
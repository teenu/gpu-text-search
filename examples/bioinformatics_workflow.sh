#!/bin/bash

# GPU Text Search - Bioinformatics Workflow Example
# ================================================
# 
# This script demonstrates how to use GPU Text Search for common
# bioinformatics tasks including genome analysis and primer design.
#
# Usage: ./bioinformatics_workflow.sh <input_file.fasta>

set -e

INPUT_FILE="$1"
OUTPUT_DIR="bioinformatics_results"
DATE=$(date +%Y%m%d_%H%M%S)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Check if input file is provided
if [ -z "$INPUT_FILE" ]; then
    error "Usage: $0 <input_file.fasta>"
fi

# Check if input file exists
if [ ! -f "$INPUT_FILE" ]; then
    error "Input file not found: $INPUT_FILE"
fi

# Check if GPU Text Search is available
if ! command -v gpu-text-search &> /dev/null; then
    error "gpu-text-search not found. Please install it first."
fi

log "Starting bioinformatics analysis workflow"
log "Input file: $INPUT_FILE"
log "Output directory: $OUTPUT_DIR"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# File information
FILE_SIZE=$(du -h "$INPUT_FILE" | cut -f1)
log "Analyzing file of size: $FILE_SIZE"

echo ""
echo "🧬 BIOINFORMATICS ANALYSIS WORKFLOW"
echo "=================================="

# 1. Common genetic sequences analysis
log "Step 1: Analyzing common genetic sequences..."

# Define common patterns to search for
GENETIC_PATTERNS=(
    "GATTACA"     # Famous sequence from the movie
    "ATCG"        # Basic nucleotides
    "GCTA"        # Reverse complement
    "TATA"        # TATA box
    "CAAT"        # CAAT box
    "GGCCGG"      # GC box
    "AATAAA"      # Polyadenylation signal
)

# Create patterns file
echo "Creating genetic patterns file..."
printf '%s\n' "${GENETIC_PATTERNS[@]}" > "$OUTPUT_DIR/genetic_patterns.txt"

# Profile all patterns at once for efficiency
log "Running pattern profile analysis..."
gpu-text-search "$INPUT_FILE" --profile \
    --patterns "$(IFS=,; echo "${GENETIC_PATTERNS[*]}")" \
    --iterations 10 \
    --verbose > "$OUTPUT_DIR/genetic_profile_${DATE}.txt"

success "Genetic profile analysis complete"

# 2. Individual sequence analysis with detailed results
log "Step 2: Detailed analysis of key sequences..."

for pattern in "${GENETIC_PATTERNS[@]}"; do
    log "Analyzing pattern: $pattern"
    
    # Get match count
    match_count=$(gpu-text-search "$INPUT_FILE" "$pattern" --quiet)
    echo "  Found $match_count matches for $pattern"
    
    # Export positions for further analysis
    if [ "$match_count" -gt 0 ]; then
        gpu-text-search "$INPUT_FILE" "$pattern" \
            --export-binary "$OUTPUT_DIR/${pattern}_positions_${DATE}.bin"
        
        # Get detailed results with positions (limited to first 100)
        gpu-text-search "$INPUT_FILE" "$pattern" \
            --verbose --limit 100 > "$OUTPUT_DIR/${pattern}_detailed_${DATE}.txt"
    fi
done

success "Individual sequence analysis complete"

# 3. Performance benchmarking
log "Step 3: Performance benchmarking..."

# Benchmark the most common pattern
BENCHMARK_PATTERN="ATCG"
log "Benchmarking pattern: $BENCHMARK_PATTERN"

gpu-text-search "$INPUT_FILE" "$BENCHMARK_PATTERN" \
    --benchmark --iterations 20 \
    --csv > "$OUTPUT_DIR/performance_benchmark_${DATE}.csv"

# Get verbose benchmark for the report
gpu-text-search "$INPUT_FILE" "$BENCHMARK_PATTERN" \
    --benchmark --iterations 5 \
    --verbose > "$OUTPUT_DIR/performance_report_${DATE}.txt"

success "Performance benchmarking complete"

# 4. Primer design simulation
log "Step 4: Primer design analysis..."

# Define potential primer sequences (example)
PRIMER_CANDIDATES=(
    "ATCGCTAG"
    "GCTATCGA"
    "TAGCATGC"
    "CGATCGAT"
    "AATTGGCC"
)

echo "Analyzing primer candidates..."
echo "Primer,Matches,Suitable" > "$OUTPUT_DIR/primer_analysis_${DATE}.csv"

for primer in "${PRIMER_CANDIDATES[@]}"; do
    matches=$(gpu-text-search "$INPUT_FILE" "$primer" --quiet)
    
    # Simple suitability check (primers should be relatively rare)
    if [ "$matches" -lt 100 ] && [ "$matches" -gt 0 ]; then
        suitable="Yes"
    else
        suitable="No"
    fi
    
    echo "$primer,$matches,$suitable" >> "$OUTPUT_DIR/primer_analysis_${DATE}.csv"
    log "Primer $primer: $matches matches ($suitable)"
done

success "Primer design analysis complete"

# 5. Generate summary report
log "Step 5: Generating summary report..."

REPORT_FILE="$OUTPUT_DIR/analysis_summary_${DATE}.txt"

cat > "$REPORT_FILE" << EOF
BIOINFORMATICS ANALYSIS SUMMARY
==============================

Analysis Date: $(date)
Input File: $INPUT_FILE
File Size: $FILE_SIZE
Output Directory: $OUTPUT_DIR

GENETIC PATTERN ANALYSIS:
$(cat "$OUTPUT_DIR/genetic_patterns.txt" | while read pattern; do
    count=$(gpu-text-search "$INPUT_FILE" "$pattern" --quiet 2>/dev/null || echo "0")
    printf "  %-10s: %s matches\n" "$pattern" "$count"
done)

PRIMER CANDIDATES:
$(tail -n +2 "$OUTPUT_DIR/primer_analysis_${DATE}.csv" | while IFS=, read primer matches suitable; do
    printf "  %-10s: %s matches (%s)\n" "$primer" "$matches" "$suitable"
done)

PERFORMANCE:
$(tail -n 1 "$OUTPUT_DIR/performance_report_${DATE}.txt" | grep -o "Average.*")

FILES GENERATED:
- Genetic profile: genetic_profile_${DATE}.txt
- Performance benchmark: performance_benchmark_${DATE}.csv
- Primer analysis: primer_analysis_${DATE}.csv
- Individual pattern results: *_detailed_${DATE}.txt
- Binary position data: *_positions_${DATE}.bin

NEXT STEPS:
1. Review detailed results in individual pattern files
2. Use binary position data for downstream analysis
3. Validate primer candidates with additional criteria
4. Compare performance across different file sizes

EOF

success "Summary report generated: $REPORT_FILE"

# 6. Validation against traditional tools (if available)
if command -v grep &> /dev/null; then
    log "Step 6: Validating results against grep..."
    
    VALIDATION_PATTERN="ATCG"
    
    log "GPU Text Search result:"
    gpu_result=$(gpu-text-search "$INPUT_FILE" "$VALIDATION_PATTERN" --quiet)
    
    log "grep result:"
    grep_result=$(grep -o "$VALIDATION_PATTERN" "$INPUT_FILE" | wc -l | tr -d ' ')
    
    if [ "$gpu_result" -eq "$grep_result" ]; then
        success "Validation passed: Both tools found $gpu_result matches"
    else
        warning "Validation mismatch: GPU($gpu_result) vs grep($grep_result)"
    fi
    
    # Performance comparison
    log "Performance comparison:"
    echo "GPU Text Search:"
    time gpu-text-search "$INPUT_FILE" "$VALIDATION_PATTERN" --quiet
    
    echo "grep:"
    time grep -c "$VALIDATION_PATTERN" "$INPUT_FILE"
else
    warning "grep not available for validation"
fi

echo ""
echo "🎉 ANALYSIS COMPLETE!"
echo "===================="
echo ""
echo "Results saved in: $OUTPUT_DIR/"
echo "Summary report: $REPORT_FILE"
echo ""
echo "To review results:"
echo "  cat $REPORT_FILE"
echo ""
echo "To analyze binary position data:"
echo "  python3 -c \""
echo "import struct"
echo "with open('$OUTPUT_DIR/GATTACA_positions_${DATE}.bin', 'rb') as f:"
echo "    positions = [struct.unpack('<I', f.read(4))[0] for _ in range(10)]"
echo "    print('First 10 GATTACA positions:', positions)"
echo "\""

log "Workflow completed successfully! 🚀"\n

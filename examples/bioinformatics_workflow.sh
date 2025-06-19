#!/bin/bash
# GPU Text Search - Bioinformatics Example
# Demonstrates genome pattern analysis and primer design

set -e

INPUT_FILE="$1"
OUTPUT_DIR="bioinformatics_results"

# Validation
[ -z "$INPUT_FILE" ] && { echo "Usage: $0 <input_file.fasta>"; exit 1; }
[ ! -f "$INPUT_FILE" ] && { echo "File not found: $INPUT_FILE"; exit 1; }
# Try to find search-cli binary
if command -v search-cli &> /dev/null; then
    SEARCH_CLI="search-cli"
elif [ -f ".build/release/search-cli" ]; then
    SEARCH_CLI=".build/release/search-cli"
else
    echo "search-cli not found. Please build with 'swift build -c release' or install globally"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "🧬 Bioinformatics Analysis: $(du -h "$INPUT_FILE" | cut -f1)"

# 1. Common genetic pattern analysis
PATTERNS=("GATTACA" "ATCG" "TATA" "CAAT" "GGCCGG")
echo "Analyzing genetic patterns..."

for pattern in "${PATTERNS[@]}"; do
    count=$($SEARCH_CLI search "$INPUT_FILE" "$pattern" --quiet)
    echo "  $pattern: $count matches"
    [ "$count" -gt 0 ] && $SEARCH_CLI search "$INPUT_FILE" "$pattern" --export-binary "$OUTPUT_DIR/${pattern}_positions.bin"
done

# 2. Performance benchmark
echo "Benchmarking performance..."
$SEARCH_CLI benchmark "$INPUT_FILE" "ATCG" --iterations 10 --csv > "$OUTPUT_DIR/benchmark.csv"

# 3. Primer analysis
echo "Analyzing primer candidates..."
PRIMERS=("ATCGCTAG" "GCTATCGA" "TAGCATGC")
echo "Primer,Matches,Suitable" > "$OUTPUT_DIR/primers.csv"

for primer in "${PRIMERS[@]}"; do
    matches=$($SEARCH_CLI search "$INPUT_FILE" "$primer" --quiet)
    suitable=$( [ "$matches" -gt 0 ] && [ "$matches" -lt 100 ] && echo "Yes" || echo "No" )
    echo "$primer,$matches,$suitable" >> "$OUTPUT_DIR/primers.csv"
    echo "  $primer: $matches matches ($suitable)"
done

# 4. Validation with grep (if available)
if command -v grep &> /dev/null; then
    echo "Validating with grep..."
    gpu_result=$($SEARCH_CLI search "$INPUT_FILE" "ATCG" --quiet)
    grep_result=$(grep -o "ATCG" "$INPUT_FILE" | wc -l)
    [ "$gpu_result" -eq "$grep_result" ] && echo "✅ Validation passed" || echo "⚠️ Validation mismatch"
fi

echo "✅ Analysis complete! Results in: $OUTPUT_DIR/"\n

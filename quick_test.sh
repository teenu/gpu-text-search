#!/bin/bash

echo "🧪 GPU Text Search - Quick Validation Test"
echo "========================================="

# Build the project
echo "📦 Building project..."
swift build -c release

if [ $? -ne 0 ]; then
    echo "❌ Build failed!"
    exit 1
fi

echo "✅ Build successful!"

# Test basic functionality
echo ""
echo "🔍 Testing basic search functionality..."

# Test 1: Basic search
echo "Test 1: Basic pattern search"
RESULT1=$(.build/release/search-cli search test_file.txt "Hello" --quiet)
if [ "$RESULT1" = "3" ]; then
    echo "✅ Basic search: Found $RESULT1 matches (expected: 3)"
else
    echo "❌ Basic search: Found $RESULT1 matches (expected: 3)"
fi

# Test 2: Unicode search
echo "Test 2: Unicode pattern search"
RESULT2=$(.build/release/search-cli search unicode_test.txt "Hello" --quiet)
if [ "$RESULT2" = "2" ]; then
    echo "✅ Unicode search: Found $RESULT2 matches (expected: 2)"
else
    echo "❌ Unicode search: Found $RESULT2 matches (expected: 2)"
fi

# Test 3: No matches
echo "Test 3: Pattern not found"
RESULT3=$(.build/release/search-cli search test_file.txt "NOTFOUND" --quiet)
if [ "$RESULT3" = "0" ]; then
    echo "✅ No matches: Found $RESULT3 matches (expected: 0)"
else
    echo "❌ No matches: Found $RESULT3 matches (expected: 0)"
fi

# Test 4: Performance test
echo "Test 4: Performance benchmark"
echo "Running 5-iteration benchmark..."
.build/release/search-cli benchmark test_file.txt "the" --iterations 5 --verbose

echo ""
echo "🎉 Quick validation complete!"
echo ""
echo "Next steps:"
echo "  • Run comprehensive tests: python3 Validation/comprehensive_test.py"
echo "  • Profile performance: .build/release/search-cli profile test_file.txt --verbose"
echo "  • Test binary export: .build/release/search-cli search test_file.txt \"Hello\" --export-binary positions.bin"
echo ""
echo "For detailed usage instructions, see: README.md"
echo "For development guidelines, see: CLAUDE.md"

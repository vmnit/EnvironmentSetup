#!/bin/bash

set -e

OUTPUT_FILE="stdout.diff.log"
FILES_WITH_DIFF=0
FILES_IDENTICAL=0
FILES_MISSING=0

# Clear the output file
> "$OUTPUT_FILE"

echo "======================================"
echo "Environment Files Diff Check"
echo "======================================"
echo ""

while read f;
do
    if [[ ! $f =~ ^#.*$ && ! -z $f ]];
    then
        echo -n "Checking $f ... "

        if [[ ! -f ~/$f ]]; then
            echo "MISSING (file doesn't exist in ~/$f)"
            echo "=== MISSING: $f ===" >> "$OUTPUT_FILE"
            echo "" >> "$OUTPUT_FILE"
            FILES_MISSING=$((FILES_MISSING + 1))
        elif diff -q "$f" ~/"$f" > /dev/null 2>&1; then
            echo "identical"
            FILES_IDENTICAL=$((FILES_IDENTICAL + 1))
        else
            echo "DIFFERENCES FOUND"
            echo "=== DIFF: $f vs ~/$f ===" >> "$OUTPUT_FILE"
            diff "$f" ~/"$f" >> "$OUTPUT_FILE" 2>&1 || true
            echo "" >> "$OUTPUT_FILE"
            FILES_WITH_DIFF=$((FILES_WITH_DIFF + 1))
        fi
    fi
done < files.txt

echo ""
echo "======================================"
echo "Summary:"
echo "  Files with differences: $FILES_WITH_DIFF"
echo "  Identical files: $FILES_IDENTICAL"
echo "  Missing files: $FILES_MISSING"
echo ""
if [[ $FILES_WITH_DIFF -gt 0 || $FILES_MISSING -gt 0 ]]; then
    echo "  Detailed diff output saved to: $OUTPUT_FILE"
else
    echo "  All files are identical!"
fi
echo "======================================"

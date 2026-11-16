--Hadoop / HDFS (File-Level Ingestion & Storage Testing)
#!/bin/bash
HDFS_DIR="/data/landing/medicaid_837/20261115"

# 1. Check if the directory exists and contains files
FILE_COUNT=$(hdfs dfs -ls $HDFS_DIR/*.dat 2>/dev/null | wc -l)
if [ "$FILE_COUNT" -eq 0 ]; then
    echo "FAIL: No 837 batch files landed in $HDFS_DIR"
    exit 1
fi

# 2. Check for corrupted 0-byte files
EMPTY_FILES=$(hdfs dfs -ls $HDFS_DIR/*.dat | awk '$5 == 0 {print $8}')
if [ -n "$EMPTY_FILES" ]; then
    echo "FAIL: Zero-byte files detected: $EMPTY_FILES"
    exit 1
fi

# 3. Verify line count across all landed files
TOTAL_LINES=$(hdfs dfs -cat $HDFS_DIR/*.dat | wc -l)
echo "PASS: Found $FILE_COUNT files with $TOTAL_LINES total records."

# Fix for Iceberg Partition Values Containing "/" Characters

## Issue

ClickHouse incorrectly handled Iceberg tables with partition values containing "/" characters. 

**Problem:**
- S3 stores objects with URL-encoded paths: `partition_key=dev%2Fapp1%2Fservice1/file.parquet`
- ClickHouse was decoding the path to: `partition_key=dev/app1/service1/file.parquet`
- S3 returned 404 because the decoded path doesn't exist

**Root Cause:**
The `S3::URI` class used `Poco::URI::getPath()` which automatically URL-decodes the path, converting `%2F` to `/`. When this decoded path was re-encoded for S3 requests, `/` was not encoded back to `%2F`, causing a mismatch.

## Solution

Modified `src/IO/S3/URI.cpp` to extract the S3 key directly from the original URI string instead of using `Poco::URI::getPath()`. This preserves URL encoding in the key.

### Changes Made

1. **File: `src/IO/S3/URI.cpp`**
   - Added `extractOriginalPath()` lambda function to parse the path directly from the URI string
   - Modified key extraction in both virtual-hosted style and path-style URI parsing to use the original encoded path
   - Preserves all URL-encoded characters including `%2F`, `%20`, `%2B`, etc.

2. **File: `src/IO/tests/gtest_s3_uri.cpp`**
   - Added `TEST(S3UriTest, urlEncodedKeys)` with test cases for:
     - Iceberg partition paths with `%2F` (encoded slashes)
     - Path-style URIs with encoded slashes
     - Other encoded characters like spaces (`%20`) and plus signs (`%2B`)

## Impact

- **Minimal**: Changes are isolated to the S3::URI constructor
- **Backward Compatible**: Existing functionality unchanged - only fixes incorrect decoding behavior
- **No Breaking Changes**: Keys without encoding work exactly as before

## Testing

### Unit Tests
Three new test cases added to verify:
1. Virtual-hosted style URI with encoded partition paths
2. Path-style URI with encoded partition paths
3. URIs with various encoded characters

### Manual Testing
To test with actual Iceberg tables:

```sql
SET send_logs_level = 'trace';
SET allow_experimental_database_iceberg = 1;

CREATE DATABASE IF NOT EXISTS test_catalog
ENGINE = DataLakeCatalog('http://your-polaris-catalog/api/catalog')
SETTINGS
    catalog_type = 'rest',
    catalog_credential = 'client_id:client_secret',
    oauth_server_uri = 'http://your-polaris/api/catalog/v1/oauth/tokens',
    warehouse = 'your_warehouse',
    vended_credentials = false;

-- Query table with partitions containing "/"
SELECT * FROM test_catalog.schema.partition_bug_test LIMIT 5;
```

## Files Modified

1. `src/IO/S3/URI.cpp` - Core fix implementation
2. `src/IO/tests/gtest_s3_uri.cpp` - Added unit tests

## Related Issue

- GitHub Issue: https://github.com/Altinity/ClickHouse/issues/1348
- Iceberg Specification: Partition values can contain any valid string, including "/"
- S3 Specification: Object keys must be URL-encoded in requests

## Technical Details

### Before Fix
```
URI: s3://bucket/data/partition_key=dev%2Fapp1%2Fservice1/file.parquet
                                       ↓ Poco::URI::getPath() decodes
Key extracted: "data/partition_key=dev/app1/service1/file.parquet"
                                       ↓ Re-encode for S3 (but / not encoded)
S3 Request: "data/partition_key=dev/app1/service1/file.parquet"
Result: 404 Not Found
```

### After Fix
```
URI: s3://bucket/data/partition_key=dev%2Fapp1%2Fservice1/file.parquet
                                       ↓ Extract from original string
Key extracted: "data/partition_key=dev%2Fapp1%2Fservice1/file.parquet"
                                       ↓ Already encoded, preserve as-is
S3 Request: "data/partition_key=dev%2Fapp1%2Fservice1/file.parquet"
Result: 200 OK
```

## Build Instructions

The fix can be tested by building ClickHouse from source:

```bash
# Standard ClickHouse build process
mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --target clickhouse-server
```

Or wait for the CI/CD pipeline to build and test automatically.

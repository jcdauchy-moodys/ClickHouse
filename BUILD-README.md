# ClickHouse Build Automation Scripts

## Quick Start

### 1. Run the Automated Build

```bash
# In WSL
cd /mnt/c/code/clickhouse-antalya
./build-clickhouse.sh
```

This will:
- Check prerequisites (Docker, Python3)
- Fix Docker configuration if needed
- Start the build process
- Build output: `./ci/tmp/`

### 2. Build Options

```bash
# Default: AMD64 release build
./build-clickhouse.sh

# AMD64 debug build with tests
./build-clickhouse.sh amd_debug

# AMD64 with AddressSanitizer
./build-clickhouse.sh amd_asan

# ARM64 release build
./build-clickhouse.sh arm_release

# Clean previous build and rebuild
./build-clickhouse.sh amd_release --clean
```

## Docker Image Information

### Current Build Image

**Image:** `altinityinfra/binary-builder:ea526917c7dc72be8644_amd`  
**Size:** ~6-8 GB  
**Base:** Ubuntu 22.04 with complete build toolchain

### Copy to Your Registry

Use the provided script:

```bash
# For Docker Hub
./copy-docker-image-to-repo.sh yourusername/clickhouse-builder latest

# For AWS ECR
./copy-docker-image-to-repo.sh 123456.dkr.ecr.us-east-1.amazonaws.com/clickhouse-builder latest

# For Azure ACR
./copy-docker-image-to-repo.sh myregistry.azurecr.io/clickhouse-builder latest
```

### Manual Process

```bash
# 1. Pull the image
docker pull altinityinfra/binary-builder:ea526917c7dc72be8644_amd

# 2. Tag for your registry
docker tag altinityinfra/binary-builder:ea526917c7dc72be8644_amd \
  your-registry.com/clickhouse-builder:latest

# 3. Login to your registry
docker login your-registry.com

# 4. Push
docker push your-registry.com/clickhouse-builder:latest
```

### Update Build Configuration

After pushing to your registry, edit:

**File:** `ci/defs/job_configs.py`  
**Line 48-53:**

Change:
```python
BINARY_DOCKER_COMMAND = (
    "altinityinfra/binary-builder+--network=host+"
```

To:
```python
BINARY_DOCKER_COMMAND = (
    "your-registry.com/clickhouse-builder+--network=host+"
```

## Build from Scratch

### Build Your Own Builder Image

```bash
cd ci/docker/binary-builder

# Build for AMD64
docker build -t your-registry.com/clickhouse-builder:amd .

# Push to registry
docker push your-registry.com/clickhouse-builder:amd
```

**Note:** Building the builder image itself takes ~30-60 minutes as it compiles LLVM and other tools.

## Build Output

After successful build, artifacts are in `./ci/tmp/`:

```
ci/tmp/
├── build/
│   └── programs/
│       ├── clickhouse              # Main binary
│       ├── clickhouse-server       # Server symlink
│       ├── clickhouse-client       # Client symlink
│       └── clickhouse-local        # Local tool
├── packages/                       # DEB/RPM packages (if generated)
└── ...
```

## Build Time Estimates

- **Full build (release):** 1-2 hours
- **Debug build:** 1.5-2.5 hours
- **Incremental rebuild:** 5-30 minutes (depends on changes)

## System Requirements

- **CPU:** 4+ cores recommended (8+ ideal)
- **RAM:** 16GB minimum, 32GB+ recommended
- **Disk:** 50GB+ free space
- **Docker:** Version 20.10+
- **WSL2** (for Windows users)

## Troubleshooting

### Docker Credential Issues

If you see `docker-credential-desktop.exe` errors:

```bash
echo '{"auths": {}}' > ~/.docker/config.json
```

Or run the build script which fixes this automatically.

### Out of Memory

Reduce parallel jobs by modifying CMake flags in `ci/jobs/build_clickhouse.py`:

```python
# Find the ninja build command and add:
"-j4"  # Limit to 4 parallel jobs
```

### Slow Build on WSL

- Ensure files are on WSL filesystem (`/home/...`) not Windows mount (`/mnt/c/...`)
- Or enable WSL2 with proper memory allocation in `.wslconfig`

### Build Failed with Exit Code

Check the full log:
```bash
tail -500 ~/.cursor/projects/c-code-clickhouse-antalya/terminals/[latest-id].txt
```

## Advanced Usage

### Custom CMake Options

Edit `ci/jobs/build_clickhouse.py` and modify the `BUILD_TYPE_TO_CMAKE` dictionary.

### Cross-compilation

```bash
# ARM64 on AMD64
./build-clickhouse.sh arm_release

# Darwin (macOS) from Linux
./build-clickhouse.sh amd_darwin
./build-clickhouse.sh arm_darwin
```

### Package Building

Release builds automatically create packages in `ci/tmp/packages/`:
- `.deb` files for Debian/Ubuntu
- `.rpm` files for RHEL/CentOS
- `.tgz` archives

## Files Created

- `build-clickhouse.sh` - Main build automation script
- `copy-docker-image-to-repo.sh` - Docker image copy utility
- `docker-image-info.md` - Detailed Docker image documentation
- `BUILD-README.md` - This file

## Support

For build issues:
1. Check the build log in `terminals/` folder
2. Verify Docker is running: `docker ps`
3. Check disk space: `df -h`
4. Review ClickHouse build documentation: https://clickhouse.com/docs/en/development/build

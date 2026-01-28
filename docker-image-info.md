# ClickHouse Build Docker Image Information

## Current Build Image

The ClickHouse build system uses the following Docker image:

**Image Name:** `altinityinfra/binary-builder`  
**Current Tag:** `ea526917c7dc72be8644_amd`  
**Architecture:** AMD64/x86_64

This image contains all the build dependencies needed to compile ClickHouse:
- CMake
- Clang/LLVM compiler toolchain
- Build tools (make, ninja, etc.)
- All required libraries and headers
- sccache for faster compilation

## Image Size

Approximately **6-8 GB** (compressed layers)

## How to Pull and Tag for Your Own Repository

### 1. Pull the Current Image

```bash
docker pull altinityinfra/binary-builder:ea526917c7dc72be8644_amd
```

### 2. Tag for Your Repository

Replace `your-registry` and `your-repo` with your Docker registry information:

```bash
# For Docker Hub
docker tag altinityinfra/binary-builder:ea526917c7dc72be8644_amd \
  your-dockerhub-username/clickhouse-builder:latest

# For AWS ECR
docker tag altinityinfra/binary-builder:ea526917c7dc72be8644_amd \
  123456789.dkr.ecr.us-east-1.amazonaws.com/clickhouse-builder:latest

# For Azure ACR
docker tag altinityinfra/binary-builder:ea526917c7dc72be8644_amd \
  yourregistry.azurecr.io/clickhouse-builder:latest

# For Google GCR
docker tag altinityinfra/binary-builder:ea526917c7dc72be8644_amd \
  gcr.io/your-project/clickhouse-builder:latest

# For private Harbor/GitLab registry
docker tag altinityinfra/binary-builder:ea526917c7dc72be8644_amd \
  your-registry.com/clickhouse/builder:latest
```

### 3. Push to Your Repository

```bash
# Docker Hub (login first: docker login)
docker push your-dockerhub-username/clickhouse-builder:latest

# AWS ECR (authenticate first)
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin 123456789.dkr.ecr.us-east-1.amazonaws.com
docker push 123456789.dkr.ecr.us-east-1.amazonaws.com/clickhouse-builder:latest

# Azure ACR
az acr login --name yourregistry
docker push yourregistry.azurecr.io/clickhouse-builder:latest

# Google GCR
gcloud auth configure-docker
docker push gcr.io/your-project/clickhouse-builder:latest

# Harbor/GitLab (login first)
docker login your-registry.com
docker push your-registry.com/clickhouse/builder:latest
```

## Modifying the Build Script to Use Your Image

After pushing to your registry, update the Docker image reference in:

**File:** `ci/defs/job_configs.py`

**Line ~48-53:**
```python
BINARY_DOCKER_COMMAND = (
    "altinityinfra/binary-builder+--network=host+"
    f"--memory={Utils.physical_memory() * 95 // 100}+"
    f"--memory-reservation={Utils.physical_memory() * 9 // 10}"
    '+--env=AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID"+--env=AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY"'
)
```

Change `altinityinfra/binary-builder` to your registry path:
```python
BINARY_DOCKER_COMMAND = (
    "your-registry.com/clickhouse/builder+--network=host+"
    # ... rest remains the same
)
```

## Alternative: Build Your Own Builder Image

If you want to create your own build image from scratch:

**Dockerfile location:** `ci/docker/binary-builder/Dockerfile`

```bash
cd ci/docker/binary-builder
docker build -t your-registry.com/clickhouse-builder:custom .
docker push your-registry.com/clickhouse-builder:custom
```

## Image Variants

The repository supports multiple architecture variants:

- `*_amd` - AMD64/x86_64 (Intel/AMD processors)
- `*_arm` - ARM64/aarch64 (Apple Silicon, Graviton, etc.)

The tag format includes a content digest hash to ensure reproducibility.

## Notes

- The image digest changes when dependencies are updated
- Each CI run may use a slightly different tag based on the Dockerfile content
- For production builds, consider pinning to a specific digest
- The image is based on Ubuntu 22.04 with all ClickHouse build dependencies pre-installed

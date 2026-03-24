# Airgap-Bundler

Helper script for loading and distributing Juno Innovations setup to non-internet enabled machines.

## What It Does

Airgap-Bundler packages Docker images and Git repositories into a tar.gz archive that can be transferred to air-gapped (offline) machines. On the target machine, the included `load.sh` script restores the Docker images and starts the services via docker-compose.

### Features

- **Docker Images**: Pulls and saves Docker images as tar files
- **Git Repositories**: Clones repositories as bare repositories for serving via git server
- **Automated Setup**: Generates docker-compose.yaml and load.sh scripts
- **Portable Bundle**: Creates a single tar.gz archive for easy transfer

## Prerequisites

- Docker must be installed and running
- Git must be available
- Network access to pull the defined Docker images and clone repositories

## Quick Start

```bash
# Build the bundle
./build-bundle.sh

# Or use make
make build
```

This creates `airgap-bundle-YYYYMMDDHHMMSS.tar.gz` in the current directory.

## Usage on Target Machine

1. Extract the bundle:
   ```bash
   tar -xzf airgap-bundle-YYYYMMDDHHMMSS.tar.gz
   cd airgap-bundle-YYYYMMDDHHMMSS
   ```

2. Run the load script:
   ```bash
   ./load.sh
   ```

3. Services will be available at:
   - Git Server: http://localhost:8080/
   - Docker Registry: http://localhost:5000

## Transferring to Target Machine

### Using rsync

Rsync is ideal for transferring the bundle as it supports resuming and is efficient:

```bash
# Rsync the bundle to a remote target machine
rsync -avz --progress airgap-bundle-YYYYMMDDHHMMSS.tar.gz user@target-machine:/path/to/destination/

# Or transfer the extracted directory
rsync -avz --progress airgap-bundle-YYYYMMDDHHMMSS/ user@target-machine:/path/to/destination/
```

### Using SCP

```bash
scp airgap-bundle-YYYYMMDDHHMMSS.tar.gz user@target-machine:/path/to/destination/
```

### Using USB Drive

```bash
# Copy to USB drive (assuming /mnt/usb is mounted)
cp airgap-bundle-YYYYMMDDHHMMSS.tar.gz /mnt/usb/

# On target machine, mount USB and copy
cp /mnt/usb/airgap-bundle-YYYYMMDDHHMMSS.tar.gz /path/to/destination/
```

## Working with Git Repositories

The git server serves repositories from the `/git/` path.

### Cloning a Repository

```bash
# Clone from the local git server
git clone http://localhost:8080/git/Orion-Deployment.git

# Clone to a specific directory
git clone http://localhost:8080/git/Orion-Deployment.git my-project
```

## Working with Docker Registry

The local Docker registry allows you to push and pull images without internet access.

### Listing Images in Registry

```bash
# List available repositories
curl http://localhost:5000/v2/_catalog

# List tags for a specific image
curl http://localhost:5000/v2/<image-name>/tags/list
```

### Pulling an Image from Registry

```bash
# Tag an existing image for the local registry
docker tag myimage:latest localhost:5000/myimage:latest

# Push to local registry
docker push localhost:5000/myimage:latest

# Pull from local registry (on any machine that can reach the registry)
docker pull localhost:5000/myimage:latest
```

### Loading Images from Bundle

The bundle includes pre-saved Docker images in the `docker/` directory. These are automatically loaded when running `./load.sh`. To manually load a specific image:

```bash
docker load -i docker/aliolozy-tinygit-latest.tar
```

## Configuration

Edit the arrays at the top of `build-bundle.sh` to customize:

```bash
GIT_REPOS=(
    "https://github.com/juno-fx/Orion-Deployment.git"
    "https://github.com/juno-fx/Genesis-Deployment.git"
)

DOCKER_IMAGES=(
    "aliolozy/tinygit:latest"
    "registry:3"
)
```

## Cleanup

Remove build artifacts:

```bash
make clean
```

## Testing

Run the integration test to verify the build, extraction, Docker registry, and git server:

```bash
# Using make
make test

# Or directly
./test-integration.sh
```

The integration test performs:
1. Builds the bundle
2. Extracts to a temporary directory
3. Starts services via load.sh
4. Tests Docker registry (push/pull an image)
5. Tests Git server (clones a repository)
6. Cleans up all artifacts regardless of pass or fail

## Linting

Run shellcheck to validate the scripts:

```bash
# Using make
make lint

# Or directly with devbox
devbox run -- shellcheck build-bundle.sh test-integration.sh
```

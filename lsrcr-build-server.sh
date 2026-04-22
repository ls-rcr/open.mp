#!/bin/bash

# Detect platform
OS="$(uname -s)"
case "$OS" in
    Linux*)            PLATFORM="linux" ;;
    MINGW*|CYGWIN*|MSYS*) PLATFORM="windows" ;;
    *)                 PLATFORM="linux" ;;
esac

# Linux requires sudo for Docker; Windows (Git Bash/WSL) does not
if [ "$PLATFORM" = "linux" ]; then
    SUDO="sudo"
else
    SUDO=""
fi

# Conan cache — use $HOME so it resolves correctly on both platforms
CONAN_PATH="$HOME/.conan2"

DOCKER_IMAGE="open.mp/build:ubuntu-22.04"
DOCKER_DIR="docker/build_ubuntu-22.04"
REBUILD=0

for arg in "$@"; do
    case "$arg" in
        --rebuild|-r) REBUILD=1 ;;
        *) echo "Unknown option: $arg"; echo "Usage: $0 [--rebuild|-r]"; exit 1 ;;
    esac
done

# Build the Docker image if it doesn't exist or --rebuild was passed
if [ "$REBUILD" = "1" ] || ! $SUDO docker image inspect "$DOCKER_IMAGE" > /dev/null 2>&1; then
    echo "Building Docker image '$DOCKER_IMAGE'..."
    $SUDO docker build -t "$DOCKER_IMAGE" "$DOCKER_DIR"
fi

# Check if 'build/' directory exists
if [ ! -d "build/" ]; then
    echo "Creating 'build/' directory..."
    mkdir build
fi

# Ensure the build dir is writable by the Docker container user (uid 1000)
if [ "$PLATFORM" = "linux" ]; then
    $SUDO chown -R 1000:1000 build
fi

# Navigate to the 'build/' directory
cd build/

# On Windows, Git Bash auto-converts /code → C:/code when calling native exes.
# Disable that so Docker receives the correct Linux container paths.
if [ "$PLATFORM" = "windows" ]; then
    export MSYS_NO_PATHCONV=1
fi

# Run the Docker command
$SUDO docker run \
    --rm \
    -t \
    -w /code \
    -v "$PWD/../:/code" \
    -v "$PWD/:/code/build" \
    -v "$CONAN_PATH:/home/root/.conan" \
    -e CONFIG=RelWithDebInfo \
    -e TARGET_BUILD_ARCH=x86 \
    -e BUILD_SHARED=0 \
    -e BUILD_SERVER=1 \
    -e BUILD_TOOLS=0 \
    -e OMP_BUILD_VERSION=$(git rev-list $(git rev-list --max-parents=0 HEAD) HEAD | wc -l) \
    -e OMP_BUILD_COMMIT=$(git rev-parse HEAD) \
    "$DOCKER_IMAGE"

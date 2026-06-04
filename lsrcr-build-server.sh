#!/bin/bash

# Detect host platform
OS="$(uname -s)"
case "$OS" in
    Linux*)            HOST="linux" ;;
    MINGW*|CYGWIN*|MSYS*) HOST="windows" ;;
    *)                 HOST="linux" ;;
esac

if [ "$HOST" = "linux" ]; then
    SUDO="sudo"
else
    SUDO=""
fi

CONAN_PATH="$HOME/.conan2"
DOCKER_IMAGE="open.mp/build:ubuntu-22.04"
DOCKER_DIR="docker/build_ubuntu-22.04"
REBUILD=0
TARGET=""
CONFIG="RelWithDebInfo"

usage() {
    echo "Usage: $0 --linux | --win32 [--rebuild|-r]"
    exit 1
}

for arg in "$@"; do
    case "$arg" in
        --linux|-l)   TARGET="linux" ;;
        --win32|-w)   TARGET="win32" ;;
        --rebuild|-r) REBUILD=1 ;;
        *) echo "Unknown option: $arg"; usage ;;
    esac
done

if [ -z "$TARGET" ]; then
    TARGET="linux"
fi

OMP_BUILD_VERSION=$(git rev-list $(git rev-list --max-parents=0 HEAD) HEAD | wc -l | tr -d ' ')
OMP_BUILD_COMMIT=$(git rev-parse HEAD)

# Wipe build dir if it was made for a different target
BUILD_MARKER="build/.lsrcr-target"
if [ -d "build/" ]; then
    PREV_TARGET=""
    if [ -f "$BUILD_MARKER" ]; then
        PREV_TARGET=$(cat "$BUILD_MARKER")
    fi
    if [ "$PREV_TARGET" != "$TARGET" ]; then
        echo "Target changed ($PREV_TARGET -> $TARGET), clearing build/..."
        rm -rf build/
    fi
fi

if [ ! -d "build/" ]; then
    mkdir build
fi
echo "$TARGET" > "$BUILD_MARKER"

if [ "$TARGET" = "linux" ]; then
    if [ "$REBUILD" = "1" ] || ! $SUDO docker image inspect "$DOCKER_IMAGE" > /dev/null 2>&1; then
        echo "Building Docker image '$DOCKER_IMAGE'..."
        $SUDO docker build -t "$DOCKER_IMAGE" "$DOCKER_DIR"
    fi

    if [ "$HOST" = "linux" ]; then
        $SUDO chown -R 1000:1000 build
    fi

    cd build/

    if [ "$HOST" = "windows" ]; then
        export MSYS_NO_PATHCONV=1
    fi

    $SUDO docker run \
        --rm \
        -t \
        -w /code \
        -v "$PWD/../:/code" \
        -v "$PWD/:/code/build" \
        -v "$CONAN_PATH:/home/root/.conan" \
        -e CONFIG=$CONFIG \
        -e TARGET_BUILD_ARCH=x86 \
        -e BUILD_SHARED=0 \
        -e BUILD_SERVER=1 \
        -e BUILD_TOOLS=0 \
        -e OMP_BUILD_VERSION=$OMP_BUILD_VERSION \
        -e OMP_BUILD_COMMIT=$OMP_BUILD_COMMIT \
        "$DOCKER_IMAGE"

elif [ "$TARGET" = "win32" ]; then
    # Project requires Conan 1.x — enforce the same version CI uses
    pip install -q "conan==1.65.0"

    cd build/

    cmake \
        -DCMAKE_BUILD_TYPE=$CONFIG \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
        -DOMP_BUILD_VERSION=$OMP_BUILD_VERSION \
        -DOMP_BUILD_COMMIT=$OMP_BUILD_COMMIT \
        -DBUILD_SERVER=1 \
        -DBUILD_TOOLS=0 \
        -A Win32 \
        -T "ClangCL" \
        ..

    cmake --build . --config $CONFIG
fi

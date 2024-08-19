#!/bin/bash

# Check if 'build/' directory exists
if [ ! -d "build/" ]; then
    echo "Creating 'build/' directory..."
    mkdir build
fi

# Navigate to the 'build/' directory
cd build/

# Run the Docker command
sudo docker run \
    --rm \
    -t \
    -w /code \
    -v $PWD/../:/code \
    -v $PWD/:/code/build \
    -v /home/richano/.conan2:/home/root/.conan \
    -e CONFIG=RelWithDebInfo \
    -e TARGET_BUILD_ARCH=x86 \
    -e BUILD_SHARED=0 \
    -e BUILD_SERVER=1 \
    -e BUILD_TOOLS=0 \
    -e OMP_BUILD_VERSION=$(git rev-list $(git rev-list --max-parents=0 HEAD) HEAD | wc -l) \
    -e OMP_BUILD_COMMIT=$(git rev-parse HEAD) \
    open.mp/build:ubuntu-20.04
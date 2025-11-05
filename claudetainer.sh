#!/bin/bash

# create unique name for the container and hash of the current directory
DIR_HASH=$(echo -n "$(pwd)" | md5sum | cut -d' ' -f1)

CONTAINER_NAME="claudetainer-$DIR_HASH"

# Check if container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
  # Container exists, start and attach to it
  echo "Starting existing container: $CONTAINER_NAME"
  docker start -ai $CONTAINER_NAME
else
  # Container doesn't exist, create it
  echo "Creating new container: $CONTAINER_NAME"
  docker run -it \
    --name $CONTAINER_NAME \
    --platform="linux/arm64" \
    --memory="4g" \
    --memory-swap="4g" \
    --cpus="2.0" \
    --pids-limit=100 \
    -v $HOME/.claude.json:/home/claude/.claude.json \
    -v $HOME/.claude:/home/claude/.claude \
    -v $HOME/.config/claude:/claude \
    -v $HOME/.codex:/home/claude/.codex \
    -v $(pwd):$(pwd) \
    -w $(pwd) \
    -e CLAUDE_CONFIG_DIR=/claude \
    claudetainer
fi

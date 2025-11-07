#!/bin/bash

# create unique name for the container and hash of the current directory
DIR_HASH=$(echo -n "$(pwd)" | md5sum | cut -d' ' -f1)
TIMESTAMP=$(date | md5sum | cut -c 1,8)

CONTAINER_NAME="claudetainer-${DIR_HASH}-${TIMESTAMP}"

docker run -it \
  --rm \
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
  claudetainer "$@"

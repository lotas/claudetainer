#!/bin/bash

docker run -it --rm \
  --platform="linux/arm64" \
  --memory="4g" \
  --memory-swap="4g" \
  --cpus="2.0" \
  --pids-limit=100 \
  -v $HOME/.claude.json:/home/claude/.claude.json \
  -v $HOME/.claude:/home/claude/.claude \
  -v $HOME/.config/claude:/claude \
  -v $(pwd):$(pwd) \
  -w $(pwd) \
  -e CLAUDE_CONFIG_DIR=/claude \
  claudetainer

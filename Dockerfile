ARG TARGETPLATFORM=linux/arm64
FROM node:24-slim

RUN apt-get update && \
  apt-get install -y procps curl wget git build-essential ca-certificates gnupg && rm -rf /var/lib/apt/lists/*


RUN useradd -ms /bin/bash claude
WORKDIR /home/claude

RUN mkdir /home/claude/.npm && \
  chown claude:claude -R /home/claude/.npm

USER claude
ENV HOME=/home/claude
ENV NODE_ENV=production
ENV PATH=/home/claude/.npm/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Prevent Claude from hanging at 100% CPU
# Memory allocator settings for Linux
ENV MALLOC_TRIM_THRESHOLD_=-1
ENV MALLOC_MMAP_THRESHOLD_=134217728
ENV MALLOC_ARENA_MAX=4

# Disable file watching to reduce CPU usage in containers
ENV CHOKIDAR_USEPOLLING=false
ENV WATCHPACK_POLLING=false
ENV NODE_NO_WARNINGS=1

# Optimize Node.js for container environment
ENV NODE_OPTIONS="--max-old-space-size=4096 --max-semi-space-size=64"

RUN npm config set prefix /home/claude/.npm && \
  npm install -g @anthropic-ai/claude-code

# Healthcheck to detect if claude is hanging
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD pgrep -x node > /dev/null || exit 1

ENTRYPOINT ["claude"]

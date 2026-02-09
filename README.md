# Devtainer

Run your dev environment in isolated Docker containers on ARM Macs.

Each project gets its own container with all common development tools pre-installed, with access only to that project's directory.

## Why

Not because I don't trust AI agents or any 3rd party npm/python package running arbitrary code on my host machine,
but because I want to make my local dev experience harder (or more fun).

On Mac I'm using OrbStack as an awesome tool to run `docker` containers.
However, the default behaviour is to give full disk access basically to everything running inside and outside:
https://github.com/orbstack/orbstack/issues/169

By running dev containers with only the project folder mounted, I can hope that occasional `npm install` will not
start scanning my host for crypto wallets or password stores.
Of course, this works as long as container and docker manage to isolate itself from the rest of the system.
Probably slightly more secure than running it on my host machine.

## Features

- **Single Universal Image**: One container image with all common dev tools pre-installed
- **Project Isolation**: Each project gets its own container, with access only to the project directory
- **Container Reuse**: Containers are reused across sessions for fast startup
- **Multi-Session**: Run multiple terminal sessions in the same container simultaneously

## Included Tools

- **Node.js**: v24 with npm, yarn
- **Bun**: fast JavaScript runtime and package manager
- **Go**: via gvm
- **Python**: 3.14 with pip, poetry, pipenv
- **uv**: fast Python package installer
- **Neovim**: 0.11 with LazyVim
- **Claude CLI**: installed natively
- **OpenAI Codex**: via npm
- **agent-browser**: headless Chromium for AI agents
- **System Tools**: git, make, build-essential, curl, wget, ripgrep, fd, htop

## Building and Installing

Images are not published — build locally:

```bash
make build
# same as:
# docker build --platform=linux/arm64 -f Dockerfile.devtainer -t devtainer .

make install  # adds symlink to ~/.local/bin/devtainer
```

## Usage

```bash
# Navigate to your project
cd ~/my-project

# Start interactive shell
devtainer
# or
devtainer shell

# Inside the container, all tools are available:
python3 --version
node --version
make test
```

### Execute Commands

Run commands without entering the shell:

```bash
devtainer exec python3 script.py
devtainer exec make test
devtainer exec npm install
devtainer exec go build ./...
```

### Multi-Session Workflows

Run multiple terminal sessions in the same container simultaneously. Each session gets its own shell process but shares the same environment, filesystem, and running processes.

```bash
# Terminal 1: Start your development server
devtainer shell
npm run dev

# Terminal 2: Run tests (simultaneously)
devtainer shell
npm test -- --watch

# Terminal 3: View active sessions
devtainer ps
```

### Container Management

```bash
devtainer stop       # Stop the container (keeps it for reuse)
devtainer clean      # Remove the container completely
devtainer rebuild    # Rebuild the image (after Dockerfile changes)
```

### Exposing Ports

```bash
DEVTAINER_PORTS="9090,3306" devtainer shell
```

### Accessing Host Services

From inside the container, access host services via `host.docker.internal`:

```bash
psql -h host.docker.internal -p 5432 -U postgres -d mydb
redis-cli -h host.docker.internal -p 6379
```

## Customization

```bash
devtainer init --with-dockerfile  # initialize .devtainer directory

# add more tools
vim .devtainer/Dockerfile

# update mem/cpu limits or port configs in .devtainer/config

# rebuild image
devtainer rebuild

# recreate dev container
devtainer clean
devtainer shell
```

Run `devtainer help` for full command reference.

# Claudetainer & Devtainer

Running claude code and dev env in containers on ARM macs.

`claudetainer` to run claude code in docker container

`devtainer` to run projects inside reusable docker containers

## Building and running

Images are not being published on purpose, it's better to build them locally

```bash
make build  # claudetainer
# same as:
# docker build --platform=linux/arm64 -t claudetainer .

make build-dev # devtainer
# same as:
# docker build --platform=linux/arm64 -f Dockerfile.devtainer -t devtainer .

make install # adds soft links to the ~/.local/bin
# or manually to your favourite bin folder:
# ln -sf $(PWD)/claudetainer.sh ~/bin/claudetainer
# ln -sf $(PWD)/devtainer.sh ~/bin/devtainer
```

## Why

Not because I don't trust AI agents or any 3rd party npm/python package running arbitrary code on my host machine,
but because I want to make my local dev experience harder (or more fun).

On Mac I'm using OrbStack as an awesome tool to run `docker` containers.
However, the default behaviour is to give full disk access basically to everything running inside and outside:
https://github.com/orbstack/orbstack/issues/169

By running claude code inside a container I am only mapping current project folder. And I don't have to worry that
some typo in a generated and executed command will do something silly on my host.

And by running dev container with only the project folder mounted, I can hope that occasional `npm install` will not
start scanning my host for crypto wallets or password stores.
Of course, this works as long as container and docker manage to isolate itself from the rest of the system.
Probably slightly more secure than running it on my host machine.

## Claudetainer

Inside the project run `claudetainer` (which should be a link or alias to `$path/claudetainer.sh`)

First run would require login: run `/login` command to complete login/signup.

Claude settings are being mapped to host, so should stay preserved between runs.

## Devtainer

Devtainer creates project-specific Docker containers with all common development tools pre-installed. Each project gets its own isolated container with access only to that project's directory.

### Features

- **Single Universal Image**: One container image with Node.js, Go, Python, and uv pre-installed
- **Project Isolation**: Each project gets its own container, with access only to the project directory
- **Container Reuse**: Containers are reused across sessions for fast startup

### Included Tools

- **Node.js**: v24 with npm
- **Go**: v1.25.0
- **Python**: 3.14 with pip, poetry, pipenv
- **uv**: Fast Python package installer
- **System Tools**: git, make, build-essential, curl, wget

Easy to extend with project-specific builds

### Use in Your Projects

```bash
# Navigate to your project
cd ~/my-python-project

# Start interactive shell
devtainer
# or devtainer shell

# Inside the container, all tools are available:
python3 --version
uv --version
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

### Container Management

```bash
# Stop the container (keeps it for reuse)
devtainer.sh stop

# Remove the container completely
devtainer.sh clean

# Rebuild the image (after Dockerfile changes)
devtainer.sh rebuild
```

### How It Works

1. **Container Naming**: Each project gets a unique container name based on the project directory path hash
2. **Volume Mounting**: Only the current project directory is mounted at the same path inside the container
3. **Persistence**: Containers run detached with `tail -f /dev/null` and are reused across sessions
4. **Working Directory**: The container's working directory matches your project path

### Exposing Ports

```bash
DEVTAINER_PORTS="9090,3306" devtainer shell
```

### Accessing Host Services

From inside the container, access host services (including Docker containers) using `host.docker.internal`:

**PostgreSQL on host:**
```bash
devtainer shell
psql -h host.docker.internal -p 5432 -U postgres -d mydb
```

### Customization

```bash
devtainer init --with-dockerfile  # initialize .devtainer directory

# add more tools
vim .devtainer/dockerfile

# update mem/cpu limits or port configs in .devtainer/config

# rebuild image
devtainer rebuild

# recreate dev container
devtainer clean
devtainer shell
```

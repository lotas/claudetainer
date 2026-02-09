.PHONY: build build-no-cache
.PHONY: install install-devtainer uninstall

build:
	docker build --platform=linux/arm64 -f Dockerfile.devtainer -t devtainer .

install: install-devtainer

install-devtainer:
	@mkdir -p ~/.local/bin
	ln -sf $(PWD)/devtainer.sh ~/.local/bin/devtainer

uninstall:
	rm -f ~/.local/bin/devtainer

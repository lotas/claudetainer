.PHONY: build run
.PHONY: build-dev build-dev-no-cache
.PHONY: install install-claudetainer install-devtainer uninstall

build:
		docker build --platform=linux/arm64 --no-cache -t claudetainer .

build-dev:
	docker build --platform=linux/arm64 -f Dockerfile.devtainer -t devtainer .

install: install-claudetainer install-devtainer install-codextainer

install-claudetainer:
	@mkdir -p ~/.local/bin
	ln -sf $(PWD)/claudetainer.sh ~/.local/bin/claudetainer

install-codextainer:
	@mkdir -p ~/.local/bin
	ln -sf $(PWD)/codextainer.sh ~/.local/bin/codextainer

install-devtainer:
	@mkdir -p ~/.local/bin
	ln -sf $(PWD)/devtainer.sh ~/.local/bin/devtainer

uninstall:
	rm -f ~/.local/bin/claudetainer
	rm -f ~/.local/bin/devtainer
	rm -f ~/.local/bin/codextainer

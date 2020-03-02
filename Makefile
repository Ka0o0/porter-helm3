MIXIN = helm3
PKG = get.porter.sh/mixin/$(MIXIN)
SHELL = bash

GO = GO111MODULE=on go

PORTER_HOME ?= $(HOME)/.porter

COMMIT ?= $(shell git rev-parse --short HEAD)
VERSION ?= $(shell git describe --tags 2> /dev/null || echo v0.1.0)
PERMALINK ?= $(shell git describe --tags --exact-match &> /dev/null && echo latest || echo canary)

LDFLAGS = -w -X $(PKG)/pkg.Version=$(VERSION) -X $(PKG)/pkg.Commit=$(COMMIT)
XBUILD = CGO_ENABLED=0 $(GO) build -a -tags netgo -ldflags '$(LDFLAGS)'
BINDIR = bin/mixins/$(MIXIN)

CLIENT_PLATFORM ?= $(shell go env GOOS)
CLIENT_ARCH ?= $(shell go env GOARCH)
RUNTIME_PLATFORM ?= linux
RUNTIME_ARCH ?= amd64
SUPPORTED_PLATFORMS = linux darwin windows
SUPPORTED_ARCHES = amd64

ifeq ($(CLIENT_PLATFORM),windows)
FILE_EXT=.exe
else ifeq ($(RUNTIME_PLATFORM),windows)
FILE_EXT=.exe
else
FILE_EXT=
endif

REGISTRY ?= $(USER)

.PHONY: build
build: build-client build-runtime clean-packr

build-runtime: generate
	mkdir -p $(BINDIR)
	GOARCH=$(RUNTIME_ARCH) GOOS=$(RUNTIME_PLATFORM) $(GO) build -ldflags '$(LDFLAGS)' -o $(BINDIR)/$(MIXIN)-runtime$(FILE_EXT) ./cmd/$(MIXIN)

build-client: generate
	mkdir -p $(BINDIR)
	$(GO) build -ldflags '$(LDFLAGS)' -o $(BINDIR)/$(MIXIN)$(FILE_EXT) ./cmd/$(MIXIN)

generate: packr2
	$(GO) generate ./...

HAS_PACKR2 := $(shell command -v packr2)
packr2:
ifndef HAS_PACKR2
	$(GO) get -u github.com/gobuffalo/packr/v2/packr2
endif

xbuild-all:
	$(foreach OS, $(SUPPORTED_PLATFORMS), \
		$(foreach ARCH, $(SUPPORTED_ARCHES), \
				$(MAKE) $(MAKE_OPTS) CLIENT_PLATFORM=$(OS) CLIENT_ARCH=$(ARCH) MIXIN=$(MIXIN) xbuild; \
		))
	$(MAKE) clean-packr

xbuild: $(BINDIR)/$(VERSION)/$(MIXIN)-$(CLIENT_PLATFORM)-$(CLIENT_ARCH)$(FILE_EXT)
$(BINDIR)/$(VERSION)/$(MIXIN)-$(CLIENT_PLATFORM)-$(CLIENT_ARCH)$(FILE_EXT):
	mkdir -p $(dir $@)
	GOOS=$(CLIENT_PLATFORM) GOARCH=$(CLIENT_ARCH) $(XBUILD) -o $@ ./cmd/$(MIXIN)

test: test-unit
	$(BINDIR)/$(MIXIN)$(FILE_EXT) version

test-unit: build
	$(GO) test ./...

publish: bin/porter$(FILE_EXT)
	# The following demonstrates how to publish a mixin. As an example, we show how to publish to azure.
	# The porter mixins feed generate command is used to build an ATOM feed for sharing mixins once published

	# AZURE_STORAGE_CONNECTION_STRING will be used for auth in the following commands
	if [[ "$(PERMALINK)" == "latest" ]]; then \
		az storage blob upload-batch -d porter/mixins/$(MIXIN)/$(VERSION) -s $(BINDIR)/$(VERSION); \
		az storage blob upload-batch -d porter/mixins/$(MIXIN)/$(PERMALINK) -s $(BINDIR)/$(VERSION); \
	else \
		mv $(BINDIR)/$(VERSION) $(BINDIR)/$(PERMALINK); \
		az storage blob upload-batch -d porter/mixins/$(MIXIN)/$(PERMALINK) -s $(BINDIR)/$(PERMALINK); \
	fi

	# Generate the mixin feed
	az storage blob download -c porter -n atom.xml -f bin/atom.xml
	bin/porter mixins feed generate -d bin/mixins -f bin/atom.xml -t build/atom-template.xml
	#az storage blob upload -c porter -n atom.xml -f bin/atom.xml

bin/porter$(FILE_EXT):
	curl -fsSLo bin/porter$(FILE_EXT) https://cdn.porter.sh/canary/porter-$(CLIENT_PLATFORM)-$(CLIENT_ARCH)$(FILE_EXT)
	chmod +x bin/porter$(FILE_EXT)

install:
	porter mixin uninstall $(MIXIN)
	mkdir -p $(PORTER_HOME)/mixins/$(MIXIN)
	install $(BINDIR)/$(MIXIN)$(FILE_EXT) $(PORTER_HOME)/mixins/$(MIXIN)/$(MIXIN)$(FILE_EXT)
	install $(BINDIR)/$(MIXIN)-runtime$(FILE_EXT) $(PORTER_HOME)/mixins/$(MIXIN)/$(MIXIN)-runtime$(FILE_EXT)
	porter mixin list
clean: clean-packr
	-rm -fr bin/

clean-packr: packr2
	cd pkg/helm3 && packr2 clean
.PHONY: multiarch build run

# Default values for variables
REPO  ?= mastrogeppetto/nglab-desktop-multiarch
TAG   ?= latest

#REPO  ?= dorowu/ubuntu-desktop-lxde-vnc
#TAG   ?= latest
# you can choose other base image versions
IMAGE ?= ubuntu:jammy-20220531
# IMAGE ?= nvidia/cuda:10.1-cudnn7-devel-ubuntu18.04
# choose from supported flavors (see available ones in ./flavors/*.yml)
FLAVOR ?= lxde
# arm64 or amd64
ARCH ?= amd64
# apt source
LOCALBUILD ?= 0

# These files will be generated from teh Jinja templates (.j2 sources)
templates = Dockerfile rootfs/etc/supervisor/conf.d/supervisord.conf

multiarch:
	ARCH=arm64 make build
	ARCH=amd64 make build
	docker manifest create \
	  mastrogeppetto/nglab-desktop-multiarch:latest \
	  --amend mastrogeppetto/nglab-desktop-multiarch_amd64:latest \
	  --amend mastrogeppetto/nglab-desktop-multiarch_arm64:latest
	

build: $(templates)
	cp Dockerfile Dockerfile.$(ARCH)
	docker buildx build --load --platform linux/$(ARCH) -t $(REPO)_$(ARCH):$(TAG) -f Dockerfile.$(ARCH) .
	

# Rebuild the container image
#build: $(templates)
#	cp Dockerfile Dockerfile.$(ARCH)
#	docker build -t $(REPO):$(TAG) -f Dockerfile.$(ARCH) .

# Test run the container
# the local dir will be mounted under /src read-only
run:
	docker run --privileged --rm \
		-p 6080:80 -p 6081:443 \
		-v ${PWD}:/src:ro \
		-e USER=doro -e PASSWORD=mypassword \
		-e ALSADEV=hw:2,0 \
		-e SSL_PORT=443 \
		-e RELATIVE_URL_ROOT=approot \
		-e OPENBOX_ARGS="--startup /usr/bin/galculator" \
		-v ${PWD}/ssl:/etc/nginx/ssl \
		--device /dev/snd \
		--name ubuntu-desktop-lxde-test \
		$(REPO)_$(ARCH):$(TAG)

# Connect inside the running container for debugging
shell:
	docker exec -it ubuntu-desktop-lxde-test bash

# Generate the SSL/TLS config for HTTPS
gen-ssl:
	mkdir -p ssl
	openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
		-keyout ssl/nginx.key -out ssl/nginx.crt

clean:
	rm -f $(templates)

extra-clean:
	docker rmi $(REPO):$(TAG)
	docker image prune -f

# Run jinja2cli to parse Jinja template applying rules defined in the flavors definitions
%: %.j2 flavors/$(FLAVOR).yml
	docker run --rm -v $(shell pwd):/data vikingco/jinja2cli \
		-D flavor=$(FLAVOR) \
		-D image=$(IMAGE) \
		-D localbuild=$(LOCALBUILD) \
		-D arch=$(ARCH) \
		$< flavors/$(FLAVOR).yml > $@ || rm $@

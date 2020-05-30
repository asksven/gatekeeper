# Build docker image with buildx
# Experimental docker feature to build cross platform multi-architecture docker images
# https://docs.docker.com/buildx/working-with-buildx/
docker-buildx:
	export DOCKER_CLI_EXPERIMENTAL=enabled
	@if ! docker buildx ls | grep -q container-builder; then\
		docker buildx create --platform "linux/amd64,linux/arm64,linux/arm/v7" --name container-builder --use;\
	fi
	docker buildx build --platform "linux/amd64,linux/arm64,linux/arm/v7" \
		-t $(REPOSITORY):$(VERSION) \
		. --push


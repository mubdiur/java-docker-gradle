#!/bin/bash

DOCKER_COMPOSE_FILE="docker-compose.yml"
DOCKERFILE="Dockerfile"
JAVA_FILE="HelloWorld.java"

echo "Building and starting the container using Docker Compose..."
docker compose up --build --abort-on-container-exit
EXIT_CODE=$?
echo "Docker Compose finished with exit code: $EXIT_CODE"

exit $EXIT_CODE
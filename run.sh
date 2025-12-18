#!/bin/bash

# Script Name: run.sh
# Description: Builds and runs the HelloWorld Java app in a Docker container using Java 17.

set -e # Exit immediately if a command exits with a non-zero status

DOCKER_COMPOSE_FILE="docker-compose.yml"
DOCKERFILE="Dockerfile"
JAVA_FILE="HelloWorld.java"

# --- Build and Run with Docker Compose ---
echo "Building and starting the container using Docker Compose..."
# The --build flag forces rebuilding the image to ensure latest code changes are included
# The --abort-on-container-exit flag ensures the compose session stops when the app container exits
docker compose up --build --abort-on-container-exit

# Get the exit code from the service container
# docker-compose up returns the exit code of the first container to exit when using --abort-on-container-exit
EXIT_CODE=$?
echo "Docker Compose finished with exit code: $EXIT_CODE"

# Optional: Clean up containers after running (uncomment if desired)
# echo "Removing stopped containers..."
# docker-compose down

exit $EXIT_CODE
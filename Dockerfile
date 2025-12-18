# Use the official Eclipse Temurin (Adoptium) OpenJDK 17 slim image as the base image
FROM eclipse-temurin:21-jdk-alpine AS build

# Set the working directory inside the container
WORKDIR /app

# Install Gradle
RUN apk add --no-cache curl unzip
RUN curl -L https://services.gradle.org/distributions/gradle-8.5-bin.zip -o gradle.zip && \
    unzip gradle.zip -d /opt && \
    rm gradle.zip && \
    ln -s /opt/gradle-8.5/bin/gradle /usr/bin/gradle

# Copy the Gradle project files
COPY . .

# Build the application using Gradle
RUN gradle build --no-daemon

# Runtime stage
FROM eclipse-temurin:21-jre-alpine

# Set the working directory
WORKDIR /app

# Copy the built JAR from the build stage
# Use wildcards to handle version-specific naming
COPY --from=build /app/app/build/libs/*.jar app.jar

# Command to run the Java application when the container starts
CMD ["java", "-jar", "app.jar"]
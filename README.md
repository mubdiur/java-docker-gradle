# 🚀 Java Docker Gradle Project

A modern, containerized Java application template combining the power of **Java 21**, **Docker**, and **Gradle** for streamlined development and deployment. This project serves as the perfect starting point for building robust, scalable Java applications with cloud-native architecture.

## ✨ Features

- 🎯 **Modern Java Stack**: Built with Java 21 leveraging the latest language features
- 🐳 **Container-First Design**: Multi-stage Docker builds for optimized production images
- 🔧 **Gradle Build System**: Fast, flexible build automation with dependency management
- 🚀 **One-Command Deployment**: Simple scripts for running and managing the application
- 🌟 **Railpack Support**: Modern cloud-native build system for effortless deployment
- 🔄 **Easy Project Customization**: Automated scripts for renaming projects and switching Java versions
- ✅ **Testing Ready**: Pre-configured with JUnit testing framework
- 📦 **Fat JAR Production**: Self-contained executable JAR with all dependencies

## 🏗️ Project Structure

```
.
├── 📁 app/
│   ├── 📁 src/
│   │   ├── 📁 main/
│   │   │   └── 📁 java/com/demo/
│   │   │       └── 📄 App.java          # Main application class
│   │   └── 📁 test/
│   │       └── 📁 java/com/demo/
│   │           └── 📄 AppTest.java      # Unit tests
│   └── 📄 build.gradle.kts              # Gradle build configuration
├── 📄 Dockerfile                       # Multi-stage Docker configuration
├── 📄 docker-compose.yml               # Docker Compose service definition
├── 📄 railpack.json                   # Railpack build configuration
├── 📄 settings.gradle.kts              # Gradle project settings
├── 📄 run.sh                          # Quick start script
├── 📄 rename-project.sh               # Project renaming utility
├── 📄 set-java-version.sh             # Java version switcher
└── 📄 README.md                       # This file
```

## 🚀 Quick Start

### Prerequisites

- **Java 21** (or Java 8/11/17 if you switch versions)
- **Docker** & **Docker Compose**
- **Gradle 8.5+** (or use Gradle Wrapper)
- **Railpack CLI** (optional, for cloud deployment)

### Option 1: Docker Compose (Recommended)

```bash
# Clone the repository
git clone <repository-url>
cd java-docker-gradle

# Build and run the application
./run.sh
```

### Option 2: Manual Docker Build

```bash
# Build the Docker image
docker build -t demo-project-app .

# Run the container
docker run --rm demo-project-app
```

### Option 3: Railpack Cloud Deployment

```bash
# Install Railpack CLI
curl -sSL https://railpack.dev/install | sh

# Build and deploy to the cloud
railpack build
railpack deploy

# Or build and deploy in one command
railpack deploy --build
```

### Option 4: Local Gradle Build

```bash
# Build the project
./gradlew build

# Run the application
java -jar app/build/libs/app.jar
```

## 🛠️ Development Guide

### Building the Project

```bash
# Clean and build
./gradlew clean build

# Run tests
./gradlew test

# Create executable JAR
./gradlew jar
```

### Running Tests

```bash
# Run all tests
./gradlew test

# Run tests with coverage report
./gradlew test jacocoTestReport
```

### Development Mode

For rapid development during coding:

```bash
# Run in watch mode (requires additional configuration)
./gradlew build --continuous
```

## 🐳 Docker Configuration

### Multi-Stage Build

The Dockerfile uses a multi-stage build strategy:

1. **Build Stage**: Compiles the application using Gradle with JDK
2. **Runtime Stage**: Creates a minimal image with JRE only

### Build Process

```bash
# Rebuild with Docker Compose
docker-compose up --build

# Build without cache
docker-compose build --no-cache
```

## 🔧 Customization Tools

### Renaming Your Project

Use the interactive script to rename your project:

```bash
# Interactive mode
./rename-project.sh --interactive

# Or specify directly
./rename-project.sh -p com.mycompany -a my-awesome-app
```

This script updates:
- Package names and directory structure
- Main class references
- Docker service names
- Gradle project configuration

### Switching Java Versions

Change Java versions across the entire project:

```bash
# Interactive mode
./set-java-version.sh --interactive

# Or specify version (supports: 8, 11, 17, 21, 22)
./set-java-version.sh -v 17

# Check current version
./set-java-version.sh --current
```

The script updates:
- Gradle Java toolchain configuration
- Docker base images (JDK/JRE versions)
- Build configurations

## 📋 Scripts Overview

| Script | Purpose | Key Features |
|--------|---------|--------------|
| `run.sh` | Quick start application | Builds and runs with Docker Compose |
| `rename-project.sh` | Project customization | Renames packages, app, and Docker services |
| `set-java-version.sh` | Java version management | Updates Java version across all configs |

## 🔍 Application Details

### Main Application

The `App.java` class provides a simple "Hello World!" implementation:

```java
package com.demo;

public class App {
    public String getGreeting() {
        return "Hello World!";
    }

    public static void main(String[] args) {
        System.out.println(new App().getGreeting());
    }
}
```

### Dependencies

- **JUnit 5**: Testing framework
- **Guava**: Google's core libraries (optional utility)

### Build Configuration

- **Java Version**: 21 (configurable)
- **Gradle Version**: 8.5+
- **Application Plugin**: For CLI application support
- **Fat JAR**: Includes all dependencies

## 🌟 Advanced Usage

### Environment Variables

Configure application behavior via environment variables:

```bash
# Set custom environment variables
docker run -e APP_ENV=production demo-project-app
```

### Custom Docker Compose

Extend the docker-compose.yml for additional services:

```yaml
services:
  demo-project-app:
    build: .
    environment:
      - SPRING_PROFILES_ACTIVE=prod
    ports:
      - "8080:8080"
```

### Railpack Configuration

The `railpack.json` file provides cloud-native deployment configuration:

```json
{
  "name": "demo-project",
  "type": "java",
  "build": {
    "builder": "gradle",
    "buildCommand": "./gradlew build -x test",
    "outputDirectory": "app/build/libs",
    "outputFile": "*.jar"
  },
  "run": {
    "command": ["java", "-jar", "app.jar"],
    "port": 8080
  },
  "deploy": {
    "replicas": 1,
    "resources": {
      "cpu": "500m",
      "memory": "512Mi"
    }
  }
}
```

Key Railpack features:
- 🚀 **Automatic Build Detection**: Gradle projects automatically configured
- 📦 **Dependency Management**: Handles Java dependencies automatically
- 🔧 **Environment Variables**: Configure via `railpack.json` or CLI
- 📊 **Resource Management**: CPU and memory allocation control
- 🔄 **Health Checks**: Built-in application health monitoring

### CI/CD Integration

The project structure is CI/CD friendly:

**GitHub Actions Example:**
```yaml
name: Build and Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up JDK 21
        uses: actions/setup-java@v3
        with:
          java-version: '21'
          distribution: 'temurin'
      - name: Run tests
        run: ./gradlew test
      - name: Deploy with Railpack (optional)
        if: github.ref == 'refs/heads/main'
        run: |
          curl -sSL https://railpack.dev/install | sh
          railpack deploy
```

**Railpack CI/CD Pipeline:**
```yaml
# GitHub Actions with Railpack
name: Deploy with Railpack
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Setup Railpack
        run: curl -sSL https://railpack.dev/install | sh
      - name: Deploy to Cloud
        run: railpack deploy
        env:
          RAILPACK_TOKEN: ${{ secrets.RAILPACK_TOKEN }}
```

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙋‍♂️ Support

Have questions or need help?

- 🐛 **Bug Reports**: Open an issue on GitHub
- 💡 **Feature Requests**: Open an issue with the "enhancement" label
- 📧 **General Questions**: Use GitHub Discussions

---

## 🎉 What's Next?

Here are some ideas to extend this template:

- 🌐 Add a web framework (Spring Boot, Micronaut, Quarkus)
- 🗄️ Integrate database support (PostgreSQL, MongoDB)
- 🔐 Add authentication and authorization
- 📊 Implement monitoring and logging
- 🚀 Deploy to cloud platforms (AWS, GCP, Azure)
- 📦 Add API documentation (OpenAPI/Swagger)
- 🧪 Add integration and end-to-end tests

Made with ❤️ for the Java community! 🚀
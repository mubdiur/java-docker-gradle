# =========================
# Build Stage
# =========================
FROM eclipse-temurin:21-jdk AS build

WORKDIR /app

# 1. Install Basics
RUN apt-get update && \
    apt-get install -y bash && \
    rm -rf /var/lib/apt/lists/*

# 2. Copy ONLY the Gradle Wrapper first
#    We copy specific files so Docker doesn't "see" changes 
#    in libs.versions.toml yet.
COPY gradlew .
COPY gradle/wrapper gradle/wrapper

RUN chmod +x gradlew

# 3. Download Gradle Distribution (The Heavy Lift)
#    This layer will now ONLY invalidate if you change 
#    gradle-wrapper.properties, not your dependencies.
RUN ./gradlew --version --no-daemon

# 4. Copy Project Configuration
#    Now we copy the rest of the 'gradle' folder (including libs.versions.toml)
#    and the settings files.
COPY gradle gradle
COPY settings.gradle.kts gradle.properties ./
COPY app/build.gradle.kts app/

# 5. Download Project Dependencies
#    This runs if libs.versions.toml or build.gradle.kts changes.
RUN ./gradlew dependencies --no-daemon

# 6. Copy Source Code & Build
COPY . .
RUN ./gradlew build --no-daemon

# =========================
# Runtime Stage
# =========================
FROM eclipse-temurin:21-jre

WORKDIR /app
COPY --from=build /app/app/build/libs/*.jar app.jar

CMD ["java", "-jar", "app.jar"]
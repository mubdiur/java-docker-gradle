#!/bin/bash

# Set Java Version Script
# This script updates the Java version across all project configuration files

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Supported Java versions
SUPPORTED_VERSIONS=(8 11 17 21 22)

# Default current version (will be detected from files)
CURRENT_JAVA_VERSION=""
NEW_JAVA_VERSION=""

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script updates the Java version across all project configuration files."
    echo ""
    echo "Options:"
    echo "  -v, --version <version>   Set new Java version (${SUPPORTED_VERSIONS[*]})"
    echo "  -i, --interactive         Interactive mode - prompts for version"
    echo "  -c, --current             Show current Java version"
    echo "  -h, --help               Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -v 21"
    echo "  $0 --interactive"
    echo "  $0 --current"
    echo ""
}

# Function to validate Java version
validate_java_version() {
    local version=$1
    if [[ ! " ${SUPPORTED_VERSIONS[@]} " =~ " ${version} " ]]; then
        print_error "Unsupported Java version: $version"
        print_error "Supported versions: ${SUPPORTED_VERSIONS[*]}"
        exit 1
    fi
}

# Function to detect current Java version
detect_current_version() {
    print_info "Detecting current Java version..."

    # Check build.gradle.kts
    if [[ -f "app/build.gradle.kts" ]]; then
        local detected_version=$(grep -o 'languageVersion = JavaLanguageVersion.of([0-9]\+)' app/build.gradle.kts | grep -o '[0-9]\+' | head -1)
        if [[ -n "$detected_version" ]]; then
            CURRENT_JAVA_VERSION="$detected_version"
            print_info "Found Java $CURRENT_JAVA_VERSION in build.gradle.kts"
        fi
    fi

    # Check Dockerfile
    if [[ -f "Dockerfile" ]]; then
        local docker_version=$(grep -o 'eclipse-temurin:[0-9]\+' Dockerfile | grep -o '[0-9]\+' | head -1)
        if [[ -n "$docker_version" ]]; then
            if [[ -z "$CURRENT_JAVA_VERSION" ]]; then
                CURRENT_JAVA_VERSION="$docker_version"
                print_info "Found Java $docker_version in Dockerfile"
            elif [[ "$CURRENT_JAVA_VERSION" != "$docker_version" ]]; then
                print_warning "Dockerfile uses Java $docker_version but build.gradle.kts uses Java $CURRENT_JAVA_VERSION"
            fi
        fi
    fi

    if [[ -z "$CURRENT_JAVA_VERSION" ]]; then
        print_warning "Could not detect current Java version, assuming Java 17"
        CURRENT_JAVA_VERSION="17"
    fi
}

# Function to replace in file
replace_in_file() {
    local file=$1
    local old_pattern=$2
    local new_pattern=$3
    local description=$4

    if [[ -f "$file" ]]; then
        # Use sed for replacement, handle different OS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|${old_pattern}|${new_pattern}|g" "$file"
        else
            sed -i "s|${old_pattern}|${new_pattern}|g" "$file"
        fi
        print_info "Updated: $file ($description)"
    fi
}

# Function to update build.gradle.kts
update_build_gradle() {
    local version=$1
    print_info "Updating build.gradle.kts..."

    # Update Java language version
    replace_in_file "app/build.gradle.kts" \
        "languageVersion = JavaLanguageVersion.of([0-9]\+)" \
        "languageVersion = JavaLanguageVersion.of(${version})" \
        "Java language version"
}

# Function to update Dockerfile
update_dockerfile() {
    local version=$1
    print_info "Updating Dockerfile..."

    # Update JDK version in build stage
    replace_in_file "Dockerfile" \
        "FROM eclipse-temurin:[0-9]\+-jdk-alpine AS build" \
        "FROM eclipse-temurin:${version}-jdk-alpine AS build" \
        "Build stage JDK version"

    # Update JRE version in runtime stage
    replace_in_file "Dockerfile" \
        "FROM eclipse-temurin:[0-9]\+-jre-alpine" \
        "FROM eclipse-temurin:${version}-jre-alpine" \
        "Runtime stage JRE version"
}

# Function to check for additional Java version references
check_additional_files() {
    print_info "Checking for additional Java version references..."

    local found_files=()

    # Check GitHub Actions workflows
    if [[ -d ".github/workflows" ]]; then
        local workflow_files=$(find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null || true)
        for file in $workflow_files; do
            if grep -q "java-version\|java:[0-9]\+" "$file" 2>/dev/null; then
                found_files+=("$file")
            fi
        done
    fi

    # Check README files
    for readme in README.md README readme.md; do
        if [[ -f "$readme" ]] && grep -q "Java [0-9]\+" "$readme" 2>/dev/null; then
            found_files+=("$readme")
        fi
    done

    if [[ ${#found_files[@]} -gt 0 ]]; then
        print_warning "Found additional files that might contain Java version references:"
        for file in "${found_files[@]}"; do
            echo "  - $file"
        done
        print_warning "Please review and update these files manually if needed."
    fi
}

# Function to test Java version compatibility
check_compatibility() {
    local old_version=$1
    local new_version=$2

    if [[ $new_version -lt $old_version ]]; then
        print_warning "Downgrading from Java $old_version to Java $new_version"
        print_warning "Please ensure your code is compatible with Java $new_version"
        print_warning "Check for:"
        echo "  - Var keyword (requires Java 10+)"
        echo "  - Text blocks (requires Java 15+)"
        echo "  - Records (requires Java 16+)"
        echo "  - Pattern matching (requires Java 16+)"
        echo "  - Switch expressions (requires Java 14+)"
        read -p "Continue with downgrade? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Operation cancelled."
            exit 0
        fi
    elif [[ $new_version -gt $old_version ]]; then
        print_success "Upgrading from Java $old_version to Java $new_version"
        print_info "You can now use newer Java features available in version $new_version"
    fi
}

# Parse command line arguments
INTERACTIVE=false
SHOW_CURRENT=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -v|--version)
            NEW_JAVA_VERSION="$2"
            shift 2
            ;;
        -i|--interactive)
            INTERACTIVE=true
            shift
            ;;
        -c|--current)
            SHOW_CURRENT=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Detect current version
detect_current_version

# Show current version if requested
if [[ "$SHOW_CURRENT" == true ]]; then
    echo "Current Java version: $CURRENT_JAVA_VERSION"
    exit 0
fi

# Interactive mode
if [[ "$INTERACTIVE" == true ]]; then
    echo ""
    print_info "=== Interactive Java Version Update ==="
    echo ""
    echo "Current Java version: $CURRENT_JAVA_VERSION"
    echo "Supported versions: ${SUPPORTED_VERSIONS[*]}"
    echo ""
    read -p "Enter new Java version: " NEW_JAVA_VERSION
    echo ""
fi

# Validate input
if [[ -z "$NEW_JAVA_VERSION" ]]; then
    print_error "Java version is required"
    show_usage
    exit 1
fi

validate_java_version "$NEW_JAVA_VERSION"

# Show summary
echo ""
print_info "=== Java Version Update Summary ==="
echo "Current Java version: $CURRENT_JAVA_VERSION"
echo "New Java version: $NEW_JAVA_VERSION"
echo ""

# Check compatibility
check_compatibility "$CURRENT_JAVA_VERSION" "$NEW_JAVA_VERSION"

# Confirm before proceeding
read -p "Do you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Operation cancelled."
    exit 0
fi

print_info "Starting Java version update..."

# Step 1: Update build.gradle.kts
print_info "Step 1: Updating Gradle configuration..."
update_build_gradle "$NEW_JAVA_VERSION"

# Step 2: Update Dockerfile
print_info "Step 2: Updating Docker configuration..."
update_dockerfile "$NEW_JAVA_VERSION"

# Step 3: Clean up build cache
print_info "Step 3: Cleaning up build cache..."
if [[ -d ".gradle" ]]; then
    rm -rf .gradle
    print_info "Removed .gradle cache"
fi

if [[ -d "app/build" ]]; then
    rm -rf app/build
    print_info "Removed app/build directory"
fi

# Step 4: Check for additional files
check_additional_files

# Step 5: Show completion message
echo ""
print_success "=== Java Version Update Complete! ==="
echo ""
print_info "Files that were modified:"
echo "  - app/build.gradle.kts (Java language version)"
echo "  - Dockerfile (JDK and JRE versions)"
echo ""
print_success "Next steps:"
echo "1. Test the build: ./gradlew build"
echo "2. Run tests: ./gradlew test"
echo "3. Run with Docker: docker-compose up --build"
echo "4. Commit your changes: git add . && git commit -m 'Update Java version to ${NEW_JAVA_VERSION}'"
echo ""

if [[ $NEW_JAVA_VERSION -gt $CURRENT_JAVA_VERSION ]]; then
    print_info "New Java $NEW_JAVA_VERSION features you can now use:"
    case $NEW_JAVA_VERSION in
        11)
            echo "  - Local variable type inference (var)"
            echo "  - HTTP Client"
            echo "  - Collection factory methods"
            ;;
        17)
            echo "  - Text blocks (\"\"\"...\"\"\")"
            echo "  - Records"
            echo "  - Pattern matching for instanceof"
            echo "  - Sealed classes"
            ;;
        21)
            echo "  - Record patterns"
            echo "  - Pattern matching for switch"
            echo "  - String templates (preview)"
            echo "  - Virtual threads"
            ;;
        22)
            echo "  - Unnamed variables & patterns"
            echo "  - String templates (final)"
            echo "  - Implicitly declared classes"
            ;;
    esac
    echo ""
fi
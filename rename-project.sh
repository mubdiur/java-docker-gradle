#!/bin/bash

# Rename Project Script
# This script renames package names and application names throughout the project

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to detect current package from Java files
detect_current_package() {
    local java_file=$(find app/src/main/java -name "*.java" -type f | head -1)
    if [[ -f "$java_file" ]]; then
        local package_line=$(grep -E "^package " "$java_file" | head -1)
        if [[ -n "$package_line" ]]; then
            CURRENT_PACKAGE=$(echo "$package_line" | sed 's/package //; s/;//' | tr -d ' ')
            print_info "Detected current package: $CURRENT_PACKAGE"
        fi
    fi

    # Fallback if detection fails
    if [[ -z "$CURRENT_PACKAGE" ]]; then
        CURRENT_PACKAGE="com.demo"
        print_warning "Could not detect package, using default: $CURRENT_PACKAGE"
    fi
}

# Function to detect current app name from build.gradle.kts
detect_current_app_name() {
    if [[ -f "settings.gradle.kts" ]]; then
        local app_name_line=$(grep "rootProject.name" "settings.gradle.kts" | head -1)
        if [[ -n "$app_name_line" ]]; then
            CURRENT_APP_NAME=$(echo "$app_name_line" | sed 's/.*"\(.*\)".*/\1/')
            print_info "Detected current app name: $CURRENT_APP_NAME"
        fi
    fi

    # Fallback if detection fails
    if [[ -z "$CURRENT_APP_NAME" ]]; then
        CURRENT_APP_NAME="demo-project"
        print_warning "Could not detect app name, using default: $CURRENT_APP_NAME"
    fi
}

# Function to detect current Docker image name
detect_current_docker_image() {
    if [[ -f "docker-compose.yml" ]]; then
        local image_line=$(grep -E "image:" "docker-compose.yml" | head -1)
        if [[ -n "$image_line" ]]; then
            CURRENT_DOCKER_IMAGE=$(echo "$image_line" | sed 's/.*image: *//; s/["'\'']//g')
            print_info "Detected current Docker image: $CURRENT_DOCKER_IMAGE"
        fi
    fi

    # Fallback if detection fails
    if [[ -z "$CURRENT_DOCKER_IMAGE" ]]; then
        CURRENT_DOCKER_IMAGE="${CURRENT_APP_NAME}-app"
        print_warning "Could not detect Docker image, using default: $CURRENT_DOCKER_IMAGE"
    fi
}

# Function to validate package name format
validate_package_name() {
    if [[ ! $1 =~ ^[a-z]+(\.[a-z][a-z0-9]*)*$ ]]; then
        print_error "Package name must be a valid Java package (e.g., com.mycompany, org.example.app)"
        exit 1
    fi
}

# Function to validate app name format
validate_app_name() {
    if [[ ! $1 =~ ^[a-z][a-z0-9-]*$ ]]; then
        print_error "App name must start with a letter and contain only lowercase letters, numbers, and hyphens"
        exit 1
    fi
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "This script renames package names and application names throughout the project."
    echo ""
    echo "Options:"
    echo "  -p, --package <name>     Set new package name (e.g., com.mycompany)"
    echo "  -a, --app-name <name>    Set new application name (e.g., my-awesome-app)"
    echo "  -i, --interactive        Interactive mode - prompts for values"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 -p com.mycompany -a my-app"
    echo "  $0 --interactive"
    echo ""
    echo "Current detected values:"
    echo "  Package: $CURRENT_PACKAGE"
    echo "  App Name: $CURRENT_APP_NAME"
    echo "  Docker Image: $CURRENT_DOCKER_IMAGE"
}

# Function to prompt for input
prompt_input() {
    local prompt=$1
    local default=$2
    local var_name=$3
    local value

    read -p "$prompt [$default]: " value
    if [[ -z "$value" ]]; then
        value="$default"
    fi
    eval "$var_name=\"$value\""
}

# Function to replace in file
replace_in_file() {
    local file=$1
    local old_string=$2
    local new_string=$3

    if [[ -f "$file" ]]; then
        # Escape special characters in old_string for sed
        local escaped_old=$(printf '%s\n' "$old_string" | sed 's/[[\.*^$()+?{|]/\\&/g')
        # Use sed for replacement, handle different OS
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|${escaped_old}|${new_string}|g" "$file"
        else
            sed -i "s|${escaped_old}|${new_string}|g" "$file"
        fi
        print_info "Updated: $file"
    fi
}

# Function to rename directories
rename_directory() {
    local old_path=$1
    local new_path=$2

    if [[ -d "$old_path" && ! -d "$new_path" ]]; then
        # Ensure parent directory exists
        local parent_dir=$(dirname "$new_path")
        if [[ ! -d "$parent_dir" ]]; then
            mkdir -p "$parent_dir"
        fi
        mv "$old_path" "$new_path"
        print_success "Renamed directory: $old_path -> $new_path"
    fi
}

# Parse command line arguments
INTERACTIVE=false
NEW_PACKAGE=""
NEW_APP_NAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--package)
            NEW_PACKAGE="$2"
            shift 2
            ;;
        -a|--app-name)
            NEW_APP_NAME="$2"
            shift 2
            ;;
        -i|--interactive)
            INTERACTIVE=true
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

# Detect current values
print_info "Detecting current project configuration..."
detect_current_package
detect_current_app_name
detect_current_docker_image

# Interactive mode
if [[ "$INTERACTIVE" == true ]]; then
    echo ""
    print_info "=== Interactive Project Rename ==="
    echo ""
    prompt_input "Enter new package name" "$CURRENT_PACKAGE" "NEW_PACKAGE"
    prompt_input "Enter new application name" "$CURRENT_APP_NAME" "NEW_APP_NAME"
    echo ""
fi

# Validate inputs
if [[ -z "$NEW_PACKAGE" ]]; then
    print_error "Package name is required"
    show_usage
    exit 1
fi

if [[ -z "$NEW_APP_NAME" ]]; then
    print_error "App name is required"
    show_usage
    exit 1
fi

validate_package_name "$NEW_PACKAGE"
validate_app_name "$NEW_APP_NAME"

# Derive Docker image name from app name
NEW_DOCKER_IMAGE="${NEW_APP_NAME}-app"

# Show summary
echo ""
print_info "=== Rename Summary ==="
echo "Current Package: $CURRENT_PACKAGE -> New Package: $NEW_PACKAGE"
echo "Current App Name: $CURRENT_APP_NAME -> New App Name: $NEW_APP_NAME"
echo "Current Docker Image: $CURRENT_DOCKER_IMAGE -> New Docker Image: $NEW_DOCKER_IMAGE"
echo ""

# Confirm before proceeding
read -p "Do you want to proceed? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_warning "Operation cancelled."
    exit 0
fi

print_info "Starting rename process..."

# Step 1: Rename package directories
print_info "Step 1: Renaming package directories..."
OLD_PACKAGE_PATH="app/src/main/java/$(echo $CURRENT_PACKAGE | tr '.' '/')"
NEW_PACKAGE_PATH="app/src/main/java/$(echo $NEW_PACKAGE | tr '.' '/')"

if [[ -d "$OLD_PACKAGE_PATH" ]]; then
    rename_directory "$OLD_PACKAGE_PATH" "$NEW_PACKAGE_PATH"
fi

# Also rename test package directory
OLD_TEST_PACKAGE_PATH="app/src/test/java/$(echo $CURRENT_PACKAGE | tr '.' '/')"
NEW_TEST_PACKAGE_PATH="app/src/test/java/$(echo $NEW_PACKAGE | tr '.' '/')"

if [[ -d "$OLD_TEST_PACKAGE_PATH" ]]; then
    rename_directory "$OLD_TEST_PACKAGE_PATH" "$NEW_TEST_PACKAGE_PATH"
fi

# Step 2: Update package declarations in Java files
print_info "Step 2: Updating package declarations in Java files..."
find . -name "*.java" -type f -exec grep -l "package ${CURRENT_PACKAGE}" {} \; 2>/dev/null | while read file; do
    replace_in_file "$file" "package ${CURRENT_PACKAGE}" "package ${NEW_PACKAGE}"
done

# Step 3: Update main class reference in build.gradle.kts
print_info "Step 3: Updating build configuration..."
MAIN_CLASS_PATH="${NEW_PACKAGE}.App"
replace_in_file "app/build.gradle.kts" "mainClass = \"${CURRENT_PACKAGE}.App\"" "mainClass = \"${MAIN_CLASS_PATH}\""
replace_in_file "app/build.gradle.kts" "attributes\[\"Main-Class\"\] = \"${CURRENT_PACKAGE}.App\"" "attributes[\"Main-Class\"] = \"${MAIN_CLASS_PATH}\""

# Step 4: Update project name in settings.gradle.kts
print_info "Step 4: Updating project configuration..."
replace_in_file "settings.gradle.kts" "rootProject.name = \"${CURRENT_APP_NAME}\"" "rootProject.name = \"${NEW_APP_NAME}\""

# Step 5: Update Docker Compose file
print_info "Step 5: Updating Docker Compose configuration..."
replace_in_file "docker-compose.yml" "$CURRENT_DOCKER_IMAGE" "$NEW_DOCKER_IMAGE"

# Step 6: Clean up any leftover .gradle directories that might reference old names
print_info "Step 6: Cleaning up build cache..."
if [[ -d ".gradle" ]]; then
    rm -rf .gradle
    print_info "Removed .gradle cache to prevent conflicts"
fi

if [[ -d "app/.gradle" ]]; then
    rm -rf app/.gradle
    print_info "Removed app/.gradle cache to prevent conflicts"
fi

if [[ -d "app/build" ]]; then
    rm -rf app/build
    print_info "Removed app/build directory to force rebuild"
fi

# Step 7: Clean up old package directories
print_info "Step 7: Cleaning up old package directories..."

# Function to remove empty parent directories
cleanup_empty_parents() {
    local dir_path=$1
    while [[ "$dir_path" != "." && "$dir_path" != "/" ]]; do
        # Check if directory is empty (only contains other empty directories)
        if [[ -d "$dir_path" ]]; then
            local remaining_files=$(find "$dir_path" -type f | wc -l)
            if [[ $remaining_files -eq 0 ]]; then
                rmdir "$dir_path" 2>/dev/null && print_info "Removed empty directory: $dir_path"
            else
                break
            fi
        fi
        dir_path=$(dirname "$dir_path")
    done
}

# Clean up main source old package directories
OLD_MAIN_PACKAGE_DIR="app/src/main/java/$(echo $CURRENT_PACKAGE | tr '.' '/')"
if [[ -d "$OLD_MAIN_PACKAGE_DIR" ]]; then
    # Only remove if we successfully moved to a new location
    if [[ -d "app/src/main/java/$(echo $NEW_PACKAGE | tr '.' '/')" ]]; then
        rm -rf "$OLD_MAIN_PACKAGE_DIR"
        print_info "Removed old package directory: $OLD_MAIN_PACKAGE_DIR"
        # Clean up any empty parent directories
        cleanup_empty_parents "$(dirname "$OLD_MAIN_PACKAGE_DIR")"
    fi
fi

# Clean up test source old package directories
OLD_TEST_PACKAGE_DIR="app/src/test/java/$(echo $CURRENT_PACKAGE | tr '.' '/')"
if [[ -d "$OLD_TEST_PACKAGE_DIR" ]]; then
    # Only remove if we successfully moved to a new location
    if [[ -d "app/src/test/java/$(echo $NEW_PACKAGE | tr '.' '/')" ]]; then
        rm -rf "$OLD_TEST_PACKAGE_DIR"
        print_info "Removed old test package directory: $OLD_TEST_PACKAGE_DIR"
        # Clean up any empty parent directories
        cleanup_empty_parents "$(dirname "$OLD_TEST_PACKAGE_DIR")"
    fi
fi

# Step 8: Update any README files if they exist
print_info "Step 8: Updating documentation files..."
if [[ -f "README.md" ]]; then
    replace_in_file "README.md" "$CURRENT_APP_NAME" "$NEW_APP_NAME"
fi

if [[ -f "README" ]]; then
    replace_in_file "README" "$CURRENT_APP_NAME" "$NEW_APP_NAME"
fi

# Step 9: Show what changed
echo ""
print_success "=== Rename Complete! ==="
echo ""
print_info "Files that were modified:"
if [[ -f "app/src/main/java/$(echo $NEW_PACKAGE | tr '.' '/')/App.java" ]]; then
    echo "  - app/src/main/java/$(echo $NEW_PACKAGE | tr '.' '/')/App.java (package declaration)"
fi
if [[ -f "app/src/test/java/$(echo $NEW_PACKAGE | tr '.' '/')/AppTest.java" ]]; then
    echo "  - app/src/test/java/$(echo $NEW_PACKAGE | tr '.' '/')/AppTest.java (package declaration)"
fi
echo "  - app/build.gradle.kts (main class and jar manifest)"
echo "  - settings.gradle.kts (project name)"
echo "  - docker-compose.yml (service name)"
echo ""

print_info "Directories that were renamed:"
echo "  - app/src/main/java/$(echo $CURRENT_PACKAGE | tr '.' '/')/ -> $(echo $NEW_PACKAGE | tr '.' '/')/"
if [[ -d "app/src/test/java/$(echo $NEW_PACKAGE | tr '.' '/')" ]]; then
    echo "  - app/src/test/java/$(echo $CURRENT_PACKAGE | tr '.' '/')/ -> $(echo $NEW_PACKAGE | tr '.' '/')/"
fi
echo ""
print_info "Old directories were cleaned up automatically"
echo ""

print_success "Next steps:"
echo "1. Test the build: ./gradlew build"
echo "2. Run tests: ./gradlew test"
echo "3. Run with Docker: docker-compose up --build"
echo "4. Commit your changes: git add . && git commit -m 'Rename project to ${NEW_APP_NAME}'"
echo ""

print_info "Note: Build caches were cleared to prevent conflicts with the old package name."
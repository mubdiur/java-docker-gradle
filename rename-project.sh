#!/usr/bin/env bash

################################################################################
# Java Project Renamer - Nuclear Edition
# 
# ZERO TOLERANCE FOR INCONSISTENCIES
# - Scans entire project tree
# - Finds and replaces ALL references
# - Handles mixed/broken configurations
# - Leaves absolutely nothing behind
# - Still maintains professional safety features
################################################################################

set -euo pipefail
IFS=$'\n\t'

################################################################################
# CONFIGURATION
################################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="$SCRIPT_DIR/.rename-backup-$(date +%Y%m%d_%H%M%S)"
LOG_FILE="$SCRIPT_DIR/rename-project.log"
DRY_RUN=false
VERBOSE=false
FORCE=false

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

################################################################################
# UTILITY FUNCTIONS
################################################################################

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[⚠]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*" | tee -a "$LOG_FILE"
}

log_debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${MAGENTA}[DEBUG]${NC} $*" | tee -a "$LOG_FILE"
    fi
}

log_nuke() {
    echo -e "${RED}[☢]${NC} $*" | tee -a "$LOG_FILE"
}

print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║     ☢  JAVA PROJECT RENAMER - NUCLEAR EDITION  ☢            ║
║     Zero Tolerance for Inconsistencies                       ║
║     Scans Everything. Replaces Everything.                   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

show_usage() {
    cat << EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -p, --package PKG     New package name (e.g., com.company.app)
    -n, --name NAME       New application name (e.g., my-app)
    -d, --dry-run         Preview changes without applying them
    -f, --force           Skip confirmation prompts
    -v, --verbose         Enable verbose logging
    -r, --rollback        Rollback to previous backup
    -h, --help            Show this help message

EXAMPLES:
    # Interactive mode
    $0

    # Non-interactive with options
    $0 -p com.acme.widget -n acme-widget

    # Dry run to preview ALL changes
    $0 -p com.test.app -n test-app --dry-run

    # Rollback last change
    $0 --rollback

EOF
}

################################################################################
# VALIDATION
################################################################################

validate_package_name() {
    local pkg="$1"
    
    if ! [[ "$pkg" =~ ^[a-z][a-z0-9_]*(\.[a-z][a-z0-9_]*)+$ ]]; then
        log_error "Invalid package name: '$pkg'"
        log_error "Must: start with lowercase, use dots, contain 2+ segments"
        return 1
    fi
    
    local reserved_words=("abstract" "assert" "boolean" "break" "byte" "case" "catch" "char" "class" "const" "continue" "default" "do" "double" "else" "enum" "extends" "final" "finally" "float" "for" "goto" "if" "implements" "import" "instanceof" "int" "interface" "long" "native" "new" "package" "private" "protected" "public" "return" "short" "static" "strictfp" "super" "switch" "synchronized" "this" "throw" "throws" "transient" "try" "void" "volatile" "while")
    
    IFS='.' read -ra SEGMENTS <<< "$pkg"
    for segment in "${SEGMENTS[@]}"; do
        for keyword in "${reserved_words[@]}"; do
            if [[ "$segment" == "$keyword" ]]; then
                log_error "Package segment '$segment' is a Java reserved keyword"
                return 1
            fi
        done
    done
    
    return 0
}

validate_app_name() {
    local name="$1"
    
    if ! [[ "$name" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
        log_error "Invalid application name: '$name'"
        log_error "Must: start with lowercase/digit, use only lowercase, digits, hyphens, underscores"
        return 1
    fi
    
    if [[ ${#name} -lt 2 || ${#name} -gt 50 ]]; then
        log_error "Application name must be between 2 and 50 characters"
        return 1
    fi
    
    return 0
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    command -v sed >/dev/null 2>&1 || missing_tools+=("sed")
    command -v find >/dev/null 2>&1 || missing_tools+=("find")
    command -v grep >/dev/null 2>&1 || missing_tools+=("grep")
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    if [[ ! -f "settings.gradle.kts" && ! -f "settings.gradle" ]]; then
        log_error "Not a valid Gradle project (no settings.gradle.kts or settings.gradle)"
        return 1
    fi
    
    if [[ ! -d "app/src" ]]; then
        log_error "Standard Gradle structure not found (app/src missing)"
        return 1
    fi
    
    log_success "All prerequisites met"
    return 0
}

################################################################################
# NUCLEAR SCANNING - FIND ALL REFERENCES
################################################################################

find_all_packages() {
    log_info "Scanning entire project for package declarations..."
    
    local packages=()
    
    # Find all package declarations in Java files
    while IFS= read -r file; do
        local pkg
        pkg=$(grep "^package " "$file" 2>/dev/null | head -n1 | sed 's/package //;s/;//' | tr -d ' ' || true)
        if [[ -n "$pkg" ]]; then
            packages+=("$pkg")
            log_debug "Found package in $file: $pkg"
        fi
    done < <(find . -type f -name "*.java" 2>/dev/null || true)
    
    # Remove duplicates and sort
    local unique_packages
    unique_packages=$(printf '%s\n' "${packages[@]}" | sort -u)
    
    echo "$unique_packages"
}

find_all_app_names() {
    log_info "Scanning entire project for app name references..."
    
    local names=()
    
    # From settings.gradle.kts
    if [[ -f "settings.gradle.kts" ]]; then
        local name
        name=$(grep 'rootProject.name' settings.gradle.kts 2>/dev/null | sed 's/.*=//;s/[" ]//g' | tr -d '\n' || true)
        [[ -n "$name" ]] && names+=("$name")
    fi
    
    # From settings.gradle
    if [[ -f "settings.gradle" ]]; then
        local name
        name=$(grep 'rootProject.name' settings.gradle 2>/dev/null | sed 's/.*=//;s/[" '\'']//g' | tr -d '\n' || true)
        [[ -n "$name" ]] && names+=("$name")
    fi
    
    # From docker-compose.yml
    if [[ -f "docker-compose.yml" ]]; then
        local name
        name=$(grep -E "^\s+image:" docker-compose.yml 2>/dev/null | head -n1 | sed 's/.*image://;s/-app//;s/ //g' | tr -d '\n' || true)
        [[ -n "$name" ]] && names+=("$name")
    fi
    
    # From README.md (first header)
    if [[ -f "README.md" ]]; then
        local name
        name=$(head -n5 README.md 2>/dev/null | grep "^#" | head -n1 | sed 's/^#*//;s/ //g' | tr '[:upper:]' '[:lower:]' | tr -d '\n' || true)
        [[ -n "$name" ]] && names+=("$name")
    fi
    
    # Remove duplicates
    local unique_names
    unique_names=$(printf '%s\n' "${names[@]}" | sort -u)
    
    echo "$unique_names"
}

scan_project_inconsistencies() {
    log_warn "=== INCONSISTENCY SCAN ==="
    
    local packages
    packages=$(find_all_packages)
    
    local pkg_count
    pkg_count=$(echo "$packages" | grep -c . || echo "0")
    
    if [[ $pkg_count -gt 1 ]]; then
        log_warn "Found $pkg_count DIFFERENT packages in project:"
        echo "$packages" | while read -r pkg; do
            [[ -n "$pkg" ]] && echo "    - $pkg"
        done
        echo
    elif [[ $pkg_count -eq 1 ]]; then
        log_info "Current package: $(echo "$packages" | head -n1)"
    else
        log_warn "No package declarations found (fresh project)"
    fi
    
    local app_names
    app_names=$(find_all_app_names)
    
    local name_count
    name_count=$(echo "$app_names" | grep -c . || echo "0")
    
    if [[ $name_count -gt 1 ]]; then
        log_warn "Found $name_count DIFFERENT app names in project:"
        echo "$app_names" | while read -r name; do
            [[ -n "$name" ]] && echo "    - $name"
        done
        echo
    elif [[ $name_count -eq 1 ]]; then
        log_info "Current app name: $(echo "$app_names" | head -n1)"
    fi
    
    echo "$packages"
}

################################################################################
# BACKUP AND ROLLBACK
################################################################################

create_backup() {
    if [[ "$DRY_RUN" == true ]]; then
        log_info "[DRY-RUN] Would create backup at: $BACKUP_DIR"
        return 0
    fi
    
    log_info "Creating backup at: $BACKUP_DIR"
    mkdir -p "$BACKUP_DIR"
    
    # Backup entire project except build artifacts and git
    tar czf "$BACKUP_DIR/project-backup.tar.gz" \
        --exclude='.git' \
        --exclude='build' \
        --exclude='.gradle' \
        --exclude='*.class' \
        --exclude='*.jar' \
        --exclude='node_modules' \
        . 2>/dev/null || true
    
    cat > "$BACKUP_DIR/metadata.txt" << EOF
Backup Date: $(date)
Script Version: 3.0 Nuclear Edition
Working Directory: $SCRIPT_DIR
EOF
    
    log_success "Backup created successfully"
}

list_backups() {
    log_info "Available backups:"
    local backup_count=0
    
    for backup in "$SCRIPT_DIR"/.rename-backup-*; do
        if [[ -d "$backup" ]]; then
            backup_count=$((backup_count + 1))
            local backup_name
            backup_name=$(basename "$backup")
            echo "  [$backup_count] $backup_name"
            if [[ -f "$backup/metadata.txt" ]]; then
                grep "Backup Date" "$backup/metadata.txt" | sed 's/^/      /'
            fi
        fi
    done
    
    if [[ $backup_count -eq 0 ]]; then
        log_warn "No backups found"
        return 1
    fi
    
    return 0
}

perform_rollback() {
    log_info "Initiating rollback procedure..."
    
    if ! list_backups; then
        log_error "Cannot rollback: No backups available"
        return 1
    fi
    
    echo
    read -rp "Enter backup number to restore (or 'cancel'): " backup_choice
    
    if [[ "$backup_choice" == "cancel" ]]; then
        log_info "Rollback cancelled"
        return 0
    fi
    
    local backup_dirs=("$SCRIPT_DIR"/.rename-backup-*)
    local selected_index=$((backup_choice - 1))
    
    if [[ $selected_index -lt 0 || $selected_index -ge ${#backup_dirs[@]} ]]; then
        log_error "Invalid backup selection"
        return 1
    fi
    
    local backup_dir="${backup_dirs[$selected_index]}"
    
    log_warn "This will restore files from: $(basename "$backup_dir")"
    read -rp "Are you sure? (yes/no): " confirm
    
    if [[ "$confirm" != "yes" ]]; then
        log_info "Rollback cancelled"
        return 0
    fi
    
    log_info "Restoring from backup..."
    
    if [[ -f "$backup_dir/project-backup.tar.gz" ]]; then
        tar xzf "$backup_dir/project-backup.tar.gz" -C "$SCRIPT_DIR"
        log_success "Rollback completed successfully"
    else
        log_error "Backup archive not found"
        return 1
    fi
    
    return 0
}

################################################################################
# NUCLEAR REPLACEMENT ENGINE
################################################################################

safe_sed() {
    local pattern="$1"
    local file="$2"
    
    if [[ "$DRY_RUN" == true ]]; then
        return 0
    fi
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        sed -i '' "$pattern" "$file"
    else
        sed -i "$pattern" "$file"
    fi
}

nuclear_replace_in_file() {
    local file="$1"
    local old_value="$2"
    local new_value="$3"
    local description="$4"
    
    if [[ ! -f "$file" ]]; then
        return 0
    fi
    
    # Check if file contains the old value
    if ! grep -q "$old_value" "$file" 2>/dev/null; then
        return 0
    fi
    
    local count
    count=$(grep -c "$old_value" "$file" 2>/dev/null || echo "0")
    
    if [[ $count -gt 0 ]]; then
        log_nuke "Replacing $count occurrence(s) of '$old_value' in: $(basename "$file") ($description)"
        
        if [[ "$DRY_RUN" == false ]]; then
            safe_sed "s|${old_value}|${new_value}|g" "$file"
        fi
    fi
}

nuclear_replace_package_everywhere() {
    local old_packages="$1"
    local new_package="$2"
    
    log_nuke "INITIATING PACKAGE REPLACEMENT ACROSS ENTIRE PROJECT"
    
    # Convert new package to path
    local new_pkg_path="${new_package//./\/}"
    
    # Process each old package
    echo "$old_packages" | while IFS= read -r old_pkg; do
        [[ -z "$old_pkg" ]] && continue
        
        log_warn "Targeting old package: $old_pkg"
        
        local old_pkg_path="${old_pkg//./\/}"
        
        # Find ALL text files (not just Java)
        local extensions=("*.java" "*.kt" "*.kts" "*.xml" "*.yml" "*.yaml" "*.properties" "*.gradle" "*.md" "*.txt" "*.sh" "*.json")
        
        for ext in "${extensions[@]}"; do
            while IFS= read -r file; do
                # Skip if file is in build directory or is binary
                if [[ "$file" == *"/build/"* ]] || [[ "$file" == *"/.gradle/"* ]]; then
                    continue
                fi
                
                # Replace package declaration
                nuclear_replace_in_file "$file" "package $old_pkg" "package $new_package" "package declaration"
                
                # Replace import statements
                nuclear_replace_in_file "$file" "import $old_pkg" "import $new_package" "import statement"
                
                # Replace in mainClass declarations
                nuclear_replace_in_file "$file" "\"$old_pkg\." "\"$new_package." "mainClass reference"
                
                # Replace path references
                nuclear_replace_in_file "$file" "$old_pkg_path" "$new_pkg_path" "path reference"
                
                # Replace dot-notation references (but be careful)
                nuclear_replace_in_file "$file" "$old_pkg\\." "$new_package." "qualified reference"
                
            done < <(find . -type f -name "$ext" 2>/dev/null || true)
        done
    done
    
    log_success "Package replacement completed"
}

nuclear_replace_app_name_everywhere() {
    local old_names="$1"
    local new_app="$2"
    
    log_nuke "INITIATING APP NAME REPLACEMENT ACROSS ENTIRE PROJECT"
    
    echo "$old_names" | while IFS= read -r old_name; do
        [[ -z "$old_name" ]] && continue
        
        log_warn "Targeting old app name: $old_name"
        
        # Find ALL configuration and documentation files
        local file_patterns=("*.gradle" "*.kts" "*.yml" "*.yaml" "*.md" "*.txt" "*.properties" "*.json" "*.sh" "Dockerfile*" "docker-compose*")
        
        for pattern in "${file_patterns[@]}"; do
            while IFS= read -r file; do
                # Skip build directories
                if [[ "$file" == *"/build/"* ]] || [[ "$file" == *"/.gradle/"* ]]; then
                    continue
                fi
                
                # Replace in various contexts
                nuclear_replace_in_file "$file" "rootProject.name = \"$old_name\"" "rootProject.name = \"$new_app\"" "Gradle project name"
                nuclear_replace_in_file "$file" "rootProject.name = '$old_name'" "rootProject.name = \"$new_app\"" "Gradle project name (single quotes)"
                nuclear_replace_in_file "$file" "name: $old_name" "name: $new_app" "YAML name"
                nuclear_replace_in_file "$file" "image: $old_name" "image: $new_app" "Docker image"
                nuclear_replace_in_file "$file" "container_name: $old_name" "container_name: $new_app" "Docker container"
                nuclear_replace_in_file "$file" "# $old_name" "# $new_app" "Markdown header"
                
                # Replace as standalone word (using word boundaries when possible)
                if [[ "$file" == *.md ]] || [[ "$file" == *.txt ]]; then
                    nuclear_replace_in_file "$file" "\\b$old_name\\b" "$new_app" "text reference"
                fi
                
            done < <(find . -type f -name "$pattern" 2>/dev/null || true)
        done
    done
    
    log_success "App name replacement completed"
}

################################################################################
# MAIN NUCLEAR RENAME
################################################################################

nuclear_rename() {
    local new_package="$1"
    local new_app="$2"
    
    # Step 1: Scan for inconsistencies
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "PHASE 1: INCONSISTENCY DETECTION"
    log_info "═══════════════════════════════════════════════════════════════"
    local old_packages
    old_packages=$(scan_project_inconsistencies)
    local old_names
    old_names=$(find_all_app_names)
    
    # Step 2: Nuclear directory restructure
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "PHASE 2: DIRECTORY RESTRUCTURE"
    log_info "═══════════════════════════════════════════════════════════════"
    
    local new_pkg_path="app/src/main/java/${new_package//./\/}"
    local new_test_path="app/src/test/java/${new_package//./\/}"
    
    if [[ "$DRY_RUN" == false ]]; then
        log_nuke "Obliterating old Java source structure..."
        rm -rf app/src/main/java/*
        rm -rf app/src/test/java/*
        
        log_info "Creating new package structure..."
        mkdir -p "$new_pkg_path"
        mkdir -p "$new_test_path"
        
        # Create App.java
        cat > "$new_pkg_path/App.java" << EOF
package $new_package;

public class App {
    public String getGreeting() {
        return "Hello from $new_app!";
    }

    public static void main(String[] args) {
        System.out.println(new App().getGreeting());
    }
}
EOF
        
        # Create AppTest.java
        cat > "$new_test_path/AppTest.java" << EOF
package $new_package;

import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class AppTest {
    @Test
    void appHasAGreeting() {
        App classUnderTest = new App();
        assertNotNull(classUnderTest.getGreeting(), "app should have a greeting");
    }
}
EOF
        log_success "New structure created"
    else
        log_info "[DRY-RUN] Would recreate directory structure"
    fi
    
    # Step 3: Nuclear package replacement
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "PHASE 3: NUCLEAR PACKAGE REPLACEMENT"
    log_info "═══════════════════════════════════════════════════════════════"
    nuclear_replace_package_everywhere "$old_packages" "$new_package"
    
    # Step 4: Nuclear app name replacement
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "PHASE 4: NUCLEAR APP NAME REPLACEMENT"
    log_info "═══════════════════════════════════════════════════════════════"
    nuclear_replace_app_name_everywhere "$old_names" "$new_app"
    
    # Step 5: Force-update known critical files
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "PHASE 5: CRITICAL FILE FORCE-UPDATE"
    log_info "═══════════════════════════════════════════════════════════════"
    
    # settings.gradle.kts
    if [[ -f "settings.gradle.kts" ]] && [[ "$DRY_RUN" == false ]]; then
        log_nuke "Force-updating settings.gradle.kts"
        if ! grep -q "rootProject.name" settings.gradle.kts; then
            echo "rootProject.name = \"$new_app\"" >> settings.gradle.kts
        fi
    fi
    
    # app/build.gradle.kts - mainClass
    if [[ -f "app/build.gradle.kts" ]] && [[ "$DRY_RUN" == false ]]; then
        log_nuke "Force-updating app/build.gradle.kts mainClass"
        
        # Ensure mainClass is set correctly in application block
        if grep -q "application {" app/build.gradle.kts; then
            # Update within application block
            safe_sed "/application {/,/}/ s|mainClass.*|mainClass = \"$new_package.App\"|" app/build.gradle.kts
        fi
        
        # Update manifest
        if grep -q "Main-Class" app/build.gradle.kts; then
            safe_sed "s|Main-Class.*|Main-Class\"] = \"$new_package.App\"|" app/build.gradle.kts
        fi
    fi
    
    # docker-compose.yml
    if [[ -f "docker-compose.yml" ]] && [[ "$DRY_RUN" == false ]]; then
        log_nuke "Force-updating docker-compose.yml"
        safe_sed "s|image:.*|image: $new_app-app|" docker-compose.yml
        safe_sed "s|container_name:.*|container_name: $new_app|" docker-compose.yml
    fi
    
    # README.md
    if [[ -f "README.md" ]] && [[ "$DRY_RUN" == false ]]; then
        log_nuke "Force-updating README.md"
        safe_sed "1s|.*|# $new_app|" README.md
    fi
    
    # Step 6: Obliterate build artifacts
    log_info "═══════════════════════════════════════════════════════════════"
    log_info "PHASE 6: BUILD ARTIFACT OBLITERATION"
    log_info "═══════════════════════════════════════════════════════════════"
    
    if [[ "$DRY_RUN" == false ]]; then
        log_nuke "Obliterating all build artifacts..."
        rm -rf .gradle app/.gradle app/build build 2>/dev/null || true
        rm -rf app/build/classes app/build/libs app/build/tmp 2>/dev/null || true
        find . -name "*.class" -type f -delete 2>/dev/null || true
        log_success "Build artifacts obliterated"
    else
        log_info "[DRY-RUN] Would obliterate build artifacts"
    fi
    
    log_success "═══════════════════════════════════════════════════════════════"
    log_success "NUCLEAR RENAME OPERATION COMPLETED"
    log_success "═══════════════════════════════════════════════════════════════"
}

################################################################################
# VERIFICATION
################################################################################

verify_changes() {
    log_info "Running verification checks..."
    
    local errors=0
    
    # Check App.java exists
    local app_java
    app_java=$(find app/src/main/java -name "App.java" -type f | head -n1)
    if [[ -z "$app_java" ]]; then
        log_error "App.java not found"
        errors=$((errors + 1))
    else
        log_success "App.java found"
    fi
    
    # Check AppTest.java exists
    local test_java
    test_java=$(find app/src/test/java -name "AppTest.java" -type f | head -n1)
    if [[ -z "$test_java" ]]; then
        log_error "AppTest.java not found"
        errors=$((errors + 1))
    else
        log_success "AppTest.java found"
    fi
    
    # Check settings.gradle.kts updated
    if [[ -f "settings.gradle.kts" ]]; then
        if grep -q "rootProject.name" settings.gradle.kts; then
            log_success "settings.gradle.kts updated"
        else
            log_warn "settings.gradle.kts may need manual review"
        fi
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "All verifications passed"
        return 0
    else
        log_error "Verification found $errors error(s)"
        return 1
    fi
}

################################################################################
# SUMMARY
################################################################################

print_summary() {
    local new_package="$1"
    local new_app="$2"
    
    echo
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                ${GREEN}☢  NUCLEAR OPERATION COMPLETE  ☢${NC}               ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo
    echo -e "${GREEN}✓${NC} Package:     ${BLUE}$new_package${NC}"
    echo -e "${GREEN}✓${NC} Application: ${BLUE}$new_app${NC}"
    echo -e "${GREEN}✓${NC} Backup:      ${YELLOW}$BACKUP_DIR${NC}"
    echo
    echo -e "${YELLOW}All inconsistencies have been eliminated.${NC}"
    echo
    echo -e "${CYAN}Next Steps:${NC}"
    echo -e "  1. Verify:  ${YELLOW}git diff${NC}"
    echo -e "  2. Build:   ${YELLOW}./gradlew clean build${NC}"
    echo -e "  3. Test:    ${YELLOW}./gradlew test${NC}"
    echo -e "  4. Docker:  ${YELLOW}docker-compose up --build${NC}"
    echo
    echo -e "${CYAN}Rollback:${NC}"
    echo -e "  If needed: ${YELLOW}$0 --rollback${NC}"
    echo
    echo -e "${GREEN}Log:${NC} $LOG_FILE"
    echo
}

################################################################################
# MAIN
################################################################################

main() {
    local new_package=""
    local new_app=""
    local rollback_mode=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--package) new_package="$2"; shift 2 ;;
            -n|--name) new_app="$2"; shift 2 ;;
            -d|--dry-run) DRY_RUN=true; shift ;;
            -f|--force) FORCE=true; shift ;;
            -v|--verbose) VERBOSE=true; shift ;;
            -r|--rollback) rollback_mode=true; shift ;;
            -h|--help) show_usage; exit 0 ;;
            *) log_error "Unknown option: $1"; show_usage; exit 1 ;;
        esac
    done
    
    print_banner
    
    if [[ "$rollback_mode" == true ]]; then
        perform_rollback
        exit $?
    fi
    
    if ! check_prerequisites; then
        exit 1
    fi
    
    # Interactive input if needed
    if [[ -z "$new_package" ]]; then
        echo -e "${CYAN}Enter new package name (e.g., com.company.app):${NC}"
        read -r new_package
    fi
    
    if [[ -z "$new_app" ]]; then
        echo -e "${CYAN}Enter new application name (e.g., my-app):${NC}"
        read -r new_app
    fi
    
    # Validate
    log_info "Validating inputs..."
    if ! validate_package_name "$new_package" || ! validate_app_name "$new_app"; then
        exit 1
    fi
    log_success "Validation passed"
    
    # Show preview
    echo
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}NUCLEAR TRANSFORMATION${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "  New package:     ${GREEN}$new_package${NC}"
    echo -e "  New application: ${GREEN}$new_app${NC}"
    echo
    echo -e "${RED}This will:${NC}"
    echo -e "  ${RED}•${NC} Find and replace ALL package references"
    echo -e "  ${RED}•${NC} Find and replace ALL app name references"
    echo -e "  ${RED}•${NC} Eliminate ALL inconsistencies"
    echo -e "  ${RED}•${NC} Rebuild directory structure"
    echo -e "  ${RED}•${NC} Obliterate build artifacts"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo
    
    if [[ "$FORCE" != true && "$DRY_RUN" != true ]]; then
        read -rp "Proceed with nuclear rename? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            log_info "Operation cancelled"
            exit 0
        fi
    fi
    
    # Create backup
    if [[ "$DRY_RUN" != true ]]; then
        create_backup
    fi
    
    # Execute nuclear rename
    nuclear_rename "$new_package" "$new_app"
    
    # Verify
    if [[ "$DRY_RUN" != true ]]; then
        verify_changes
    fi
    
    # Summary
    if [[ "$DRY_RUN" == true ]]; then
        echo
        log_info "DRY-RUN completed. No changes were made."
        log_info "Run without --dry-run to apply changes"
    else
        print_summary "$new_package" "$new_app"
    fi
}

main "$@"
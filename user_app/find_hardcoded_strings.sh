#!/bin/bash

# Script to find hardcoded strings in Flutter/Dart code that should be translated
# Usage: ./find_hardcoded_strings.sh [OPTIONS]

set -e

# Default search directory
SEARCH_DIR="lib"
TRANSLATIONS_DIR="lib/app/translations"
OUTPUT_FILE=""
MIN_LENGTH=3
EXCLUDE_TECHNICAL=true
INCLUDE_SINGLE_WORDS=false
SHOW_CONTEXT=false
VERBOSE=false
COMPACT_MODE=false

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Function to print colored output
print_error() {
    echo -e "${RED}Error: $1${NC}" >&2
}

print_success() {
    echo -e "${GREEN}$1${NC}"
}

print_warning() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

print_info() {
    echo -e "${BLUE}$1${NC}"
}

print_header() {
    echo -e "${BOLD}${CYAN}$1${NC}"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Find hardcoded strings in Flutter/Dart code that should be translated."
    echo ""
    echo "OPTIONS:"
    echo "  --dir DIR               Search directory (default: lib)"
    echo "  --min-length N          Minimum string length (default: 3)"
    echo "  --include-technical     Include technical strings (URLs, file paths, etc.)"
    echo "  --include-single        Include single words"
    echo "  --context               Show surrounding context for each match"
    echo "  --compact               Show compact format (file:line only)"
    echo "  --output FILE           Save results to file"
    echo "  --verbose               Show detailed information"
    echo "  --help, -h              Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0                                    # Basic scan"
    echo "  $0 --min-length 5 --context          # Longer strings with context"
    echo "  $0 --compact                          # Show only file:line format"
    echo "  $0 --include-single --output report.txt  # Include single words, save to file"
    echo "  $0 --dir lib/modules --verbose        # Scan specific directory with details"
    echo ""
    echo "STRING TYPES DETECTED:"
    echo "  • Text() widget strings"
    echo "  • AppBar title strings"
    echo "  • Button text"
    echo "  • Snackbar messages"
    echo "  • Dialog content"
    echo "  • Error messages"
    echo "  • Form labels and hints"
    echo ""
}

# Function to parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dir)
                SEARCH_DIR="$2"
                shift 2
                ;;
            --min-length)
                MIN_LENGTH="$2"
                shift 2
                ;;
            --include-technical)
                EXCLUDE_TECHNICAL=false
                shift
                ;;
            --include-single)
                INCLUDE_SINGLE_WORDS=true
                shift
                ;;
            --context)
                SHOW_CONTEXT=true
                shift
                ;;
            --compact)
                COMPACT_MODE=true
                shift
                ;;
            --output)
                OUTPUT_FILE="$2"
                shift 2
                ;;
            --verbose)
                VERBOSE=true
                shift
                ;;
            --help|-h)
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
}

# Function to check if a string is already translated
is_already_translated() {
    local string="$1"
    local escaped_string=$(echo "$string" | sed 's/[]\/$*.^[()|+?{]/\\&/g')
    
    # Check if it exists in translation files
    if [ -d "$TRANSLATIONS_DIR" ]; then
        if grep -r -q "\"[^\"]*\": \"$escaped_string\"" "$TRANSLATIONS_DIR" 2>/dev/null; then
            return 0  # Already translated
        fi
    fi
    
    return 1  # Not translated
}

# Function to check if a string should be excluded
should_exclude_string() {
    local string="$1"
    local length=${#string}
    
    # Check minimum length
    if [ $length -lt $MIN_LENGTH ]; then
        return 0  # Exclude
    fi
    
    # Check for single words if not included
    if [ "$INCLUDE_SINGLE_WORDS" = false ]; then
        if [[ ! "$string" =~ [[:space:]] ]]; then
            return 0  # Exclude single words
        fi
    fi
    
    # Check technical strings if excluded
    if [ "$EXCLUDE_TECHNICAL" = true ]; then
        # URLs, file paths, technical identifiers
        if [[ "$string" =~ ^https?:// ]] || \
           [[ "$string" =~ ^/ ]] || \
           [[ "$string" =~ \.(dart|json|yaml|xml|png|jpg|svg)$ ]] || \
           [[ "$string" =~ ^[a-zA-Z0-9_]+\.[a-zA-Z0-9_]+$ ]] || \
           [[ "$string" =~ ^[0-9]+(\.[0-9]+)*$ ]] || \
           [[ "$string" =~ ^#[0-9a-fA-F]{6,8}$ ]] || \
           [[ "$string" =~ ^[A-Z][A-Z_]+$ ]] || \
           [[ "$string" =~ ^(true|false|null)$ ]] || \
           [[ "$string" =~ ^(GET|POST|PUT|DELETE|PATCH)$ ]] || \
           [[ "$string" =~ ^(http|https|ftp|file)$ ]] || \
           [[ "$string" =~ ^[a-zA-Z0-9_-]+@[a-zA-Z0-9_-]+$ ]]; then
            return 0  # Exclude technical strings
        fi
    fi
    
    return 1  # Don't exclude
}

# Function to get context around a match
get_context() {
    local file="$1"
    local line_num="$2"
    local context_lines=2
    
    local start_line=$((line_num - context_lines))
    local end_line=$((line_num + context_lines))
    
    [ $start_line -lt 1 ] && start_line=1
    
    echo "    Context:"
    sed -n "${start_line},${end_line}p" "$file" | nl -v$start_line -w4 -s': ' | \
    while IFS= read -r line; do
        local current_line=$(echo "$line" | cut -d':' -f1 | tr -d ' ')
        if [ "$current_line" = "$line_num" ]; then
            echo -e "    ${YELLOW}$line${NC}"
        else
            echo "    $line"
        fi
    done
}

# Function to find hardcoded strings in Dart files
find_hardcoded_strings() {
    local total_files=0
    local files_with_strings=0
    local total_strings=0
    local translatable_strings=0
    
    # Create output header
    local output=""
    output+="\n$(print_header "=== HARDCODED STRINGS REPORT ===")\n"
    output+="Search Directory: $SEARCH_DIR\n"
    output+="Minimum Length: $MIN_LENGTH characters\n"
    output+="Technical Strings: $([ "$EXCLUDE_TECHNICAL" = true ] && echo "Excluded" || echo "Included")\n"
    output+="Single Words: $([ "$INCLUDE_SINGLE_WORDS" = true ] && echo "Included" || echo "Excluded")\n"
    output+="\n"
    
    if [ "$VERBOSE" = true ]; then
        print_info "Starting search in: $SEARCH_DIR"
        print_info "Patterns: Text(), AppBar(), Button(), Dialog(), Snackbar()"
    fi
    
    # Process each Dart file
    while IFS= read -r -d '' file; do
        [ "$VERBOSE" = true ] && echo -n "."
        total_files=$((total_files + 1))
        local file_has_strings=false
        local file_strings=0
        local file_output=""
        
        # Process different patterns and collect results
        local temp_results=$(mktemp)
        
        # Search for different patterns
        grep -n "Text(" "$file" 2>/dev/null | grep -v "\.tr" | grep "['\"][^'\"]*['\"]" >> "$temp_results" || true
        grep -n "title:" "$file" 2>/dev/null | grep -v "\.tr" | grep "['\"][^'\"]*['\"]" >> "$temp_results" || true
        grep -n "child:.*Text(" "$file" 2>/dev/null | grep -v "\.tr" | grep "['\"][^'\"]*['\"]" >> "$temp_results" || true
        grep -n "Get\.snackbar(" "$file" 2>/dev/null | grep "['\"][^'\"]*['\"]" >> "$temp_results" || true
        grep -n "labelText:" "$file" 2>/dev/null | grep "['\"][^'\"]*['\"]" >> "$temp_results" || true
        grep -n "hintText:" "$file" 2>/dev/null | grep "['\"][^'\"]*['\"]" >> "$temp_results" || true
        grep -n "errorText:" "$file" 2>/dev/null | grep "['\"][^'\"]*['\"]" >> "$temp_results" || true
        grep -n "throw.*Exception(" "$file" 2>/dev/null | grep "['\"][^'\"]*['\"]" >> "$temp_results" || true
        
        # Remove duplicates while preserving order
        if [ -s "$temp_results" ]; then
            sort -u "$temp_results" > "$temp_results.tmp"
            mv "$temp_results.tmp" "$temp_results"
        fi
        
        # Debug output
        if [ "$VERBOSE" = true ] && [ -s "$temp_results" ]; then
            echo "Debug: Found patterns in $file:" >&2
            cat "$temp_results" >&2
            echo "---" >&2
        fi
        
        # Process each line from temp results
        if [ -s "$temp_results" ]; then
            # Track processed strings to avoid duplicates
            local processed_strings=$(mktemp)
            
            while IFS=: read -r line_num line_content; do
                if [ -n "$line_num" ] && [ -n "$line_content" ]; then
                    # Extract quoted strings from this line
                    local extracted_strings=$(echo "$line_content" | grep -o "['\"][^'\"]*['\"]" | sed "s/^['\"]//; s/['\"]$//")
                    
                    while IFS= read -r string_line; do
                        if [ -n "$string_line" ]; then
                            # Create unique key for this string + line combination
                            local unique_key="${line_num}:${string_line}"
                            
                            # Skip if already processed
                            if grep -q "^${unique_key}$" "$processed_strings" 2>/dev/null; then
                                continue
                            fi
                            echo "$unique_key" >> "$processed_strings"
                            
                            if should_exclude_string "$string_line"; then
                                continue
                            fi
                            
                            total_strings=$((total_strings + 1))
                            
                            # Check if already translated
                            local status="NOT TRANSLATED"
                            local color="$RED"
                            if is_already_translated "$string_line"; then
                                status="ALREADY TRANSLATED"
                                color="$GREEN"
                            else
                                translatable_strings=$((translatable_strings + 1))
                            fi
                            
                            file_strings=$((file_strings + 1))
                            
                            if [ "$COMPACT_MODE" = true ]; then
                                # Compact mode: just file:line and string
                                if [ "$status" = "NOT TRANSLATED" ]; then
                                    file_output+="$(echo -e "${CYAN}$file:$line_num${NC}") \"$string_line\"\n"
                                fi
                            else
                                # Add file header if this is first string for this file
                                if [ "$file_has_strings" = false ]; then
                                    file_output+="\n$(print_header "📁 $file")\n"
                                    file_has_strings=true
                                fi
                                
                                file_output+="  $(echo -e "${CYAN}$file:$line_num${NC}") - $(echo -e "${color}$status${NC}")\n"
                                file_output+="    String: \"$string_line\"\n"
                                file_output+="    Pattern: $(echo "$line_content" | sed 's/^[[:space:]]*//')\n"
                                
                                if [ "$SHOW_CONTEXT" = true ]; then
                                    file_output+="$(get_context "$file" "$line_num")\n"
                                fi
                                file_output+="\n"
                            fi
                            
                            # Set file_has_strings for non-compact mode
                            if [ "$COMPACT_MODE" = false ]; then
                                file_has_strings=true
                            else
                                # For compact mode, only set if we have untranslated strings
                                if [ "$status" = "NOT TRANSLATED" ]; then
                                    file_has_strings=true
                                fi
                            fi
                        fi
                    done <<< "$extracted_strings"
                fi
            done < "$temp_results"
            
            rm -f "$processed_strings"
        fi
        
        # Clean up
        rm -f "$temp_results"
        
        if [ "$file_has_strings" = true ]; then
            output+="$file_output"
            if [ "$COMPACT_MODE" = false ]; then
                output+="  → Found $file_strings hardcoded strings in this file\n\n"
            fi
            files_with_strings=$((files_with_strings + 1))
        fi
        
    done < <(find "$SEARCH_DIR" -name "*.dart" -not -path "*/translations/*" -print0)
    
    [ "$VERBOSE" = true ] && echo ""
    
    # Generate summary
    output+="\n$(print_header "📊 SUMMARY")\n"
    output+="Files scanned: $total_files\n"
    output+="Files with hardcoded strings: $files_with_strings\n"
    output+="Total hardcoded strings found: $total_strings\n"
    output+="Strings needing translation: $(echo -e "${RED}$translatable_strings${NC}")\n"
    output+="Strings already translated: $(echo -e "${GREEN}$((total_strings - translatable_strings))${NC}")\n"
    
    if [ $translatable_strings -gt 0 ]; then
        output+="\n$(print_header "🔧 RECOMMENDATIONS")\n"
        output+="1. Review the strings marked as 'NOT TRANSLATED'\n"
        output+="2. Use './add_translation.sh' to add translations for User-facing text\n"
        output+="3. Replace hardcoded strings with AppTranslationKey references\n"
        output+="4. Consider using --include-technical flag if needed\n"
    else
        output+="\n$(print_success "✅ Great! All User-facing strings appear to be translated!")\n"
    fi
    
    # Output results
    if [ -n "$OUTPUT_FILE" ]; then
        echo -e "$output" > "$OUTPUT_FILE"
        print_success "Results saved to: $OUTPUT_FILE"
        print_info "Found $translatable_strings strings that need translation"
    else
        echo -e "$output"
    fi
    
    return $translatable_strings
}


# Function to validate search directory
validate_directory() {
    if [ ! -d "$SEARCH_DIR" ]; then
        print_error "Search directory '$SEARCH_DIR' does not exist"
        exit 1
    fi
    
    local dart_files=$(find "$SEARCH_DIR" -name "*.dart" | wc -l)
    if [ "$dart_files" -eq 0 ]; then
        print_warning "No Dart files found in '$SEARCH_DIR'"
        exit 1
    fi
    
    if [ "$VERBOSE" = true ]; then
        print_info "Found $dart_files Dart files to scan"
    fi
}

# Main execution
main() {
    parse_arguments "$@"
    validate_directory
    
    print_header "🔍 Scanning for hardcoded strings..."
    find_hardcoded_strings
    local exit_code=$?
    
    if [ $exit_code -gt 0 ]; then
        print_warning "Found $exit_code strings that need translation"
        exit 1
    else
        print_success "No untranslated strings found!"
        exit 0
    fi
}

# Check if script is being executed (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
#!/usr/bin/env bash

# Unified logging functions for consistent output
# Requires colors.sh to be sourced first

# Get script directory for sourcing colors
readonly LOGGING_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LOGGING_LIB_DIR/colors.sh"

log_error() {
    echo -e "${COLOR_ERROR}❌ ERROR: $1${COLOR_RESET}" >&2
}

log_success() {
    echo -e "${COLOR_SUCCESS}✅ $1${COLOR_RESET}"
}

log_warning() {
    echo -e "${COLOR_WARNING}⚠️  WARNING: $1${COLOR_RESET}"
}

log_info() {
    echo -e "${COLOR_INFO}ℹ️  $1${COLOR_RESET}"
}

log_header() {
    echo -e "${COLOR_HEADER}🚀 $1${COLOR_RESET}"
}

log_step() {
    echo -e "${COLOR_INFO}📋 Step: $1${COLOR_RESET}"
}

log_debug() {
    if [[ "${DEBUG:-}" == "true" ]]; then
        echo -e "${CYAN}🐛 DEBUG: $1${COLOR_RESET}" >&2
    fi
}
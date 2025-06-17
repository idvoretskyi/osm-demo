#!/usr/bin/env bash

# Color definitions for consistent output across all scripts
# Source this file to use color variables

# Only define colors if not already defined
if [[ -z "${RED:-}" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly PURPLE='\033[0;35m'
    readonly CYAN='\033[0;36m'
    readonly WHITE='\033[1;37m'
    readonly NC='\033[0m' # No Color

    # Aliases for semantic coloring
    readonly COLOR_ERROR="$RED"
    readonly COLOR_SUCCESS="$GREEN"
    readonly COLOR_WARNING="$YELLOW"
    readonly COLOR_INFO="$BLUE"
    readonly COLOR_HEADER="$PURPLE"
    readonly COLOR_RESET="$NC"
fi
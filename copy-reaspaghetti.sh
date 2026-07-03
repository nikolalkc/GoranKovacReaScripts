#!/usr/bin/env bash
# Script to copy ReaSpaghetti folder from source to destination with overwrite
# Reads paths from local config file

set -euo pipefail

CONFIG_PATH="${1:-copy-config.json}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ ! -f "$CONFIG_PATH" ]; then
    echo -e "${RED}Error: Config file not found at $CONFIG_PATH${NC}"
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}Error: 'python3' is required to parse the config file but was not found${NC}"
    exit 1
fi

if ! sourceFolder=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['sourceFolder'])" "$CONFIG_PATH" 2>/dev/null); then
    echo -e "${RED}Error: Failed to parse config file${NC}"
    exit 1
fi

if ! destinationFolder=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['destinationFolder'])" "$CONFIG_PATH" 2>/dev/null); then
    echo -e "${RED}Error: Failed to parse config file${NC}"
    exit 1
fi

if [ ! -d "$sourceFolder" ]; then
    echo -e "${RED}Error: Source folder not found: $sourceFolder${NC}"
    exit 1
fi

echo -e "${GREEN}Copying ReaSpaghetti folder...${NC}"
echo "From: $sourceFolder"
echo "To:   $destinationFolder"
echo ""

if [ -d "$destinationFolder" ]; then
    echo -e "${YELLOW}Destination folder exists. Removing old version...${NC}"
    rm -rf "$destinationFolder"
fi

parentPath=$(dirname "$destinationFolder")
if [ ! -d "$parentPath" ]; then
    mkdir -p "$parentPath"
fi

if ! rsync -a --exclude='.gitignore' "$sourceFolder"/ "$destinationFolder"/; then
    echo -e "${RED}Error: Failed to copy folder${NC}"
    exit 1
fi

echo -e "${GREEN}Successfully copied ReaSpaghetti folder!${NC}"

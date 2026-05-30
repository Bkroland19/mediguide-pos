#!/bin/bash

# PocketBase Type Generation Script
# This script generates TypeScript types from your PocketBase instance

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🔄 Generating PocketBase types...${NC}"

# Load environment variables from .env.local when present
if [ -f .env.local ]; then
    export $(grep -v '^#' .env.local | xargs)
fi

# Check required environment variables
if [ -z "$NEXT_PUBLIC_POCKETBASE_URL" ] || [ -z "$POCKETBASE_ADMIN_EMAIL" ] || [ -z "$POCKETBASE_ADMIN_PASSWORD" ]; then
    echo -e "${RED}❌ Missing required environment variables!${NC}"
    echo "Please ensure these are set in your shell or in .env.local:"
    echo "- NEXT_PUBLIC_POCKETBASE_URL"
    echo "- POCKETBASE_ADMIN_EMAIL"
    echo "- POCKETBASE_ADMIN_PASSWORD"
    exit 1
fi

# Create types directory
mkdir -p types

# Generate types using npx (no need to install globally)
echo -e "${YELLOW}📡 Connecting to PocketBase at: $NEXT_PUBLIC_POCKETBASE_URL${NC}"

npx pocketbase-typegen \
    --url "$NEXT_PUBLIC_POCKETBASE_URL" \
    --email "$POCKETBASE_ADMIN_EMAIL" \
    --password "$POCKETBASE_ADMIN_PASSWORD" \
    --out types/pocketbase-types.ts

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ PocketBase types generated successfully!${NC}"
    echo -e "${GREEN}📁 Types saved to: types/pocketbase-types.ts${NC}"
    echo ""
    echo -e "${YELLOW}📋 Generated file:${NC}"
    ls -la types/pocketbase-types.ts
else
    echo -e "${RED}❌ Failed to generate PocketBase types!${NC}"
    echo "Please check your credentials and PocketBase URL."
    exit 1
fi

#!/bin/bash
set -e

# Build script for the main website
echo "Building Plasmatic Website"
echo "========================="

# Check if website directory exists
WEBSITE_DIR="../website"
if [ ! -d "$WEBSITE_DIR" ]; then
    echo "Error: Website directory not found at $WEBSITE_DIR"
    exit 1
fi

# Navigate to website directory
cd $WEBSITE_DIR

# Check for node
if ! command -v node &> /dev/null; then
    echo "Error: Node.js is not installed"
    exit 1
fi

echo "Node version: $(node --version)"
echo "NPM version: $(npm --version)"

# Install dependencies
echo ""
echo "Installing dependencies..."
npm ci

# Build the website
echo ""
echo "Building website..."
npm run build

# Check if build was successful
if [ ! -d "build" ]; then
    echo "Error: Build directory not created"
    exit 1
fi

echo ""
echo "Build completed successfully!"
echo "Build output in: $WEBSITE_DIR/build"

# Return to original directory
cd -
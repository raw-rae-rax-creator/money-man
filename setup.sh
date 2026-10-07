#!/bin/bash

echo "🚀 Setting up Money Manager Xcode Project..."
echo ""

# Check if xcodegen is installed
if ! command -v xcodegen &> /dev/null; then
    echo "⚠️  Xcodegen is not installed. Installing..."
    echo "Run: brew install xcodegen"
    echo ""
    echo "Alternatively, you can:"
    echo "1. Open Xcode"
    echo "2. File > New > Project > iOS App"
    echo "3. Name: MoneyManager"
    echo "4. Interface: SwiftUI"
    echo "5. Language: Swift"
    echo "6. Then drag all .swift files into the project"
    echo ""
    exit 1
fi

# Generate project
echo "📦 Generating Xcode project with Xcodegen..."
xcodegen generate

echo "✅ Project generated successfully!"
echo ""
echo "📱 Open MoneyManager.xcodeproj in Xcode and run!"

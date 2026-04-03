#!/bin/bash
set -e

echo "🚀 STACK USDT - Combined Build Script"
echo "======================================"

# Step 1: Build Flutter Web
echo ""
echo "📱 Step 1: Building Flutter Web..."
cd "$(dirname "$0")/../../stack_frontend"
flutter build web --release --base-href "/"
echo "✅ Flutter Web build complete"

# Step 2: Copy Flutter build to backend
echo ""
echo "📦 Step 2: Copying Flutter build to backend..."
FRONTEND_BUILD="$(dirname "$0")/../../stack_frontend/build/web"
BACKEND_STATIC="$(dirname "$0")/frontend_build"

rm -rf "$BACKEND_STATIC"
mkdir -p "$BACKEND_STATIC"
cp -r "$FRONTEND_BUILD"/* "$BACKEND_STATIC/"
echo "✅ Frontend copied to backend/frontend_build/"

# Step 3: Build TypeScript
echo ""
echo "⚙️ Step 3: Building TypeScript backend..."
cd "$(dirname "$0")"
npm install
npm run build
echo "✅ TypeScript build complete"

echo ""
echo "🎉 Build complete! Start with: node dist/index.js"

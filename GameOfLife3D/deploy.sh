#!/bin/bash

# GameOfLife3D Deployment Script
# For DreamHost VPS deployment

# Configuration
SERVER="vps66522.dreamhostps.com"
USER="your_username"  # Replace with your actual username
REMOTE_PATH="/path/to/your/domain/"  # Replace with your actual domain path

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 GameOfLife3D Deployment Script${NC}"
echo "================================"

# Check if build exists
if [ ! -d "dist" ]; then
    echo -e "${YELLOW}⚠️  No dist folder found. Building project...${NC}"
    npm run build
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Build failed. Please fix errors and try again.${NC}"
        exit 1
    fi
fi

# Create deployment directory
echo -e "${YELLOW}📦 Preparing deployment files...${NC}"
mkdir -p deploy_temp

# Copy essential files
cp index.html deploy_temp/
cp styles.css deploy_temp/
cp -r dist/ deploy_temp/
mkdir -p deploy_temp/node_modules/three/build/
cp node_modules/three/build/three.module.js deploy_temp/node_modules/three/build/

# Optional: Create a simple PHP file for better MIME types (if needed)
cat > deploy_temp/.htaccess << 'EOF'
# Enable ES6 modules
AddType application/javascript .js
AddType application/javascript .mjs

# Enable compression
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/css application/javascript
</IfModule>

# Cache static assets
<IfModule mod_expires.c>
    ExpiresActive on
    ExpiresByType application/javascript "access plus 1 month"
    ExpiresByType text/css "access plus 1 month"
</IfModule>
EOF

echo -e "${YELLOW}🌐 Uploading to server...${NC}"

# Upload files using rsync
rsync -avz --progress deploy_temp/ ${USER}@${SERVER}:${REMOTE_PATH}

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Deployment successful!${NC}"
    echo -e "${GREEN}🌍 Your GameOfLife3D should now be available at your domain${NC}"

    # Cleanup
    rm -rf deploy_temp
    echo -e "${YELLOW}🧹 Cleaned up temporary files${NC}"
else
    echo -e "${RED}❌ Deployment failed. Please check your server credentials and path.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}🎉 Deployment complete!${NC}"
echo "================================"
echo "Next steps:"
echo "1. Update the USER and REMOTE_PATH variables in this script"
echo "2. Ensure your server supports ES6 modules"
echo "3. Test the application in your browser"
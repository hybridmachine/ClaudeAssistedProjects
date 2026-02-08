#!/bin/bash

# PlasmaBall3D Deployment Script

# Configuration
SERVER="hybridmachine.com"
REMOTE_PATH="hybridmachine.com/plasmaball3d/"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}PlasmaBall3D Deployment Script${NC}"
echo "================================"

# Always build
echo -e "${YELLOW}Building project...${NC}"
npm run build
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed. Please fix errors and try again.${NC}"
    exit 1
fi

# Create deployment directory
echo -e "${YELLOW}Preparing deployment files...${NC}"
rm -rf deploy_temp
mkdir -p deploy_temp

# Copy essential files
cp index.html deploy_temp/
cp styles.css deploy_temp/
cp -r dist/ deploy_temp/

# Copy Three.js runtime files
mkdir -p deploy_temp/node_modules/three/build/
cp node_modules/three/build/three.module.js deploy_temp/node_modules/three/build/

# Copy Three.js addons (post-processing)
mkdir -p deploy_temp/node_modules/three/examples/jsm/postprocessing/
cp node_modules/three/examples/jsm/postprocessing/EffectComposer.js deploy_temp/node_modules/three/examples/jsm/postprocessing/
cp node_modules/three/examples/jsm/postprocessing/RenderPass.js deploy_temp/node_modules/three/examples/jsm/postprocessing/
cp node_modules/three/examples/jsm/postprocessing/UnrealBloomPass.js deploy_temp/node_modules/three/examples/jsm/postprocessing/
cp node_modules/three/examples/jsm/postprocessing/OutputPass.js deploy_temp/node_modules/three/examples/jsm/postprocessing/
cp node_modules/three/examples/jsm/postprocessing/Pass.js deploy_temp/node_modules/three/examples/jsm/postprocessing/
cp node_modules/three/examples/jsm/postprocessing/ShaderPass.js deploy_temp/node_modules/three/examples/jsm/postprocessing/
cp node_modules/three/examples/jsm/postprocessing/MaskPass.js deploy_temp/node_modules/three/examples/jsm/postprocessing/

# Copy shader dependencies used by bloom
mkdir -p deploy_temp/node_modules/three/examples/jsm/shaders/
cp node_modules/three/examples/jsm/shaders/CopyShader.js deploy_temp/node_modules/three/examples/jsm/shaders/
cp node_modules/three/examples/jsm/shaders/LuminosityHighPassShader.js deploy_temp/node_modules/three/examples/jsm/shaders/
cp node_modules/three/examples/jsm/shaders/OutputShader.js deploy_temp/node_modules/three/examples/jsm/shaders/ 2>/dev/null || true

# Create .htaccess file
cat > deploy_temp/.htaccess << 'EOF'
# Enable ES6 modules
AddType application/javascript .js
AddType application/javascript .mjs

# Enable compression
<IfModule mod_deflate.c>
    AddOutputFilterByType DEFLATE text/html text/css application/javascript
</IfModule>
EOF

echo ""
echo -e "${YELLOW}Creating remote directory...${NC}"
ssh ${SERVER} "mkdir -p ${REMOTE_PATH}"

echo -e "${YELLOW}Uploading files to ${SERVER}...${NC}"
cd deploy_temp
scp -r * .htaccess ${SERVER}:${REMOTE_PATH}
if [ $? -ne 0 ]; then
    echo -e "${RED}Upload failed. Please check your connection and credentials.${NC}"
    cd ..
    rm -rf deploy_temp
    exit 1
fi
cd ..

echo ""
echo -e "${YELLOW}Setting permissions on remote server...${NC}"
ssh ${SERVER} "chmod -R 755 ${REMOTE_PATH}"
if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to set permissions. You may need to do this manually.${NC}"
fi

# Cleanup
rm -rf deploy_temp
echo -e "${YELLOW}Cleaned up temporary files${NC}"

echo ""
echo -e "${GREEN}Deployment complete!${NC}"
echo -e "Visit: https://hybridmachine.com/plasmaball3d/"

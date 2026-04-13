# Testing and Deployment Guide

This guide covers how to test and deploy the **GameOfLife3DWeb.NET** Blazor WebAssembly application.

## 1. Local Development & Testing

### Prerequisites
- [.NET 10.0 SDK](https://dotnet.microsoft.com/download/dotnet/10.0)

### Running Locally
To run the application in development mode:
```bash
cd GameOfLife3DWeb.NET
dotnet watch run
```
This will start a local web server (usually at `https://localhost:7000` or `http://localhost:5000`) and automatically reload when you make changes to the C# or Razor files.

### Manual Verification
- **Engine Logic:** Verify that different rules (Conway, HighLife, etc.) produce expected patterns.
- **Performance:** Check the "Live" cell count in the sidebar. The Three.js `InstancedMesh` is designed to handle 100,000+ cubes, but browser performance may vary by GPU.
- **Responsiveness:** Resize the window to ensure the 3D canvas and sidebar layout adapt correctly.

---

## 2. Production Build

To generate the optimized static files for deployment:
```bash
dotnet publish -c Release
```
The output will be located in:
`bin/Release/net10.0/browser-wasm/publish/wwwroot`

---

## 3. Deployment

Since this is a Standalone Blazor WebAssembly app, it can be hosted on any static web hosting service.

### GitHub Pages (Recommended)
1.  Push the project to a GitHub repository.
2.  Use a GitHub Action to automate the build and deploy:
    - Build using `dotnet publish`.
    - Push the contents of the `wwwroot` folder to the `gh-pages` branch.
    - **Note:** Ensure you have a `.nojekyll` file in the root of your deployment to prevent GitHub Pages from ignoring files starting with underscores (like `_framework`).

### Netlify / Vercel / Azure Static Web Apps
1.  Connect your repository to the service.
2.  Set the build command to: `dotnet publish -c Release -o release`
3.  Set the publish/output directory to: `release/wwwroot`

### Manual Hosting (Any Web Server)
Simply copy the contents of the `publish/wwwroot` folder to your web server's public directory.

---

## 4. Key Dependencies
- **Three.js:** Loaded via CDN in `wwwroot/js/game-renderer.js`.
- **Interop:** Managed via `IJSRuntime` in `Pages/Home.razor`.
- **Assets:** Ensure `wwwroot/css/app.css` and `wwwroot/js/game-renderer.js` are included in your deployment.

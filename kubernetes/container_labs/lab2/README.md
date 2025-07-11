# Multistage Docker Lab 2

This lab demonstrates the benefits of **multistage Docker builds** with a modern Node.js web application.

## 🎯 Learning Objectives

- Understand the difference between single-stage and multistage Docker builds
- Learn how to optimize Docker image sizes
- Practice separating build dependencies from runtime dependencies
- Explore the security benefits of multistage builds

## 📦 Application Overview

This is a modern web application built with:
- **Webpack** for bundling and optimization
- **SCSS** for styling with variables and mixins
- **Babel** for JavaScript transpilation
- **Modern ES6+** JavaScript with classes and modules
- **Responsive design** with CSS Grid and Flexbox

### Build Process Benefits for Multistage Demo

1. **Large Build Dependencies**: ~200MB of node_modules
2. **Complex Build Process**: Webpack bundling, SCSS compilation, JS transpilation
3. **Small Runtime Output**: Just static HTML, CSS, and JS files (~2MB)
4. **Perfect for nginx**: Lightweight web server for static files

## 🚀 Getting Started

### Local Development
```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Build for production
npm run build

# Clean build artifacts
npm run clean
```

### View the App
- **Development**: http://localhost:3000
- **Production**: Serve the `dist/` folder with any web server

## 🐳 Docker Implementation Challenge

Your task is to create a **multistage Dockerfile** that:

### Stage 1: Builder
- Uses a Node.js base image
- Installs all build dependencies
- Runs the webpack build process
- Outputs optimized static files

### Stage 2: Runtime
- Uses a lightweight web server (nginx)
- Copies only the built files from Stage 1
- Serves the application

### Expected Results
- **Single-stage image**: ~300-400MB (includes all node_modules)
- **Multistage image**: ~20-30MB (only runtime files)
- **Size reduction**: 90%+ smaller image!

## 🎨 Application Features

### Interactive Elements
- **Theme Toggle**: Switch between light and dark themes
- **Counter**: Interactive counter with animations
- **Build Info**: Shows build timestamp and environment
- **Responsive Design**: Works on mobile and desktop

### Technical Features
- **Code Splitting**: Webpack optimization
- **CSS Extraction**: Separate CSS files in production
- **Asset Hashing**: Cache-busting with content hashes
- **Minification**: JavaScript and CSS minification
- **Modern JavaScript**: ES6+ features transpiled for compatibility

## 📊 Build Analysis

### Development Build
- Fast compilation for development
- Hot module replacement
- Source maps for debugging
- No minification

### Production Build
- Optimized bundle size
- Minified assets
- Content hashing for caching
- CSS extraction

## 🔧 Configuration Files

- `package.json`: Dependencies and scripts
- `webpack.config.js`: Build configuration
- `.babelrc`: JavaScript transpilation
- `src/`: Source code directory
- `dist/`: Built output directory

## 💡 Multistage Docker Tips

1. **Use specific tags**: `node:18-alpine` vs `node:latest`
2. **Minimize layers**: Combine RUN commands
3. **Leverage cache**: Order instructions by change frequency
4. **Use .dockerignore**: Exclude unnecessary files
5. **Security**: No build tools in production image

## 📖 **Recursos Oficiales de Aprendizaje**

### **🐳 Multistage Builds**
- [Docker Multi-stage Builds](https://docs.docker.com/develop/dev-best-practices/#use-multi-stage-builds) - Guía oficial de builds multistage
- [Dockerfile Best Practices](https://docs.docker.com/develop/dev-best-practices/) - Mejores prácticas oficiales
- [Docker Build Cache](https://docs.docker.com/develop/dev-best-practices/#leverage-build-cache) - Optimización de cache
- [Docker Image Optimization](https://docs.docker.com/develop/dev-best-practices/#keep-images-small) - Reducir tamaño de imágenes

### **🌐 Nginx & Web Servers**
- [Nginx Official Documentation](https://nginx.org/en/docs/) - Documentación completa
- [Nginx Docker Hub](https://hub.docker.com/_/nginx) - Imagen oficial y configuración
- [Nginx Configuration Guide](https://nginx.org/en/docs/beginners_guide.html) - Guía para principiantes
- [Nginx Static Content](https://docs.nginx.com/nginx/admin-guide/web-server/serving-static-content/) - Servir archivos estáticos

### **⚙️ Node.js & Build Tools**
- [Node.js Official Documentation](https://nodejs.org/en/docs/) - Documentación completa
- [npm Documentation](https://docs.npmjs.com/) - Gestión de paquetes
- [Webpack Documentation](https://webpack.js.org/concepts/) - Bundler y optimización
- [Babel Documentation](https://babeljs.io/docs/en/) - Transpilación JavaScript

### **🛠️ Build Optimization**
- [Webpack Production Build](https://webpack.js.org/guides/production/) - Optimización para producción
- [Webpack Code Splitting](https://webpack.js.org/guides/code-splitting/) - División de código
- [npm ci vs npm install](https://docs.npmjs.com/cli/v8/commands/npm-ci) - Instalación en CI/CD
- [Docker .dockerignore](https://docs.docker.com/engine/reference/builder/#dockerignore-file) - Exclusión de archivos

### **🔒 Security & Best Practices**
- [Docker Security Best Practices](https://docs.docker.com/engine/security/security/) - Seguridad en containers
- [Alpine Linux Security](https://wiki.alpinelinux.org/wiki/Alpine_Linux:Security) - Seguridad en Alpine
- [Node.js Security Best Practices](https://nodejs.org/en/docs/guides/security/) - Seguridad en Node.js
- [npm Security](https://docs.npmjs.com/auditing-package-dependencies-for-security-vulnerabilities) - Auditoría de seguridad

### **📊 Performance & Monitoring**
- [Docker Image Analysis](https://docs.docker.com/engine/reference/commandline/history/) - Análisis de imágenes
- [Webpack Bundle Analyzer](https://github.com/webpack-contrib/webpack-bundle-analyzer) - Análisis de bundles
- [Docker Stats](https://docs.docker.com/engine/reference/commandline/stats/) - Monitoreo de recursos
- [Nginx Performance Tuning](https://www.nginx.com/blog/tuning-nginx/) - Optimización de rendimiento

### **🎯 Practical Examples**
- [Docker Samples](https://github.com/dockersamples) - Ejemplos oficiales
- [Nginx Demos](https://github.com/nginxinc/NGINX-Demos) - Demos de configuración
- [Node.js Docker Examples](https://github.com/nodejs/docker-node/tree/main/docs) - Ejemplos oficiales Node.js
- [Webpack Examples](https://github.com/webpack/webpack/tree/main/examples) - Ejemplos de configuración

### **❓ Troubleshooting & Support**
- [Docker Troubleshooting](https://docs.docker.com/engine/reference/run/#troubleshooting) - Solución de problemas
- [Nginx Troubleshooting](https://nginx.org/en/docs/debugging_log.html) - Debugging de nginx
- [Node.js Debugging](https://nodejs.org/en/docs/guides/debugging-getting-started/) - Debugging Node.js
- [Webpack Troubleshooting](https://webpack.js.org/migrate/troubleshooting/) - Solución de problemas

## 🏆 Success Criteria

Your multistage Docker build should:
- ✅ Build successfully
- ✅ Serve the application on port 80
- ✅ Be under 50MB in size
- ✅ Include only runtime dependencies
- ✅ Work with `docker run -p 8080:80 <image>`

Happy Docker building! 🐳 
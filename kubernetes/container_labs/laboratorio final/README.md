# 🏗️ Laboratorio Final - Infraestructura Completa

## 🎯 **Nivel: EXPERTO**

¡El desafío final! Demuestra tu dominio de Docker creando una **infraestructura completa** para una aplicación de producción.

---

## 🚀 **Misión Final**

**Tu desafío**: Construir desde cero una infraestructura completa con **microservicios, monitoreo, seguridad y alta disponibilidad**.

### **LO QUE DEBES CREAR** (sin copiar código):
- ✅ **Múltiples Dockerfiles** optimizados
- ✅ **docker-compose.yml** complejo con 8+ servicios
- ✅ **Proxy reverso** con SSL/HTTPS
- ✅ **Sistema de monitoreo** con métricas
- ✅ **Logging centralizado** 
- ✅ **Backup automatizado**
- ✅ **Redes personalizadas** y seguridad
- ✅ **Health checks** avanzados

### **LO QUE YA TIENES** (código fuente):
- ✅ Frontend React funcional
- ✅ Backend Node.js con API REST
- ✅ Schema de base de datos

---

## 🏗️ **Arquitectura Objetivo**

```
                    ┌─────────────┐
                    │   Internet  │
                    └──────┬──────┘
                           │ HTTPS:443
                    ┌──────▼──────┐
                    │    Nginx    │◄── SSL/TLS Termination
                    │   (Proxy)   │◄── Load Balancer
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
    ┌─────────▼───┐ ┌──────▼──────┐ ┌───▼────┐
    │  Frontend   │ │   Backend   │ │  API   │
    │   (React)   │ │ (Node.js)   │ │Gateway │
    └─────────────┘ └──────┬──────┘ └────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
    ┌─────────▼───┐ ┌──────▼──────┐ ┌───▼────┐
    │ PostgreSQL  │ │    Redis    │ │ Backup │
    │ (Database)  │ │   (Cache)   │ │Service │
    └─────────────┘ └─────────────┘ └────────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
    ┌─────────▼───┐ ┌──────▼──────┐ ┌───▼────┐
    │ Prometheus  │ │   Grafana   │ │  ELK   │
    │(Monitoring) │ │(Dashboard)  │ │(Logs)  │
    └─────────────┘ └─────────────┘ └────────┘
```

---

## 🎓 **DESAFÍO 1: Frontend con Multistage**

### **Tu misión**: Crear `frontend/Dockerfile`

**Requerimientos:**
- **3 stages**: development, build, production
- **Stage 1**: Node.js para desarrollo
- **Stage 2**: Build optimizado con Vite
- **Stage 3**: Nginx Alpine para producción
- **Optimización**: Solo archivos estáticos en producción
- **Seguridad**: Usuario no-root
- **Health check**: Endpoint `/health`

### **Estructura esperada:**
```dockerfile
# Stage 1: Development
FROM node:18-alpine AS development
# ... tu código aquí

# Stage 2: Build  
FROM node:18-alpine AS build
# ... tu código aquí

# Stage 3: Production
FROM nginx:alpine AS production
# ... tu código aquí
```

---

## 🎓 **DESAFÍO 2: Backend con Optimización**

### **Tu misión**: Crear `backend/Dockerfile`

**Requerimientos:**
- **Multistage**: development y production
- **Cache de dependencias**: npm install optimizado
- **Usuario no-root**: Seguridad
- **Health check**: Script personalizado
- **Logs**: Directorio `/app/logs`
- **Secrets**: Variables de entorno seguras

### **Optimizaciones requeridas:**
- Separar `package.json` copy para cache
- Usar `npm ci` en lugar de `npm install`
- Minimizar capas de imagen
- Implementar graceful shutdown

---

## 🎓 **DESAFÍO 3: Orquestación Avanzada**

### **Tu misión**: Crear `docker-compose.yml` maestro

**8 Servicios mínimos:**
1. **frontend** - React app
2. **backend** - Node.js API  
3. **database** - PostgreSQL
4. **cache** - Redis
5. **proxy** - Nginx con SSL
6. **monitoring** - Prometheus
7. **dashboard** - Grafana
8. **backup** - Servicio automatizado

### **Características avanzadas:**
```yaml
# Redes personalizadas
networks:
  frontend-network:
    driver: bridge
  backend-network:
    driver: bridge
    internal: true  # Solo comunicación interna

# Health checks complejos
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:5000/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s

# Dependencias con condiciones
depends_on:
  database:
    condition: service_healthy
  cache:
    condition: service_started

# Resource limits
deploy:
  resources:
    limits:
      memory: 512M
      cpus: '0.5'
```

---

## 🎓 **DESAFÍO 4: Proxy y SSL**

### **Tu misión**: Configurar Nginx como proxy reverso

**Crear:**
- `nginx/nginx.conf` - Configuración completa
- `nginx/ssl/` - Certificados SSL
- Rate limiting y security headers
- Compresión gzip
- Cache de archivos estáticos

**Funcionalidades:**
- **HTTPS redirect**: HTTP → HTTPS automático
- **Load balancing**: Entre múltiples backends
- **SSL/TLS**: Certificados auto-firmados
- **Security headers**: XSS, CSRF protección
- **Rate limiting**: Anti-DDoS básico

---

## 🎓 **DESAFÍO 5: Monitoreo Completo**

### **Tu misión**: Sistema de observabilidad

**Prometheus + Grafana:**
- Métricas de aplicación
- Métricas de contenedores
- Alertas automáticas
- Dashboards personalizados

**Logging (ELK Stack):**
- Centralización de logs
- Búsqueda y filtrado
- Alertas por errores
- Retención de logs

---

## 🎓 **DESAFÍO 6: Backup y Persistencia**

### **Tu misión**: Estrategia de backup

**Crear servicio de backup:**
- Backup automático de PostgreSQL
- Cron jobs dentro del contenedor
- Retención de backups (7 días)
- Notificaciones de éxito/fallo
- Restore automático

**Volúmenes estratégicos:**
- Base de datos persistente
- Logs centralizados  
- Configuraciones
- Certificados SSL

---

## 🔧 **Herramientas y Tecnologías**

### **Obligatorias:**
- **Docker**: Engine 20.10+
- **Docker Compose**: v2.0+
- **Node.js**: 18 Alpine
- **PostgreSQL**: 15 Alpine
- **Redis**: 7 Alpine
- **Nginx**: Alpine
- **Prometheus**: Latest
- **Grafana**: Latest

### **Opcionales (Puntos extra):**
- **Elasticsearch + Kibana**: Logging
- **Traefik**: Como alternativa a Nginx
- **Vault**: Gestión de secretos
- **Consul**: Service discovery

---

## 🔐 **Requerimientos de Seguridad**

### **Obligatorios:**
- ✅ **Usuarios no-root** en todos los contenedores
- ✅ **Variables de entorno** para secretos
- ✅ **SSL/TLS** encryption
- ✅ **Network isolation** entre servicios
- ✅ **Resource limits** en todos los servicios

### **Avanzados:**
- 🔒 **Secrets management** con Docker secrets
- 🔒 **Image scanning** con herramientas de seguridad
- 🔒 **Runtime protection** con AppArmor/SELinux
- 🔒 **Vulnerability scanning** automatizado

---

## 📖 **Recursos Oficiales de Aprendizaje**

### **🐳 Docker Enterprise & Production**
- [Docker Production Best Practices](https://docs.docker.com/config/containers/live-restore/) - Guías de producción oficiales
- [Docker Compose Production Guide](https://docs.docker.com/compose/production/) - Compose para producción
- [Docker Multi-stage Builds](https://docs.docker.com/develop/dev-best-practices/#use-multi-stage-builds) - Builds optimizados
- [Docker Security Best Practices](https://docs.docker.com/engine/security/security/) - Seguridad oficial
- [Docker Networking Guide](https://docs.docker.com/network/) - Redes avanzadas

### **🔧 Orchestration & Compose**
- [Docker Compose File Reference](https://docs.docker.com/compose/compose-file/) - Sintaxis completa de compose
- [Docker Compose CLI Reference](https://docs.docker.com/compose/reference/) - Comandos de compose
- [Docker Swarm Mode](https://docs.docker.com/engine/swarm/) - Orquestación nativa
- [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/) - Gestión de secretos

### **⚡ Performance & Optimization**
- [Dockerfile Best Practices](https://docs.docker.com/develop/dev-best-practices/) - Optimización oficial
- [Docker Image Optimization](https://docs.docker.com/develop/dev-best-practices/#keep-images-small) - Imágenes eficientes
- [Docker Build Cache](https://docs.docker.com/develop/dev-best-practices/#leverage-build-cache) - Cache inteligente
- [Docker Resource Constraints](https://docs.docker.com/config/containers/resource_constraints/) - Límites de recursos

### **🔒 Security & Compliance**
- [Docker Security Documentation](https://docs.docker.com/engine/security/) - Seguridad completa
- [Docker Content Trust](https://docs.docker.com/engine/security/trust/) - Verificación de imágenes
- [Docker AppArmor](https://docs.docker.com/engine/security/apparmor/) - Seguridad avanzada
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) - Estándares de seguridad
- [Docker Secrets Management](https://docs.docker.com/engine/swarm/secrets/) - Gestión de secretos

### **🌐 Networking & Proxy**
- [Nginx Official Documentation](https://nginx.org/en/docs/) - Documentación completa de Nginx
- [Nginx Reverse Proxy Guide](https://docs.nginx.com/nginx/admin-guide/web-server/reverse-proxy/) - Proxy reverso
- [Nginx SSL/TLS Guide](https://docs.nginx.com/nginx/admin-guide/security-controls/terminating-ssl-http/) - Configuración SSL
- [Nginx Rate Limiting](https://docs.nginx.com/nginx/admin-guide/security-controls/controlling-access-proxied-http/) - Control de acceso
- [Docker Custom Networks](https://docs.docker.com/network/bridge/) - Redes personalizadas

### **📊 Monitoring & Observability**
- [Prometheus Official Documentation](https://prometheus.io/docs/) - Monitoreo completo
- [Grafana Documentation](https://grafana.com/docs/) - Dashboards y visualización
- [Docker Metrics with Prometheus](https://docs.docker.com/config/daemon/prometheus/) - Métricas de Docker
- [Node.js Monitoring with Prometheus](https://prometheus.io/docs/guides/node-exporter/) - Métricas de aplicación
- [Prometheus Alerting](https://prometheus.io/docs/alerting/overview/) - Sistema de alertas

### **🗃️ Data Management & Backup**
- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/) - Base de datos completa
- [Redis Documentation](https://redis.io/documentation) - Cache y almacenamiento
- [Docker Volumes](https://docs.docker.com/storage/volumes/) - Persistencia de datos
- [PostgreSQL Backup Guide](https://www.postgresql.org/docs/current/backup.html) - Estrategias de backup
- [Docker Backup Strategies](https://docs.docker.com/storage/volumes/#backup-restore-or-migrate-data-volumes) - Backup de contenedores

### **🔍 Logging & Debugging**
- [Docker Logging Drivers](https://docs.docker.com/config/containers/logging/configure/) - Configuración de logs
- [Elasticsearch Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/index.html) - Búsqueda de logs
- [Kibana User Guide](https://www.elastic.co/guide/en/kibana/current/index.html) - Visualización de logs
- [Docker Debug Guide](https://docs.docker.com/engine/reference/commandline/logs/) - Debugging de contenedores
- [Docker Health Checks](https://docs.docker.com/engine/reference/builder/#healthcheck) - Monitoreo de salud

### **🚀 CI/CD & DevOps**
- [Docker Multi-platform Builds](https://docs.docker.com/buildx/working-with-buildx/) - Builds multiplataforma
- [Docker Registry](https://docs.docker.com/registry/) - Registro de imágenes
- [Docker BuildKit](https://docs.docker.com/develop/dev-best-practices/#use-buildkit) - Builder avanzado
- [GitHub Actions Docker](https://docs.github.com/en/actions/publishing-packages/publishing-docker-images) - CI/CD oficial

### **🎯 Tutorials & Examples**
- [Docker Awesome Compose](https://github.com/docker/awesome-compose) - Ejemplos oficiales
- [Docker Samples](https://github.com/dockersamples) - Repositorio de ejemplos
- [Nginx Config Examples](https://github.com/nginx/nginx-conf) - Configuraciones de ejemplo
- [Prometheus Examples](https://github.com/prometheus/prometheus/tree/main/documentation/examples) - Ejemplos de configuración

### **❓ Community & Support**
- [Docker Community Forums](https://forums.docker.com/) - Foro oficial
- [Docker Reddit](https://www.reddit.com/r/docker/) - Comunidad Reddit
- [Stack Overflow Docker](https://stackoverflow.com/questions/tagged/docker) - Preguntas técnicas
- [Docker Slack Community](https://dockercommunity.slack.com/) - Chat en tiempo real
- [Docker GitHub](https://github.com/docker) - Código fuente y issues

### **📚 Advanced Learning**
- [Docker Certified Associate](https://training.mirantis.com/dca-certification-exam/) - Certificación oficial
- [Kubernetes Documentation](https://kubernetes.io/docs/) - Orquestación avanzada
- [CNCF Landscape](https://landscape.cncf.io/) - Ecosistema cloud native
- [12-Factor App](https://12factor.net/) - Mejores prácticas para aplicaciones

---

## 📊 **Criterios de Evaluación**

### **Funcionalidad Básica (40 puntos)**
- [ ] Todos los servicios inician correctamente
- [ ] Frontend accesible via HTTPS
- [ ] Backend conecta a base de datos
- [ ] API funciona completamente
- [ ] Datos persisten después de restart

### **Arquitectura Docker (30 puntos)**
- [ ] Dockerfiles optimizados con multistage
- [ ] docker-compose.yml bien estructurado
- [ ] Health checks implementados
- [ ] Redes y volúmenes configurados
- [ ] Resource limits definidos

### **Seguridad (15 puntos)**
- [ ] SSL/HTTPS funcionando
- [ ] Usuarios no-root
- [ ] Secrets management
- [ ] Network isolation
- [ ] Security headers

### **Observabilidad (15 puntos)**
- [ ] Métricas en Prometheus
- [ ] Dashboards en Grafana
- [ ] Logs centralizados
- [ ] Alertas configuradas
- [ ] Backup funcionando

---

## 🏆 **Bonus Points**

### **Innovación técnica:**
- 🌟 **CI/CD Pipeline** con GitHub Actions
- 🌟 **Auto-scaling** con Docker Swarm
- 🌟 **Blue-Green deployment**
- 🌟 **Disaster recovery** plan
- 🌟 **Performance tuning** avanzado

### **Documentación:**
- 📚 **Architecture Decision Records**
- 📚 **Runbook** de operaciones
- 📚 **Troubleshooting guide**
- 📚 **Security audit** report

---

## 🎯 **Entrega del Proyecto**

### **Estructura esperada:**
```
laboratorio-final/
├── README.md                    # Tu documentación
├── docker-compose.yml           # Orquestación principal
├── docker-compose.override.yml  # Configuración local
├── .env.example                 # Variables de entorno
├── frontend/
│   ├── Dockerfile
│   └── nginx.conf
├── backend/
│   ├── Dockerfile
│   └── healthcheck.js
├── nginx/
│   ├── nginx.conf
│   └── ssl/
├── monitoring/
│   ├── prometheus.yml
│   └── grafana/
├── backup/
│   ├── Dockerfile
│   └── backup.sh
└── docs/
    ├── architecture.md
    ├── security.md
    └── operations.md
```

### **Comandos que deben funcionar:**
```bash
# Setup completo
make setup

# Inicio de la infraestructura
docker-compose up -d

# Health check de todos los servicios
make health-check

# Backup manual
make backup

# Limpieza completa
make clean
```

---

## 🎉 **¡El Desafío Final te Espera!**

Este es tu momento de brillar. Demuestra que has dominado:

- 🐳 **Docker** a nivel experto
- 🏗️ **Arquitectura** de microservicios
- 🔒 **Seguridad** en containers
- 📊 **Observabilidad** completa
- ⚡ **Performance** optimization

**¿Estás listo para convertirte en un Docker Master? ¡Acepta el desafío! 🚀**

---

## 📞 **Soporte**

Si te quedas atascado:
1. **Revisa los labs anteriores** - Aplica lo aprendido
2. **Lee la documentación oficial** - Docker, Compose, etc.
3. **Busca en la comunidad** - Stack Overflow, Reddit
4. **Experimenta y falla** - ¡Es parte del aprendizaje!

**¡Good luck, future Docker Master! 🐳👑** 
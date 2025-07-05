# 🛠️ Docker Lab 3 - Backend + Base de Datos

## 🎯 **Nivel: Intermedio**

En este laboratorio aprenderás a **conectar microservicios** creando tu propio backend con base de datos usando Docker Compose.

---

## 🚀 **Objetivo del Laboratorio**

**Tu misión**: Crear una API REST que se conecte a PostgreSQL, todo containerizado.

### **Lo que VAS A CREAR** (sin copiar código):
- ✅ `Dockerfile` para el backend Node.js
- ✅ `docker-compose.yml` para orquestar servicios  
- ✅ Conexión entre backend y PostgreSQL
- ✅ Volúmenes para persistir datos
- ✅ Variables de entorno para configuración

### **Lo que YA ESTÁ LISTO** (código fuente):
- ✅ `server.js` - API REST completa con Express
- ✅ `package.json` - Dependencias del backend
- ✅ `init.sql` - Schema de la base de datos

---

## 📁 **Estructura del Proyecto**

```
lab3/
├── backend/
│   ├── package.json      ✅ Ya creado
│   └── server.js         ✅ Ya creado
├── database/
│   └── init.sql          ✅ Ya creado
├── Dockerfile            ❌ TU DEBES CREARLO
└── docker-compose.yml    ❌ TU DEBES CREARLO
```

---

## 🎓 **DESAFÍO 1: Crear el Dockerfile del Backend**

### **Instrucciones:**

Crea `backend/Dockerfile` que:

1. **Use Node.js 18 Alpine** como base
2. **Establezca /app** como directorio de trabajo
3. **Copie package.json** primero (para cache de Docker)
4. **Instale dependencias** con `npm ci`
5. **Copie el código fuente**
6. **Exponga el puerto 5000**
7. **Ejecute el servidor** con `node server.js`

### **Pistas:**
```dockerfile
# Pista: Empieza con FROM node:18-alpine
# Pista: Usa WORKDIR /app
# Pista: Copia package*.json ./
# Pista: RUN npm ci
# Pista: COPY . .
# Pista: EXPOSE 5000
# Pista: CMD ["node", "server.js"]
```

### **🧪 Probar el Dockerfile:**
```bash
# Construir la imagen
docker build -t taskmanager-backend ./backend

# Probar (debería fallar sin DB)
docker run -p 5000:5000 taskmanager-backend
```

---

## 🎓 **DESAFÍO 2: Crear docker-compose.yml**

### **Instrucciones:**

Crea `docker-compose.yml` en la raíz con 2 servicios:

#### **Servicio: backend**
- Build desde `./backend`
- Puerto: `5000:5000`
- Variables de entorno:
  - `DB_HOST=database`
  - `DB_USER=taskuser`  
  - `DB_PASSWORD=taskpass123`
  - `DB_NAME=taskmanager`
  - `JWT_SECRET=your_secret_key`
- Depende de: `database`

#### **Servicio: database**  
- Imagen: `postgres:15-alpine`
- Variables de entorno:
  - `POSTGRES_USER=taskuser`
  - `POSTGRES_PASSWORD=taskpass123`
  - `POSTGRES_DB=taskmanager`
- Puerto: `5432:5432`
- Volúmenes:
  - `postgres_data:/var/lib/postgresql/data`
  - `./database/init.sql:/docker-entrypoint-initdb.d/init.sql`

### **Pistas para docker-compose.yml:**
```yaml
# Pista: services:
# Pista:   backend:
# Pista:     build: ./backend
# Pista:     ports:
# Pista:       - "5000:5000"
# Pista:     environment:
# Pista:       - DB_HOST=database
# Pista:     depends_on:
# Pista:       - database
# Pista:   database:
# Pista:     image: postgres:15-alpine
# Pista: volumes:
# Pista:   postgres_data:
```

---

## 🚦 **DESAFÍO 3: Ejecutar y Probar**

### **1. Levantar los servicios:**
```bash
# Construir e iniciar
docker-compose up --build

# Ver logs
docker-compose logs
```

### **2. Probar la conexión a la DB:**
```bash
# Conectar a PostgreSQL
docker-compose exec database psql -U taskuser -d taskmanager

# En psql:
\dt                    # Ver tablas
SELECT * FROM users;   # Ver datos de ejemplo
\q                     # Salir
```

### **3. Probar la API:**
```bash
# Health check
curl http://localhost:5000/health

# Registrar usuario
curl -X POST http://localhost:5000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"username":"test","email":"test@test.com","password":"123456"}'

# Login
curl -X POST http://localhost:5000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"test","password":"123456"}'
```

---

## 🔍 **Conceptos Clave a Aprender**

### **Docker Compose**
- **Services**: Definir múltiples containers
- **Build vs Image**: Cuándo construir vs usar imagen
- **Depends_on**: Orden de inicio de servicios
- **Environment**: Variables de entorno
- **Volumes**: Persistencia de datos
- **Networks**: Comunicación entre containers (automática)

### **Networking en Docker**
- Los containers se comunican por **nombre de servicio**
- `backend` conecta a `database:5432` (no localhost)
- Docker Compose crea una red automáticamente

### **Volúmenes**
- **Named volume**: `postgres_data` para persistir DB
- **Bind mount**: `./database/init.sql` para inicialización

---

## 🛠️ **Comandos Útiles Durante el Desarrollo**

```bash
# Ver servicios ejecutándose
docker-compose ps

# Ver logs de un servicio específico
docker-compose logs backend
docker-compose logs database

# Reconstruir un servicio
docker-compose up --build backend

# Detener todo
docker-compose down

# Eliminar volúmenes (⚠️ borra datos)
docker-compose down -v

# Acceder a un container
docker-compose exec backend sh
docker-compose exec database bash
```

---

## 🐛 **Troubleshooting**

### **Error: "database connection failed"**
✅ **Solución**: Verificar variables de entorno
```bash
# Verificar que las variables coincidan
docker-compose exec backend env | grep DB_
docker-compose exec database env | grep POSTGRES_
```

### **Error: "port already in use"**
✅ **Solución**: Cambiar puertos en docker-compose.yml
```yaml
ports:
  - "5001:5000"  # En lugar de 5000:5000
```

### **Error: "init.sql not found"**
✅ **Solución**: Verificar ruta relativa
```yaml
volumes:
  - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql
```

---

## 📖 **Recursos Oficiales de Aprendizaje**

### **🐳 Docker Compose**
- [Docker Compose Documentation](https://docs.docker.com/compose/) - Documentación completa oficial
- [Docker Compose File Reference](https://docs.docker.com/compose/compose-file/) - Sintaxis completa de compose
- [Docker Compose CLI Reference](https://docs.docker.com/compose/reference/) - Comandos de compose
- [Docker Compose Networking](https://docs.docker.com/compose/networking/) - Redes en compose

### **🗃️ PostgreSQL & Database**
- [PostgreSQL Official Documentation](https://www.postgresql.org/docs/) - Documentación completa
- [PostgreSQL Docker Hub](https://hub.docker.com/_/postgres) - Imagen oficial y configuración
- [PostgreSQL Environment Variables](https://github.com/docker-library/docs/blob/master/postgres/README.md) - Variables de entorno
- [PostgreSQL Initialization Scripts](https://github.com/docker-library/docs/blob/master/postgres/README.md#initialization-scripts) - Scripts de inicialización

### **🚀 Node.js Backend & APIs**
- [Node.js Official Documentation](https://nodejs.org/en/docs/) - Documentación completa
- [Express.js Documentation](https://expressjs.com/en/4x/api.html) - Framework para APIs
- [Node.js Docker Best Practices](https://github.com/nodejs/docker-node/blob/main/docs/BestPractices.md) - Mejores prácticas oficiales
- [npm ci Documentation](https://docs.npmjs.com/cli/v8/commands/npm-ci) - Instalación en producción

### **🔗 Microservices & Architecture**
- [Docker Compose for Microservices](https://docs.docker.com/compose/production/) - Compose en producción
- [Docker Networking](https://docs.docker.com/network/) - Comunicación entre containers
- [Docker Volumes](https://docs.docker.com/storage/volumes/) - Persistencia de datos
- [12-Factor App](https://12factor.net/) - Principios de aplicaciones modernas

### **🔧 Environment & Configuration**
- [Docker Environment Variables](https://docs.docker.com/compose/environment-variables/) - Variables de entorno en compose
- [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/) - Gestión de secretos
- [Docker Compose Override](https://docs.docker.com/compose/extends/) - Configuración por ambiente
- [Docker .env Files](https://docs.docker.com/compose/env-file/) - Archivos de entorno

### **📊 Health Checks & Monitoring**
- [Docker Health Checks](https://docs.docker.com/engine/reference/builder/#healthcheck) - Verificación de salud
- [Docker Compose Health Checks](https://docs.docker.com/compose/compose-file/compose-file-v3/#healthcheck) - Health checks en compose
- [PostgreSQL Health Checks](https://www.postgresql.org/docs/current/monitoring.html) - Monitoreo de PostgreSQL
- [Node.js Health Checks](https://nodejs.org/en/docs/guides/simple-profiling/) - Monitoreo Node.js

### **🐛 Debugging & Troubleshooting**
- [Docker Compose Logs](https://docs.docker.com/compose/reference/logs/) - Logs en compose
- [Docker Compose Troubleshooting](https://docs.docker.com/compose/troubleshooting/) - Solución de problemas
- [PostgreSQL Troubleshooting](https://www.postgresql.org/docs/current/runtime.html) - Debugging PostgreSQL
- [Node.js Debugging](https://nodejs.org/en/docs/guides/debugging-getting-started/) - Debugging Node.js

### **🔒 Security & Best Practices**
- [Docker Security](https://docs.docker.com/engine/security/) - Seguridad en containers
- [PostgreSQL Security](https://www.postgresql.org/docs/current/security.html) - Seguridad en PostgreSQL
- [Node.js Security](https://nodejs.org/en/docs/guides/security/) - Seguridad en Node.js
- [Express.js Security](https://expressjs.com/en/advanced/best-practice-security.html) - Seguridad en Express

### **📡 API Development**
- [REST API Design](https://restfulapi.net/) - Principios de APIs REST
- [JWT.io](https://jwt.io/introduction/) - JSON Web Tokens
- [HTTP Status Codes](https://developer.mozilla.org/en-US/docs/Web/HTTP/Status) - Códigos de respuesta HTTP
- [Express.js Middleware](https://expressjs.com/en/guide/using-middleware.html) - Middleware en Express

### **🎯 Practical Examples**
- [Docker Compose Examples](https://github.com/docker/awesome-compose) - Ejemplos oficiales
- [Node.js Docker Examples](https://github.com/nodejs/docker-node/tree/main/docs) - Ejemplos Node.js
- [PostgreSQL Examples](https://github.com/docker-library/docs/tree/master/postgres) - Ejemplos PostgreSQL
- [Express.js Examples](https://github.com/expressjs/express/tree/master/examples) - Ejemplos Express

### **❓ Community & Support**
- [Docker Community Forums](https://forums.docker.com/) - Foro oficial
- [PostgreSQL Community](https://www.postgresql.org/community/) - Comunidad PostgreSQL
- [Node.js Community](https://nodejs.org/en/get-involved/) - Comunidad Node.js
- [Stack Overflow Tags](https://stackoverflow.com/questions/tagged/docker+postgresql) - Preguntas específicas

---

## 📊 **Endpoints Disponibles**

Una vez funcionando, tu API tendrá:

### **Autenticación**
- `POST /auth/register` - Registrar usuario
- `POST /auth/login` - Iniciar sesión

### **Tareas** (requiere token JWT)
- `GET /tasks` - Listar tareas
- `POST /tasks` - Crear tarea
- `PUT /tasks/:id` - Actualizar tarea
- `DELETE /tasks/:id` - Eliminar tarea

### **Utilidad**
- `GET /health` - Estado del servicio
- `GET /stats` - Estadísticas del usuario

---

## ✅ **Criterios de Éxito**

### **Básico (Obligatorio)**
- [ ] `docker-compose up` funciona sin errores
- [ ] Backend se conecta a PostgreSQL
- [ ] Puedes registrar un usuario
- [ ] Puedes hacer login y obtener JWT
- [ ] Los datos persisten después de `docker-compose restart`

### **Intermedio (Recomendado)**
- [ ] Entiendes cómo funcionan las variables de entorno
- [ ] Puedes conectarte manualmente a PostgreSQL
- [ ] Sabes leer logs para debugging
- [ ] Comprendes la comunicación entre containers

### **Avanzado (Opcional)**
- [ ] Implementas health checks en docker-compose
- [ ] Usas .env file para variables
- [ ] Agregas restart policies
- [ ] Optimizas el Dockerfile con capas

---

## 🎯 **Próximo Paso: Lab 4**

Una vez que domines este laboratorio:

**Lab 4**: Agregar Frontend
- Crear React app
- Conectar frontend con tu API
- Aplicación completa de 3 capas

---

## 🏆 **¡El Desafío te Espera!**

**No copies y pegues** - ¡aprende haciendo! 

1. **Crea tu Dockerfile**
2. **Escribe tu docker-compose.yml**  
3. **Experimenta y debuggea**
4. **Entiende cada línea**

**¿Listo para el desafío? ¡Manos a la obra! 🚀** 
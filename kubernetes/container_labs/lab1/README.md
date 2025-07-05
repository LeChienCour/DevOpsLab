# 🐳 Docker Lab 1 - Fundamentos de Docker

## 🎯 **Nivel: Principiante**

¡Bienvenido a tu primer laboratorio de Docker! Aquí aprenderás los conceptos más básicos creando tu primer container desde cero.

---

## 🚀 **Objetivo del Laboratorio**

**Tu misión**: Crear tu primer Dockerfile y contenedor que ejecute una aplicación simple.

### **Lo que VAS A APRENDER**:
- ✅ ¿Qué es un Dockerfile?
- ✅ Comandos básicos de Docker: `FROM`, `RUN`, `COPY`, `CMD`
- ✅ Construir tu primera imagen
- ✅ Ejecutar tu primer contenedor
- ✅ Diferencia entre imagen y contenedor

---

## 📚 **Conceptos Básicos**

### **¿Qué es Docker?**
Docker es una plataforma que permite **empaquetar aplicaciones** en contenedores portátiles que pueden ejecutarse en cualquier lugar.

### **¿Qué es un Dockerfile?**
Un **archivo de texto** con instrucciones para construir una imagen de Docker. Es como una "receta" para crear tu contenedor.

### **¿Qué es una Imagen?**
Un **template** inmutable que contiene tu aplicación y todas sus dependencias.

### **¿Qué es un Contenedor?**
Una **instancia ejecutándose** de una imagen. Es tu aplicación corriendo en aislamiento.

---

## 🎓 **DESAFÍO 1: Tu Primer Dockerfile**

### **Instrucciones:**

Crea un archivo llamado `Dockerfile` (sin extensión) que:

1. **Use Alpine Linux** como imagen base (es muy pequeña)
2. **Actualice los paquetes** del sistema
3. **Cree un directorio de trabajo** llamado `/app`
4. **Copie todos los archivos** del directorio actual al contenedor
5. **Haga ejecutable** un archivo llamado `app`
6. **Configure el comando** para ejecutar `./app`

### **Comandos Docker que necesitas:**

```dockerfile
FROM <imagen_base>          # Imagen de partida
RUN <comando>               # Ejecutar comando durante la construcción
WORKDIR <directorio>        # Establecer directorio de trabajo
COPY <origen> <destino>     # Copiar archivos al contenedor
RUN chmod +x <archivo>      # Hacer archivo ejecutable
CMD ["comando", "arg"]      # Comando por defecto al ejecutar
```

### **Pistas específicas:**
```dockerfile
# Pista 1: Usa FROM alpine:latest
# Pista 2: RUN apk update && apk upgrade
# Pista 3: WORKDIR /app
# Pista 4: COPY . ./
# Pista 5: RUN chmod +x ./app
# Pista 6: CMD ["./app"]
```

---

## 🎓 **DESAFÍO 2: Crear tu Aplicación**

### **Crea un archivo ejecutable simple:**

```bash
# Crear archivo app (script bash)
echo '#!/bin/sh' > app
echo 'echo "¡Hola Docker! Mi primer contenedor funciona 🐳"' >> app
echo 'echo "Hostname del contenedor: $(hostname)"' >> app
echo 'echo "Usuario actual: $(whoami)"' >> app

# Hacerlo ejecutable
chmod +x app
```

---

## 🎓 **DESAFÍO 3: Construir y Ejecutar**

### **1. Construir la imagen:**
```bash
# Construir la imagen con tag "mi-primer-app"
docker build -t mi-primer-app .

# Ver tu imagen creada
docker images
```

### **2. Ejecutar el contenedor:**
```bash
# Ejecutar tu contenedor
docker run mi-primer-app

# Ejecutar con nombre personalizado
docker run --name mi-contenedor mi-primer-app

# Ejecutar en modo interactivo
docker run -it mi-primer-app sh
```

### **3. Explorar contenedores:**
```bash
# Ver contenedores ejecutándose
docker ps

# Ver todos los contenedores (incluidos detenidos)
docker ps -a

# Eliminar contenedor
docker rm mi-contenedor

# Eliminar imagen
docker rmi mi-primer-app
```

---

## 🔍 **Conceptos Clave a Entender**

### **Capas de Docker**
- Cada instrucción en Dockerfile crea una **capa**
- Las capas se **reutilizan** para eficiencia
- Ordena comandos por **frecuencia de cambio**

### **Construcción Eficiente**
```dockerfile
# ❌ Malo - siempre invalida cache
COPY . ./
RUN npm install

# ✅ Bueno - reutiliza cache si package.json no cambia
COPY package.json ./
RUN npm install
COPY . ./
```

### **Comandos vs Entrypoints**
- **CMD**: Comando por defecto (se puede sobrescribir)
- **ENTRYPOINT**: Comando fijo (siempre se ejecuta)

---

## 🛠️ **Comandos Útiles para Debugging**

```bash
# Ver logs de construcción detallados
docker build --no-cache -t mi-app .

# Inspeccionar imagen
docker inspect mi-primer-app

# Acceder al contenedor mientras corre
docker exec -it <container_id> sh

# Ver historia de la imagen
docker history mi-primer-app

# Limpiar todo (⚠️ cuidado)
docker system prune -a
```

---

## 🎨 **Retos Adicionales (Opcional)**

### **Reto 1: Personalizar la aplicación**
Modifica tu script `app` para:
- Mostrar la fecha actual
- Mostrar variables de entorno
- Mostrar el contenido de un directorio

### **Reto 2: Usar variables de entorno**
```dockerfile
ENV MI_VARIABLE=valor
```

### **Reto 3: Exponer un puerto**
```dockerfile
EXPOSE 8080
```

### **Reto 4: Crear usuario no-root**
```dockerfile
RUN adduser -D miusuario
USER miusuario
```

---

## 🐛 **Problemas Comunes y Soluciones**

### **Error: "No such file or directory"**
✅ **Solución**: Verificar que el archivo `app` existe y tiene permisos de ejecución
```bash
ls -la app
chmod +x app
```

### **Error: "permission denied"**
✅ **Solución**: Verificar el comando `chmod +x` en el Dockerfile

### **Error: "command not found"**
✅ **Solución**: Verificar la sintaxis del CMD o ENTRYPOINT

---

## 📖 **Recursos Oficiales de Aprendizaje**

### **📚 Documentación Oficial Docker**
- [Docker Get Started Guide](https://docs.docker.com/get-started/) - Tutorial oficial paso a paso
- [Dockerfile Reference](https://docs.docker.com/engine/reference/builder/) - Todos los comandos de Dockerfile
- [Docker CLI Reference](https://docs.docker.com/engine/reference/commandline/cli/) - Todos los comandos docker
- [Best Practices for Dockerfiles](https://docs.docker.com/develop/dev-best-practices/) - Mejores prácticas oficiales

### **🎯 Tutoriales Específicos**
- [Alpine Linux Documentation](https://wiki.alpinelinux.org/wiki/Main_Page) - Documenta el sistema base
- [Shell Scripting Tutorial](https://www.shellscript.sh/) - Para crear scripts ejecutables
- [Linux Command Line Basics](https://ubuntu.com/tutorials/command-line-for-beginners) - Comandos básicos

### **🔧 Herramientas de Debugging**
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) - Interfaz gráfica oficial
- [Docker Hub](https://hub.docker.com/) - Repositorio de imágenes oficiales
- [Docker Logs Documentation](https://docs.docker.com/config/containers/logging/) - Manejo de logs

### **📋 Cheat Sheets Útiles**
- [Docker Cheat Sheet](https://docs.docker.com/get-started/docker_cheatsheet.pdf) - Comandos básicos PDF
- [Dockerfile Cheat Sheet](https://kapeli.com/cheat_sheets/Dockerfile.docset/Contents/Resources/Documents/index) - Instrucciones de Dockerfile
- [Linux Commands Cheat Sheet](https://www.guru99.com/linux-commands-cheat-sheet.html) - Comandos de sistema

### **🎥 Videos Educativos Oficiales**
- [Docker Official YouTube Channel](https://www.youtube.com/c/DockerIo) - Tutoriales oficiales
- [Docker 101 Tutorial](https://www.docker.com/101-tutorial/) - Tutorial interactivo oficial

### **❓ Troubleshooting y Soporte**
- [Docker Community Forums](https://forums.docker.com/) - Foro oficial de la comunidad
- [Docker GitHub Issues](https://github.com/docker/docker-ce/issues) - Reportes de bugs oficiales
- [Stack Overflow Docker Tag](https://stackoverflow.com/questions/tagged/docker) - Preguntas y respuestas

### **🔒 Seguridad**
- [Docker Security Documentation](https://docs.docker.com/engine/security/) - Guías de seguridad oficiales
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker) - Estándares de seguridad

---

## ✅ **Criterios de Éxito**

### **Básico (Obligatorio)**
- [ ] Tienes un Dockerfile funcional
- [ ] Puedes construir la imagen sin errores
- [ ] El contenedor ejecuta y muestra el mensaje
- [ ] Entiendes la diferencia entre imagen y contenedor

### **Intermedio (Recomendado)**
- [ ] Sabes usar `docker ps` y `docker images`
- [ ] Puedes eliminar contenedores e imágenes
- [ ] Entiendes el concepto de capas
- [ ] Puedes acceder al contenedor con `sh`

### **Avanzado (Opcional)**
- [ ] Optimizas el Dockerfile para cache
- [ ] Usas variables de entorno
- [ ] Implementas usuario no-root
- [ ] Entiendes ENTRYPOINT vs CMD

---

## 🎯 **Próximo Paso: Lab 2**

Una vez que domines este laboratorio:

**Lab 2**: Aplicación Web con Nginx
- Servir una página web
- Multistage builds
- Optimización de imágenes

---

## 🏆 **¡Felicitaciones!**

Si has completado este laboratorio, ya sabes:

- ✅ **Crear Dockerfiles** básicos
- ✅ **Construir imágenes** Docker
- ✅ **Ejecutar contenedores**
- ✅ **Comandos fundamentales** de Docker
- ✅ **Conceptos clave** de containerización

**¡Estás listo para el siguiente nivel! 🚀**

---

**Próximo laboratorio**: Lab 2 - Aplicación Web con Nginx 🌐 
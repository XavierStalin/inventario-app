# inventario-app

Catálogo de inventario con interfaz web y base de datos local. Este repositorio es el **punto de partida** de la tarea de CI/CD — no incluye `Dockerfile`, workflow de GitHub Actions ni manifiestos de Kubernetes: esos tres se construyen como parte del trabajo asignado.

## Qué es

Una app Node.js/Express con:

- **Interfaz web** (`public/index.html`, `public/app.js`, `public/styles.css`): una tabla de productos con formulario para agregar y botón para eliminar.
- **Base de datos local** (`db.js`): un archivo JSON en `data/products.json` que persiste los productos entre reinicios del proceso — sin motor de base de datos externo ni dependencias nativas.
- **API REST** consumida por la interfaz.

## Ejecutar en local

```bash
npm install
npm start
# abrir http://localhost:3000
```

## Pruebas

```bash
npm test
```

## Endpoints

| Método y ruta | Qué hace |
|---|---|
| `GET /health` | Estado de salud: `200` si el proceso y el archivo de base de datos son accesibles, `500` si no (o si `SIMULATE_FAILURE=true`). |
| `GET /version` | Devuelve `version`, `color` y `hostname` — configurables por variables de entorno `APP_VERSION` / `APP_COLOR`. |
| `GET /api/products` | Lista todos los productos. |
| `GET /api/products/:id` | Devuelve un producto por id. |
| `POST /api/products` | Crea un producto (`name`, `sku`, `stock`, `price`). |
| `PATCH /api/products/:id` | Actualiza campos de un producto. |
| `DELETE /api/products/:id` | Elimina un producto. |
| `GET /` | Sirve la interfaz web. |

## Variables de entorno

| Variable | Por defecto | Para qué |
|---|---|---|
| `PORT` | `3000` | Puerto del servidor. |
| `APP_VERSION` | `v1` | Se muestra en `/version` y en el encabezado de la interfaz. |
| `APP_COLOR` | `blue` | Color del encabezado — útil para distinguir versiones en un despliegue. |
| `SIMULATE_FAILURE` | `false` | Si es `true`, `/health` responde siempre `500`. |
| `DB_PATH` | `./data/products.json` | Ruta del archivo de base de datos local. |

## Guía de Comandos y Despliegue de la Práctica (Parte I)

A continuación se detallan los comandos que se han implementado y verificado hasta el momento en la práctica.

### 1. Construcción y Ejecución Local con Docker

Para empaquetar la aplicación en un contenedor de Docker utilizando el `Dockerfile` multi-stage y validar su correcto funcionamiento localmente:

**Construir la imagen de Docker:**
```bash
docker build -t inventario-app:local .
```

**Ejecutar el contenedor localmente:**
```bash
docker run -d -p 3000:3000 --name inventario-container inventario-app:local
```

**Verificar las rutas principales (con curl):**
```bash
# Ruta de la interfaz web
curl http://localhost:3000/

# Endpoint de salud (debe retornar 200 OK)
curl http://localhost:3000/health

# Endpoint de versión de la app
curl http://localhost:3000/version

# Endpoint para listar productos de la API
curl http://localhost:3000/api/products
```

**Detener y eliminar el contenedor local:**
```bash
docker stop inventario-container
docker rm inventario-container
```

---

### 2. Control de Versiones y Repositorio Git

Comandos utilizados para inicializar el repositorio y vincularlo con GitHub:

```bash
# Inicializar repositorio Git local
git init

# Agregar todos los archivos del proyecto (excluyendo lo declarado en .gitignore)
git add .

# Guardar cambios locales con un commit explicativo
git commit -m "feat: setup dockerfile, workflow and fix file paths"

# Renombrar rama principal a main
git branch -M main

# Vincular con el repositorio remoto de GitHub
git remote add origin https://github.com/XavierStalin/inventario-app.git

# Subir los archivos por primera vez y configurar seguimiento
git push -u origin main
```

---

### 3. Pipeline de Integración Continua (GitHub Actions)

El workflow se activa automáticamente en cada `git push` a la rama `main` y consta de los siguientes pasos:

1. **Job `build-test`**: Descarga el código, instala todas las dependencias con `npm ci` y ejecuta `npm test`. Si las pruebas fallan, el pipeline se detiene inmediatamente (fail-fast).
2. **Job `build-push`**:
   - Inicia sesión de forma segura en GitHub Container Registry (`ghcr.io`).
   - Genera los metadatos y etiquetas para la imagen (incluyendo el hash del commit y la etiqueta `latest`).
   - Construye y carga localmente la imagen utilizando `load: true`.
   - **Escaneo de Seguridad con Trivy**: Ejecuta un escaneo de vulnerabilidades críticas. Si detecta alguna vulnerabilidad de severidad `CRITICAL`, el pipeline fallará con código de salida `1` para prevenir la publicación de imágenes inseguras.
   - **Publicar**: Publica la imagen limpia en el registro GHCR si supera todos los filtros de seguridad.

---

### 4. Preparación del Entorno de Kubernetes (Minikube)

Para aislar esta práctica de otras actividades sin eliminar configuraciones anteriores:

**Crear un nuevo perfil de Minikube:**
```bash
minikube start -p practica-inventario
```

**Verificar el estado del nuevo perfil:**
```bash
minikube profile list
```

**Detener el cluster al finalizar la sesión de trabajo:**
```bash
minikube stop -p practica-inventario
```

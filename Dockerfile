# ==========================================
# ETAPA 1: BUILD Y TEST
# ==========================================
FROM node:24-bookworm-slim AS builder

# Directorio de trabajo
WORKDIR /app

# Copiar archivos de dependencias
COPY package.json package-lock.json ./

# Instalar dependencias de forma reproducible
RUN npm ci

# Copiar el código de la aplicación
COPY . .

# Ejecutar las pruebas
# Si npm test falla, Docker build falla
RUN npm test


# ==========================================
# ETAPA 2: IMAGEN FINAL
# ==========================================
FROM node:24-bookworm-slim AS runtime

# Directorio de trabajo
WORKDIR /app

# Indicar que estamos en producción
ENV NODE_ENV=production

# Copiar archivos de dependencias
COPY package.json package-lock.json ./

# Instalar únicamente dependencias de producción
RUN npm ci --omit=dev && npm cache clean --force

# Copiar el código necesario desde la etapa anterior
COPY --from=builder /app/server.js ./server.js
COPY --from=builder /app/db.js ./db.js
COPY --from=builder /app/public ./public
COPY --from=builder /app/data ./data

# Exponer el puerto de la aplicación
EXPOSE 3000

# Ejecutar la aplicación
CMD ["node", "server.js"]
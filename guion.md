# GUION DE PRUEBAS - PRÁCTICA DE LABORATORIO CI/CD KUBERNETES

Este archivo es una guía local paso a paso para ejecutar y verificar las demostraciones solicitadas en la práctica.

---

## 🛠️ PASO 0: Preparar el Entorno

### 1. Iniciar Minikube con el perfil de la práctica
Asegúrate de que Docker esté abierto en tu sistema. Luego, inicia Minikube con el perfil asignado:
```powershell
minikube start -p practica-inventario
```

### 2. Verificar que el clúster esté listo y saludable
El estado del host, kubelet y apiserver debe ser `Running`:
```powershell
minikube status -p practica-inventario
```

### 3. Preparar el archivo de Secretos local
Duplica la plantilla de secretos para crear tu archivo local (excluido de Git):
```powershell
cp secret.example.yaml k8s/secret.yaml
```
*(Opcional: Abre `k8s/secret.yaml` y edita la API_KEY si lo deseas).*

---

## 📦 FASE 1: Despliegue Base y Buenas Prácticas

### 1. Aplicar los manifiestos base
```powershell
kubectl apply -f k8s/
```

### 🔍 PRUEBA DE ROLLING UPDATE (Actualización Progresiva)

El Rolling Update asegura que la aplicación se actualice progresivamente a una nueva versión sin interrumpir el servicio de tus usuarios.

**Paso A:** Simula una actualización en el despliegue activo cambiando una variable de entorno (por ejemplo, cambia el color del header a verde):
```powershell
kubectl set env deployment/inventario-app APP_COLOR=green
```

**Paso B:** Inmediatamente ejecuta este comando para ver el progreso de la transición de pods:
```powershell
kubectl rollout status deployment/inventario-app
```
* **Resultado Esperado:** Observarás cómo Kubernetes arranca los nuevos contenedores y detiene los viejos de manera escalonada, informando en consola:
  `Waiting for deployment "inventario-app" rollout to finish: 1 old replicas are pending termination...`
  `deployment "inventario-app" successfully rolled out`

**Paso C:** Puedes verificar el historial de revisiones del deployment para confirmar las versiones desplegadas:
```powershell
kubectl rollout history deployment/inventario-app
```

---

## 🔍 DEMOSTRACIÓN 3: Sonda de salud y Arranque Lento (Readiness realista)

**Paso A:** Inmediatamente después de aplicar los manifiestos, ejecuta este comando para ver el estado de los Pods en tiempo real:
```powershell
kubectl get pods -l app=inventario-app -w
```
* **Resultado Esperado:** Verás que los pods se reportan en `Running` pero su columna `READY` muestra `0/1` (no listos para tráfico). Transcurridos 12 segundos (10s de la variable de arranque lento + 2s de holgura de la sonda), cambiarán automáticamente a `1/1 READY`. Presiona `Ctrl + C` para salir del monitoreo.

**Paso B:** Si deseas ver la evidencia de la sonda fallando al principio con código `503`, ejecuta:
```powershell
kubectl describe pod -l app=inventario-app
```
* **Resultado Esperado:** Al final en la sección `Events`, verás avisos del tipo:  
  `Warning  Unhealthy ... Readiness probe failed: HTTP probe failed with statuscode: 503`.

---

### 🔍 DEMOSTRACIÓN 2: Manejo de Secretos (Sin texto plano)

Verifica que el pod pueda leer la clave secreta inyectada mediante variables de entorno desde el `Secret`:
```powershell
kubectl exec -it deployment/inventario-app -- env | findstr API_KEY
```
* **Resultado Esperado:** Deberá imprimir:  
  `API_KEY=my-super-secret-api-key-12345` (o la clave que pusiste en tu `secret.yaml`).

---

### 🔍 DEMOSTRACIÓN 4: Pérdida de Datos en Almacenamiento Efímero

**Paso A: Redirigir el puerto para acceder en el navegador**
```powershell
kubectl port-forward svc/inventario-service 8080:80
```
* **Qué hacer:** Deja esta terminal corriendo y abre [http://localhost:8080](http://localhost:8080) en tu navegador.
* **Acción:** Crea un producto usando el formulario (por ejemplo: `Mouse Gamer`, SKU: `MOU-001`). Verifica que aparezca en la lista de la interfaz.

**Paso B: Forzar la destrucción del Pod (Abre una nueva terminal)**
```powershell
# Obtén el nombre del pod actual
kubectl get pods

# Elimina el pod (reemplaza <nombre-del-pod> por el real)
kubectl delete pod <nombre-del-pod>
```
* **Resultado Esperado:** El `ReplicaSet` de Kubernetes creará inmediatamente otro pod de reemplazo para mantener las 2 réplicas configuradas.

**Paso C: Comprobar la pérdida de datos**
* **Nota Importante:** Al borrar los pods, la terminal del `port-forward` del Paso A se cerrará con el error `lost connection to pod`. Esto es normal. 
* **Acción:** Vuelve a iniciar el reenvío en esa terminal:
  ```powershell
  kubectl port-forward svc/inventario-service 8080:80
  ```
* Recarga tu navegador en [http://localhost:8080](http://localhost:8080) (o consulta usando `curl -s http://localhost:8080/api/products`).
* **Resultado Esperado:** El catálogo estará vacío (retornará `[]`) y el producto creado habrá desaparecido. Esto demuestra la naturaleza efímera e inmutable del almacenamiento interno del contenedor.
* **Para terminar:** Presiona `Ctrl + C` en la terminal del `port-forward` para detener la redirección.

---

## 🧹 LIMPIEZA DE LA FASE 1

Antes de continuar con Canary, limpia los recursos para liberar memoria en tu clúster de Minikube:
```powershell
kubectl delete -f k8s/
```

---

## 🚀 FASE 2: Despliegue de la Estrategia Canary (80/20)

### 1. Aplicar los manifiestos Canary
```powershell
kubectl apply -f k8s/canary/
```

### 2. Verificar que los pods de Canary estén listos
Deberías ver 4 pods de la versión `v1-stable` y 1 pod de la versión `v2-canary` en estado `Running`:
```powershell
kubectl get pods
```

---

### 🔍 DEMOSTRACIÓN 1: Reparto de Tráfico (80% v1 / 20% v2)

Puedes verificar el balanceo proporcional del tráfico de dos formas diferentes (interna y externa):

#### Método A: Prueba interna en consola (Recomendado para capturas)
Ejecuta un Pod temporal de `curl` dentro del clúster que realiza 20 peticiones seguidas al DNS interno del servicio:
```powershell
kubectl run test-canary --rm -i --restart=Never --image=curlimages/curl -- sh -c 'for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do curl -s http://inventario-canary-service/version; echo; done'
```
* **Resultado Esperado:** Verás una lista de 20 respuestas. Aproximadamente 16 de ellas serán `v1.0-stable` (azul) y 4 serán `v2.0-canary` (verde), demostrando la distribución proporcional del 80% / 20%.

#### Método B: Prueba externa en tu navegador (Validación visual)
1. Inicia un reenvío de puertos para el servicio Canary en un puerto alterno (por ejemplo, el 8081):
   ```powershell
   kubectl port-forward svc/inventario-canary-service 8081:80
   ```
2. Abre tu navegador y accede a: [http://localhost:8081/version](http://localhost:8081/version)
3. **Acción:** Recarga la página repetidas veces (`F5`).
4. **Resultado Esperado:** Verás cómo el JSON de respuesta va alternando entre la versión `v1.0-stable` con color `blue` y la versión `v2.0-canary` con color `green` (aproximadamente 1 de cada 5 recargas será verde).
5. **Para terminar:** Detén el comando con `Ctrl + C` en tu terminal.

---

## 🧹 LIMPIEZA FINAL

Una vez termines de recolectar evidencias y capturas de pantalla, limpia el clúster para finalizar la práctica:
```powershell
kubectl delete -f k8s/canary/
minikube stop -p practica-inventario
```

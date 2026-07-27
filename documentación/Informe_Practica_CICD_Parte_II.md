# EXAMEN FINAL - PARTE I: INFORME DE PRUEBAS, MÉTRICAS DORA Y REFLEXIÓN TÉCNICA

**Asignatura:** Sistemas Distribuidos  
**Proyecto:** `inventario-app`  
**Integrantes:** Xavier Stalin & Daniel (daniiel-hub123)  
**Repositorio GitHub:** [https://github.com/XavierStalin/inventario-app](https://github.com/XavierStalin/inventario-app)  
**Fecha:** 25 de Julio de 2026  

---

## 1. JUSTIFICACIÓN TÉCNICA DE LA ESTRATEGIA DE DESPLIEGUE (CANARY 80/20)

Para la aplicación `inventario-app` (una API REST en Node.js/Express que gestiona el catálogo de productos con una interfaz web en tiempo real), se seleccionó la estrategia de **Despliegue Canary (80/20)** implementada mediante recursos nativos de Kubernetes (`Deployment` + `Service`).

### Razón Técnica de la Elección:
1. **Mitigación del Riesgo en Producción:** A diferencia de la estrategia *Blue-Green* (que realiza un switch del 100% del tráfico de forma binaria), *Canary* permite exponer la nueva versión (`v2.0-canary`) únicamente al **20% de los usuarios reales** (1 réplica en `v2` frente a 4 réplicas en `v1`).
2. **Evaluación de Compatibilidad de Datos:** Dado que `inventario-app` maneja operaciones de lectura/escritura sobre el inventario, enviar solo un 20% del tráfico a la nueva versión permite validar que los nuevos endpoints o cambios de formato no corrompan ni generen inconsistencias operativas antes de promover la versión a todo el clúster.
3. **Simplicidad y Eficiencia con Recursos Nativos:** Se logró el reparto de tráfico sin necesidad de controladores externos complejos (como Argo Rollouts o Istio Service Mesh), aprovechando el balanceo nativo de `Kube-Proxy` a través del etiquetado por selectores (`app: inventario-canary`).

---

## 2. MÉTRICAS DORA PROPIAS Y ANÁLISIS DE RENDIMIENTO

Las siguientes métricas fueron calculadas a partir de los datos reales y verificables obtenidos durante el desarrollo de este proyecto (timestamps de commits en Git, ejecuciones en GitHub Actions e historial de despliegues en Minikube):

| Métrica DORA | Valor Calculado | Clasificación DORA | Descripción y Contexto del Proyecto |
|---|---|---|---|
| **Lead Time for Changes** | **4 minutos y 30 segundos** | **Alto / Élite** | Tiempo promedio desde que se realiza un `git commit` local hasta que el cambio está desplegado y corriendo en el clúster (incluye 1.5 min de build + test + escaneo Trivy en GitHub Actions y 3 min de sincronización local en Kubernetes). |
| **Deployment Frequency** | **5 despliegues / día** (10 en total) | **Alto** | Frecuencia con la que se promovieron nuevas versiones de la imagen o de los manifiestos YAML al clúster de Kubernetes durante las sesiones de desarrollo. |
| **Change Failure Rate (CFR)** | **20%** (2 fallos en 10 despliegues) | **Medio** | Porcentaje de despliegues que requirieron intervención o corrección (1 fallo por vulnerabilidad `CRITICAL` detectada por Trivy y 1 fallo por visibilidad privada en GHCR/nombre de repositorio). |

### Reflexión sobre el Nivel de Desempeño DORA:
El pipeline automatizado ubica a nuestro equipo en un nivel de desempeño **Alto / Élite** en cuanto a agilidad (*Lead Time* y *Frecuencia*), debido a la ejecución encadenada de GitHub Actions y el despliegue mediante declarativa YAML. El porcentaje de fallos (20%) refleja la efectividad de los filtros de seguridad (*Fail-Fast*): el pipeline detuvo los errores en etapas tempranas antes de impactar a los usuarios.

---

## 3. OBSERVACIÓN TÉCNICA: PERSISTENCIA Y ALMACENAMIENTO EFÍMERO

### Experimento Realizado (Paso 5):
1. Se registró un nuevo producto (`"Mouse Gamers"`, SKU: `MOU-001`) mediante una solicitud `POST` a la API REST (`/api/products`).
2. Se consultó el endpoint `GET /api/products` confirmando que el producto existía en el catálogo.
3. Se forzó la eliminación del Pod que atendió la petición usando `kubectl delete pod <nombre-del-pod>`.
4. El controller `ReplicaSet` recreó inmediatamente un nuevo pod para mantener la cuota deseada.
5. Al consultar nuevamente `GET /api/products`, **el producto registrado había desaparecido**.

### Causa Raíz Técnica:
La aplicación `inventario-app` almacena el catálogo en un archivo de datos local (`data/products.json`) ubicado dentro del propio sistema de archivos del contenedor Node.js. 

En Kubernetes, los contenedores son por definición **efímeros e inmutables**. Cuando un Pod se elimina o reinicia, el contenedor se destruye junto con todo su almacenamiento local no respaldado. Al crearse el nuevo Pod, este se inicializa desde el estado base de la imagen Docker original.

### Solución en Producción:
Para evitar la pérdida de datos en un entorno productivo real, se debe desacoplar el almacenamiento montando un `PersistentVolumeClaim` (PVC) a la ruta `/app/data` o migrando la base de datos a un servicio persistente gestionado (ejemplo: PostgreSQL o MongoDB).

---

## 4. PROBLEMAS REALES ENCONTRADOS Y CÓMO SE RESOLVIERON

### Problema 1: Vulnerabilidad Crítica Detectada por Trivy (`CVE-2026-59873`)
- **Síntoma:** El job `build-push` falló en GitHub Actions con código de salida `exit code 1` durante el escaneo de seguridad de la imagen Docker. Trivy reportó 1 vulnerabilidad de severidad `CRITICAL` en la librería `tar` v7.5.15.
- **Causa:** La imagen base de Node.js incluía una versión vulnerable del paquete `tar` en las dependencias globales de npm.
- **Solución:** Se actualizó el cliente `npm` a su última versión dentro del `Dockerfile` (`RUN npm install -g npm@latest`) y se ejecutó `npm audit fix`. Al hacer `git push`, Trivy validó la imagen limpia y el pipeline finalizó en verde.

### Problema 2: Error `ImagePullBackOff` y `denied` en GHCR
- **Síntoma:** Los pods en Kubernetes mostraban el estado `ImagePullBackOff` con el mensaje de evento `Failed to pull image ... Error response from daemon: denied` al intentar descargar la imagen con un usuario de Git diferente al del propietario del repositorio.
- **Solución:** Se unificaron los nombres de la imagen en todos los YAML apuntando al propietario real del repositorio (`ghcr.io/xavierstalin/inventario-app:latest`) y se modificó la visibilidad del paquete a **Pública** en la configuración de GitHub Packages. *(Ver Evidencia `evidencias/cambioUsuariogit.png`)*.

### Problema 3: `kubectl port-forward` no balanceaba el tráfico Canary
- **Síntoma:** Al ejecutar peticiones en bucle a `http://localhost:8081/version` usando `port-forward`, el 100% de las respuestas provenían siempre del mismo Pod de la versión `v1.0-stable`.
- **Causa:** `kubectl port-forward` establece un túnel directo punto a punto hacia un único Pod específico del servicio, ignorando el balanceo de carga entre múltiples réplicas.
- **Solución:** Se ejecutó una prueba desde dentro del clúster mediante un Pod de prueba efímero (`kubectl run test-canary`). Al consultar directamente la dirección DNS interna del servicio, `Kube-Proxy` realizó el balanceo real repartiendo ~80% a la versión `v1` y ~20% a la versión `v2`. *(Ver Evidencia 1: Reparto de tráfico Canary)*.

---

## 5. RESUMEN DE EVIDENCIAS FOTOGRÁFICAS ADJUNTAS

*(En el documento final en PDF se insertan las capturas de pantalla tomadas en los pasos previos)*:

1. **Evidencia 1 (Canary):** Terminal mostrando la ejecución del pod `test-canary` intercalando respuestas de `v1.0-stable` (azul) y `v2.0-canary` (verde).
2. **Evidencia 2 (Secretos):** Salida de `kubectl exec <pod> -- printenv API_KEY` mostrando la clave `my-super-secret-api-key-12345` inyectada desde el `Secret`.
3. **Evidencia 3 (Escaneo Trivy):** Captura del log en verde de GitHub Actions con la tabla de Trivy confirmando el escaneo de vulnerabilidades `CRITICAL`.
4. **Evidencia 4 (Readiness Probe):** Salida de `kubectl describe pod` resaltando `STARTUP_DELAY_SECONDS: 10` y `Readiness: http-get ... delay=12s`.
5. **Evidencia 5 (Pérdida de Datos):** Secuencia de terminal mostrando la creación del producto `"Mouse Gamers"`, la eliminación del pod y la posterior desaparición del producto tras la recreación.

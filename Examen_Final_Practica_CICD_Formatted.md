# Examen Final - Parte 1 (Practica CI/CD)

**Apertura:** lunes, 20 de julio de 2026, 00:00
**Cierre:** lunes, 27 de julio de 2026, 00:00
**Modalidad:** En parejas

## Contexto General

Un pipeline de CI/CD que solo compila y despliega resuelve apenas la mitad del problema: falta desplegar sin arriesgar a los usuarios reales, adaptarse a picos de tráfico sin intervención humana, y poder medir objetivamente el propio desempeño. Esta tarea parte de `inventario-app` —interfaz web, API REST y base de datos local—, la cual será empleada para simular un entorno de CI/CD, como parte de una práctica de laboratorio.

---

## Parte I — Construcción y Despliegue

### Objetivo

Partiendo del repositorio `inventario-app` (interfaz web, API REST y base de datos local ya funcionando), construir y desplegar todo el pipeline: empaquetado en Docker, publicación automática vía GitHub Actions, despliegue base con rolling update, una segunda estrategia de despliegue (Blue-Green o Canary), y al menos dos componentes adicionales de buenas prácticas (manejo de secretos, escaneo de seguridad en CI, o readiness con arranque lento).

### Instrucciones — pipeline base (Docker, CI/CD, Kubernetes)

**Paso 1.** Tome el repositorio `inventario-app` como punto de partida y verifique que corre en local.

**Paso 2.** Escriba un Dockerfile multi-stage: una etapa que instale dependencias y ejecute `npm test` (el build debe fallar si las pruebas fallan), y una etapa final mínima que copie solo lo necesario para ejecutar la app — incluida la carpeta `public/` de la interfaz. Construya la imagen y pruébela en local con `docker build` / `docker run`, verificando con `curl` las rutas `/`, `/health`, `/version` y `/api/products`.

**Paso 3.** Cree un repositorio en GitHub (público) para su copia de `inventario-app` y escriba `.github/workflows/ci-cd.yml` con dos jobs encadenados: `build-test` (`npm ci` + `npm test`) y `build-push` (`needs: build-test`, publica la imagen en `ghcr.io` etiquetada con el hash del commit y con `latest`). Haga push y confirme en la pestaña Actions que el pipeline corre exitosamente y publica la imagen.

**Paso 4.** Escriba `k8s/deployment.yaml` (mínimo 2 réplicas, strategy: RollingUpdate con `maxUnavailable`/`maxSurge` en 1, y `readinessProbe`/`livenessProbe` apuntando a `/health`) y `k8s/service.yaml`. Despliegue sobre Minikube y confirme con `kubectl rollout status` y `curl` que el servicio responde correctamente.

**Paso 5.** Cree un producto desde la interfaz, y luego fuerce la eliminación y recreación del pod (por ejemplo con `kubectl delete pod` sobre uno de los pods del Deployment). Observe qué ocurre con el producto que había creado — es una consecuencia directa de cómo se armó la base de datos local de esta aplicación, no un error a corregir en esta tarea, pero debe quedar registrado en el informe de la Parte II.

### Instrucciones — segunda estrategia de despliegue (Blue-Green o Canary)

**Paso 6.** Repase la diferencia conceptual entre ambas estrategias (glosario de su README de la práctica y documento complementario de la clase), identifique qué recursos nativos de Kubernetes permitirían implementar cada una sobre su Deployment actual sin herramientas adicionales como Argo Rollouts, y elija una:

1. **Blue-Green:** dos Deployments independientes (por ejemplo `inventario-app-blue` e `inventario-app-green`), cada uno con su propia versión de la app, y un Service cuyo selector se puede cambiar de uno a otro para cortar el tráfico de forma instantánea.
2. **Canary:** dos Deployments con la misma app en distintas versiones, repartiendo el tráfico de forma desigual entre ellos aprovechando que un Service reparte tráfico de forma proporcional a la cantidad de pods que matchean su selector (por ejemplo, 1 réplica de la versión nueva contra 4 de la versión estable).

**Paso 7.** Implemente los manifiestos YAML de la estrategia elegida dentro de una carpeta `k8s/blue-green/` o `k8s/canary/` en su repositorio, según corresponda.

**Paso 8.** Si eligió Blue-Green, demuestre el corte de tráfico con evidencia de `kubectl` y `curl` antes y después de cambiar el selector del Service. Si eligió Canary, demuestre con varias peticiones repetidas que solo una fracción del tráfico llega a la versión nueva.

### Instrucciones — componentes adicionales de buenas prácticas

De los tres componentes siguientes, debe implementar al menos dos — son parte obligatoria de la tarea, cada pareja elige cuáles dos. Si implementa los tres, el que quede de más (cualquiera de los tres) suma puntos extra (+2 al examen).

- **Manejo de secretos:** cree un Secret de Kubernetes para una credencial ficticia (por ejemplo, una API_KEY inventada) y consúmala desde la aplicación vía variable de entorno con `secretKeyRef`, en vez de tenerla en texto plano en el Deployment. Debe demostrarse que esa credencial nunca queda escrita en ningún archivo versionado en Git.
- **Escaneo de seguridad en el pipeline:** agregue un paso al workflow de GitHub Actions que escanee la imagen construida con Trivy (u otra acción equivalente) antes de publicarla, y configure el paso para que el pipeline falle si encuentra vulnerabilidades de severidad CRITICAL.
- **Readiness realista con arranque lento:** agregue una variable `STARTUP_DELAY_SECONDS` que haga que `/health` responda "no listo" durante los primeros N segundos después de arrancar (simulando una app que tarda en conectar a una base de datos). Ajuste el `readinessProbe` para tolerar ese arranque sin que Kubernetes elimine el pod, y documente qué pasaría si en vez de ajustar el probe simplemente se aumentara el número de réplicas.

### Restricciones
- El Dockerfile debe ser multi-stage y debe fallar el build si `npm test` falla.
- El workflow debe seguir el principio fail-fast: `build-push` solo se ejecuta si `build-test` terminó con éxito.
- No se acepta implementar la estrategia de despliegue ni los componentes adicionales sobre un pipeline base que no despliega o cuya imagen no se publica correctamente.
- La elección de estrategia (Blue-Green o Canary) debe quedar justificada por escrito en el informe de la Parte II — no basta con implementarla sin justificar.
- No se pide usar Argo Rollouts ni ninguna herramienta adicional para la estrategia de despliegue — el efecto debe lograrse con los recursos nativos de Kubernetes (Deployment + Service).
- Cada componente adicional que se realice (obligatorio o extra) debe estar documentado en el README con los comandos exactos para reproducirlo.

## Entregables (Parte I)
- Dockerfile, `.github/workflows/ci-cd.yml`, `k8s/deployment.yaml`, `k8s/service.yaml`, y los manifiestos de la estrategia de despliegue elegida.
- Evidencia de cada etapa: build local exitoso, pipeline en verde en Actions, imagen publicada en `ghcr.io`, rollout exitoso en Minikube, y corte o reparto de tráfico de la estrategia elegida.
- Código y manifiestos de al menos dos de los tres componentes adicionales (y del tercero, si también se realizó), con su evidencia de que funciona.
- README actualizado con los comandos exactos para reproducir todo lo anterior.

---

## Parte II — Pruebas y el Informe

### Objetivo

Verificar con evidencia reproducible que todo lo construido en la Parte I funciona, calcular las propias métricas DORA a partir del trabajo realizado, y consolidar todo en un informe de reflexión.

### Instrucciones — verificación

**Paso 1.** Organice toda la evidencia recolectada en la Parte I (salidas de comandos, no solo descripciones) de forma que un tercero pueda seguir el README y reproducir cada demostración sin ayuda adicional.

### Instrucciones — métricas propias

**Paso 2.** Calcule el lead time for changes: el tiempo entre el commit de un cambio y el momento en que ese cambio quedó corriendo en el clúster (no solo publicado en `ghcr.io` — hasta el `kubectl set image` real). Repórtelo para al menos dos cambios distintos desplegados durante esta tarea.

**Paso 3.** Calcule la frecuencia de despliegue: cuántas veces se promovió un cambio al Deployment (`kubectl set image` o equivalente) durante el desarrollo de esta tarea, y en cuántos días.

**Paso 4.** Calcule el change failure rate simplificado: de todos los despliegues realizados durante esta tarea (incluyendo los de prueba y error mientras se armaba la estrategia de despliegue y los componentes adicionales), qué porcentaje requirió un rollback o una corrección posterior.

**Paso 5.** Redacte un documento de reflexión corto (PDF, 1 a 2 páginas) que incluya: la justificación de la estrategia de despliegue elegida en la Parte I, la observación sobre qué pasó con los datos del catálogo al recrear el pod (Parte I), y cualquier problema real encontrado durante la tarea y cómo se resolvió.

### Restricciones
- Las métricas deben calcularse con datos propios y verificables (timestamps de commits y de runs de Actions), no con estimaciones aproximadas.
- Encontrar y documentar un error real se evalúa positivamente, no negativamente: vale más que una entrega que "simplemente funcionó a la primera" sin evidencia de haberlo intentado.

## Entregables (Parte II)
- Enlace a su repositorio de GitHub (público), con todo el código de la Parte I y el README actualizado.
- Documento de reflexión en PDF con los tres números de DORA, la justificación de la estrategia elegida, la observación sobre persistencia de datos, y los problemas reales encontrados.

---

## Rúbrica de Calificación

La calificación se distribuye en dos bloques de distinto peso. El primero evalúa la implementación y la evidencia de ejecución real —lo que la pareja construyó y demostró que funciona—, y el segundo evalúa la justificación técnica y la documentación. El primer bloque pesa más porque el foco de esta tarea es experimentar sobre infraestructura real, no solo analizarla en papel.

### Bloque A — Parte I: Construcción y Despliegue (70 puntos)

| Dimensión | Criterio | Puntaje |
|---|---|---|
| Pipeline base construido desde cero | Dockerfile multi-stage, workflow de CI/CD funcional publicando en ghcr.io, y Deployment + Service con rolling update, todo construido sin plantillas y desplegado correctamente sobre el clúster real. | 25 pts |
| Segunda estrategia de despliegue | Blue-Green o Canary está correctamente implementada sobre el clúster real, con evidencia clara del corte o reparto de tráfico. | 25 pts |
| Componentes adicionales obligatorios (2 de 3) | Al menos dos de los tres componentes (manejo de secretos, escaneo de seguridad en CI, readiness con arranque lento) están correctamente implementados y funcionando, con evidencia real, sin importar cuáles dos haya elegido la pareja. | 20 pts |

### Bloque B — Parte II: Pruebas y el Informe (30 puntos)

| Dimensión | Criterio | Puntaje |
|---|---|---|
| Justificación de la estrategia elegida | La elección entre Blue-Green y Canary está argumentada técnicamente para el caso específico de esta aplicación, no con generalidades. | 10 pts |
| Métricas propias | Los tres números (lead time, frecuencia, change failure rate) están calculados correctamente a partir de datos propios, con una reflexión que los conecta con la tabla de niveles vista en clase. | 10 pts |
| Documentación y claridad general | El README y el documento de reflexión están redactados con claridad, permiten reproducir el trabajo por un tercero, y conectan explícitamente con los conceptos de la clase. | 10 pts |


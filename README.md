# 🏃‍♂️ Running League

**Running League** es una aplicación móvil nativa desarrollada en Flutter que gamifica la experiencia de correr. Permite a los usuarios crear ligas privadas, competir con amigos en tiempo real y escalar en rankings automatizados gestionados en la nube.

Este proyecto demuestra la implementación de un ciclo de vida completo de desarrollo móvil: desde la geolocalización en tiempo real y persistencia local, hasta la lógica de negocio en servidor (Serverless) y estrategias avanzadas de Deep Linking para el crecimiento viral.

🚧 **Estado del Proyecto:** En desarrollo activo (WIP). Próximas actualizaciones incluirán nuevas mecánicas de juego y mejoras en la analítica.

---

## 📱 Características Principales

* **📍 Tracking GPS Avanzado:** Monitorización de carrera en tiempo real con superposición en mapas (OpenStreetMap/Flutter Map). Incluye gestión de permisos de ubicación en segundo plano y optimización de batería.
* **🗣️ Feedback por Voz (TTS):** Asistente de voz integrado que narra el ritmo, distancia y tiempo cada kilómetro mediante Text-to-Speech.
* **🏆 Sistema de Ligas y Rankings:** Creación de grupos privados y visualización de tablas de clasificación dinámicas sincronizadas con Firestore.
* **🔗 Deep Linking & Viralidad:** Invitación a ligas mediante enlaces inteligentes (https://running-league-app.web.app/unirse...) compatibles con Android App Links, permitiendo unirse directamente desde WhatsApp sin pasar por el navegador.
* **🤖 Árbitros en la Nube (Backend):** Lógica Serverless que se ejecuta automáticamente (Cron Jobs) para calcular ganadores semanales y mensuales sin intervención humana.

---

## 🛠️ Stack Tecnológico

### Frontend (Flutter)
* **Lenguaje:** Dart.
* **Mapas:** `flutter_map` con `latlong2`.
* **Servicios:** `geolocator` para tracking GPS, `flutter_tts` para síntesis de voz.
* **Persistencia Local:** `sqflite` (SQLite) para guardar historial de carreras offline.
* **State Management:** Gestión reactiva mediante `Streams` y `setState` optimizado.

### Backend & Cloud (Firebase)
* **Auth:** Autenticación segura con Google Sign-In.
* **Firestore:** Base de datos NoSQL en tiempo real para sincronización de ligas y usuarios.
* **Cloud Functions (Node.js):**
    * Scripts programados (`pubsub.schedule`) para el cierre de ligas (Domingos 23:59).
    * Lógica de negocio para filtrado de datos "anti-trampas" y asignación de bonus.
* **Hosting:** Alojamiento de `assetlinks.json` para verificación de dominio y App Links seguros (SHA-256 verificado).

---

## 🏗️ Retos Técnicos Superados

### 1. Geolocalización y Segundo Plano
Implementación de un servicio robusto capaz de mantener el rastreo GPS incluso con la pantalla apagada, gestionando los **Wake Locks** de Android y solicitando permisos de exención de optimización de batería para evitar que el sistema operativo mate el proceso.

### 2. Deep Linking en Android 12+
Configuración de App Links verificados mediante la asociación de la huella digital **SHA-256** de la Keystore de producción con un subdominio de Firebase Hosting. Esto soluciona las restricciones de seguridad modernas de Android, permitiendo que la App se abra nativamente desde enlaces compartidos en redes sociales.

### 3. Lógica Serverless (Cloud Functions 2nd Gen)
Desarrollo de "Cron Jobs" en Node.js desplegados en Google Cloud.

* **Reto:** Evitar que los usuarios ganen puntos simplemente acumulando carreras cortas o bonus anteriores.
* **Solución:** Algoritmo en servidor que filtra actividades tipo `esBonus: true` y calcula el volumen real de kilómetros para otorgar premios de forma justa y automática.

---

## 📸 Galería

| <img src="https://github.com/user-attachments/assets/e01e3c18-a1b5-4f1d-975c-be57eed3d7f1" width="250" /> | <img src="https://github.com/user-attachments/assets/c75abc9c-ea43-442e-8ed4-367cd3d918e7" width="250" /> | <img src="https://github.com/user-attachments/assets/9085577c-7795-4c97-aa25-099181704928" width="250" /> |
| :---: | :---: | :---: |
| <img src="https://github.com/user-attachments/assets/ff9bfa93-dda8-45e1-ba0e-e9aaf64ef460" width="250" /> | <img src="https://github.com/user-attachments/assets/e15fb6e0-2665-42c8-9c90-845ef341949e" width="250" /> | <img src="https://github.com/user-attachments/assets/4cf1dc61-715d-4a7a-baa6-34dfee9348a0" width="250" /> |

---

## 🚀 Cómo ejecutar el proyecto

**1º) Clonar el repositorio:**
```bash
git clone [https://github.com/tu-usuario/running_league.git](https://github.com/tu-usuario/running_league.git)
```
**2º) Configuración de Firebase:**

Añadir `google-services.json` en `android/app/`.

Habilitar Auth (Google), Firestore y Functions en la consola.

**3º) Instalar dependencias:**
```bash
flutter pub get
```

**4º) Ejecutar:**
```bash
flutter run
```
---

## 📲 Prueba la Aplicación
**También puedes contactarme para probar la APK disponible para Android.**

---

## 👨‍💻 Autor y Contacto

Desarrollado por **Jose María Clavijo Basáñez.**

Si tienes interés en el código, la arquitectura o quieres colaborar, contáctame en:

* **📧 Email: pclavijobasanez@gmail.com**
* **💼 LinkedIn: www.linkedin.com/in/jose-maría-clavijo-basáñez**


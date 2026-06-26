# Meds Tracker 💊

**Meds Tracker** es una aplicación móvil diseñada para ayudar a las personas a gestionar, registrar y cumplir con sus tratamientos médicos y toma de suplementos diarios de manera rigurosa y ordenada. 

La aplicación destaca por su enfoque en una experiencia de usuario limpia, adaptativa y robusta, asegurando que el usuario nunca pierda una toma gracias a alertas del sistema de alta prioridad.

---

## 🚀 ¿Qué hace la aplicación? (Características Principales)

- **Línea de Tiempo Diaria:** Muestra los medicamentos programados para el día actual ordenados cronológicamente.
  - Las tomas completadas ("Tomado" o "Perdido") se compactan visualmente para mantener el foco en las tareas pendientes.
  - Permite registrar tomas tardías directamente sobre medicamentos que fueron marcados previamente como "Perdidos".
  - Filtra automáticamente las alertas pospuestas para evitar duplicados ruidosos en la lista.
- **Gráfico de Progreso Semanal:** Representa de manera visual (mediante anillos circulares de colores con las iniciales de cada día) la tasa de cumplimiento del usuario a lo largo de la semana actual.
- **Gestión Completa de Medicamentos (CRUD):** Permite registrar, editar y eliminar medicamentos de forma segura.
  - La eliminación está protegida dentro del menú de edición para evitar pérdidas accidentales de datos.
- **Programación Flexible:** Admite configurar recordatorios diarios o para días específicos de la semana con horarios personalizados.
- **Alertas y Alarmas de Alta Prioridad:** Utiliza alarmas del sistema y notificaciones nativas de Android.
  - Soporta pantallas de bloqueo (bloqueo por overlay) para alertar al usuario incluso si el dispositivo está inactivo.
  - Capacidad de posponer alarmas (snooze) por 15 minutos.
- **Modo Oscuro / Claro Adaptativo:** Interfaz de usuario de diseño premium con soporte para temas Claro, Oscuro y adaptativo según el sistema operativo.

---

## 🛠️ Tecnologías Utilizadas

El proyecto está construido sobre un stack móvil moderno que aprovecha capacidades multiplataforma y nativas:

- **Flutter & Dart:** Framework principal utilizado para el desarrollo de la interfaz de usuario reactiva y la lógica de la aplicación.
- **SQLite (sqflite):** Motor de base de datos relacional ligero utilizado localmente en el dispositivo para persistir la información de los medicamentos, alarmas programadas e historial de cumplimiento de forma segura.
- **SharedPreferences:** Almacenamiento clave-valor utilizado para persistir la configuración de las preferencias del usuario, como el tema de la interfaz (Claro/Oscuro/Sistema).
- **Method Channels (Android Native integration):**
  - Canal de comunicación bidireccional entre Flutter y código nativo de Android (Kotlin/Java) para gestionar tareas del sistema de bajo nivel.
  - **Servicio de Alarmas Exactas (`AlarmManager`):** Para agendar notificaciones precisas al segundo exacto.
  - **Overlay Permissions & Full-Screen Intent:** Para lanzar y pintar la interfaz de alarma sobre la pantalla de bloqueo y otras aplicaciones en primer plano.

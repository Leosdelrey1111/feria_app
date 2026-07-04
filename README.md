# Mi Feria Inteligente (App Móvil - Flutter)

Este proyecto implementa la aplicación móvil para **"Mi Feria Inteligente"**, una plataforma diseñada para digitalizar la gestión de ferias y eventos masivos. Se construyó siguiendo las especificaciones del entregable de la Unidad II, utilizando **Flutter (Material Design 3)**, **Riverpod** para la gestión de estado y **go_router** para la navegación.

---

## 🚀 Cómo Correr el Proyecto

### Requisitos Previos
1. Tener instalado [Flutter](https://docs.flutter.dev/get-started/install) (Canal stable).
2. Tener configurado un Emulador Android (mínimo API 26 / Android 8.0) o dispositivo físico en modo desarrollador.

### Instrucciones de Ejecución
1. Descarga o abre el proyecto en tu terminal.
2. Navega al directorio raíz del proyecto.
3. Descarga las dependencias ejecutando:
   ```bash
   flutter pub get
   ```
4. Ejecuta la aplicación utilizando:
   ```bash
   flutter run
   ```

---

## 📱 Alcance Funcional (8 Pantallas Implementadas)

1. **M-01: Registro e Inicio de Sesión:**
   - Formulario completo con validación y entrada para **Modo Visitante** (bloquea la compra de boletos, el wallet y la agenda personal).
   - Acceso alternativo simulado con Google.
   - Envío de correo de recuperación ficticio ("¿Olvidaste tu contraseña?").
   - Mensaje de sincronización ficticio con Smartwatch Wear OS en el arranque.

2. **M-02: Inicio y Programa del Evento (Hub Principal):**
   - Banner animado del evento ("En vivo").
   - Tarjeta de actividad destacada con la opción "Ver en TV" (ecosistema Smart TV).
   - Tarjeta de acceso rápido a "Mi Boleto QR" (Wallet).
   - Lista interactiva de actividades agrupadas por fecha (tabs para Día 1, 2 y 3) y filtrado rápido mediante Chips de categorías (Música, Concursos, Arte, Gastronomía, Infantil).
   - Capacidad de marcar actividades como favoritas.

3. **M-03: Detalle de Actividad:**
   - Información ampliada (ponente, fecha, horario, duración, lugar).
   - Botón "Ver en mapa" que redirige al mapa con el pin de esta actividad preseleccionado y centrado.
   - Recordatorio automático configurable según las preferencias definidas en el perfil (dispara notificaciones locales nativas con `flutter_local_notifications`).
   - Botón de compartir actividad mediante redes sociales usando `share_plus`.
   - Módulo de reacciones rápidas animadas (👍, ❤️, 😲, 😱) con persistencia local en tiempo de ejecución.

4. **M-04: Mapa Interactivo del Evento:**
   - Mapa esquemático vectorial del recinto dibujado dinámicamente (`CustomPainter`) que permite zoom y arrastre (`InteractiveViewer`).
   - Filtros de visualización (Escenarios, Baños, Comida, Primeros Auxilios, Salidas de Emergencia).
   - Visualización del pin de ubicación del usuario en tiempo real con permisos de `geolocator` (con simulación interna integrada como fallback).
   - Buscador interactivo por texto de los stands o escenarios.
   - Botón "Descargar mapa" para soporte sin conexión (simula progreso de descarga).

5. **M-05: Compra y Reserva de Boletos:**
   - Catálogo de tarifas (General, VIP, Familiar).
   - Control de accesos (cantidad de boletos y selector de fecha de visita).
   - Resumen financiero de la orden con desglose de impuestos (IVA 16%).
   - Métodos de pago simulados (Tarjeta, OXXO, Transferencia, PayPal).
   - Opción "Reserva gratuita, pago en taquilla" (guarda el boleto en estado "Reservado" a coste cero).
   - Verificación de Modo Visitante (bloquea la compra y exige login).

6. **M-06: Mis Boletos (Wallet Digital):**
   - Listado de boletos activos y reservas con códigos QR únicos autogenerados (`qr_flutter`).
   - Sección de historial de boletos pasados.
   - Opciones simuladas para "Agregar a Google Wallet" y "Transferir boleto" mediante correo electrónico del destinatario.
   - Verificación de Modo Visitante (bloquea la visualización del Wallet).

7. **M-07: Encuestas y Votaciones:**
   - Visualización de votaciones activas con barra de resultados que se actualiza dinámicamente cada 3 segundos (simulación de WebSocket en vivo).
   - Panel de votación rápida e historial de encuestas pasadas de la feria.

8. **M-08: Mi Perfil, Configuración y Vinculación:**
   - Avatar del usuario, nombre y correo electrónico con persistencia en `shared_preferences`.
   - Modificación de anticipación de alertas (5, 10, 15 min) para la programación de recordatorios.
   - Toggles funcionales de nivel de notificaciones push e idioma (español/inglés).
   - Sincronización simulada del ecosistema: Smartwatch (Wear OS) y Smart TV (muestra/copia código de vinculación).
   - Interruptor de **Modo Oscuro/Claro** completamente funcional que altera el tema de toda la app (`ThemeMode`).
   - Botones para cerrar sesión y eliminar cuenta.

---

## 🛠️ Arquitectura del Código

El código está estructurado bajo el patrón **Feature-First / Clean-ish**, separando responsabilidades:

- `lib/models/`: Declaración de los esquemas e interfaces de datos (`Activity`, `Ticket`, `Poll`).
- `lib/services/`: Capas lógicas dedicadas a llamadas externas de red y almacenamiento local (`AuthService`, `ActivityService`, `TicketService`, `PollService`, `NotificationService`).
- `lib/providers/`: Manejadores de estado reactivo utilizando Riverpod (`authProvider`, `activityProvider`, `ticketProvider`, `pollProvider`, `themeProvider`).
- `lib/screens/`: Pantallas de la UI agrupadas por módulos.
- `lib/router/`: Control de rutas jerárquicas y declarativas con `go_router`.
- `lib/theme/`: Estilos centralizados y paletas de colores (Violeta `#6C63FF` y Coral `#FF6584`).

---

## 🔄 Conexión a un Backend Real (Mock vs Producción)

Para conectar esta aplicación móvil a un servidor real, solo necesitas reemplazar las implementaciones dentro de la carpeta `lib/services/`:

1. **Autenticación (`auth_service.dart`):**
   - *Actualmente:* Guarda datos en `SharedPreferences` de forma local y simula llamadas exitosas.
   - *Producción:* Realizar peticiones HTTP POST (usando `dio`) a un endpoint `/api/auth/login` y almacenar el Token JWT devuelto.

2. **Actividades (`activity_service.dart`):**
   - *Actualmente:* Retorna una lista estática de 10 actividades configuradas de manera relativa al día de ejecución.
   - *Producción:* Consumir `/api/activities` y mapear la respuesta JSON al modelo `Activity`.

3. **Boletos (`ticket_service.dart`):**
   - *Actualmente:* Almacena boletos serializados en formato JSON en `SharedPreferences`.
   - *Producción:* Integrar una pasarela de pago real (como Stripe SDK) y enviar el ticket al servidor mediante POST `/api/tickets/purchase`.

4. **Votaciones en Vivo (`poll_service.dart`):**
   - *Actualmente:* Usa un `Stream.periodic` para simular flujos de datos.
   - *Producción:* Instalar `web_socket_channel` y escuchar un canal de WebSocket real de Phoenix/Node.js para recibir los cambios porcentuales instantáneos.

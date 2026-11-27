# Enlace USB serial del prototipo

El puerto serial del ESP32 está configurado a **115 200 baudios**. El sketch lee comandos de texto terminados por salto de línea. El código de visión los escribe con esa terminación y extrae las RPM de las líneas recibidas.

| Dirección | Mensaje | Función |
| --- | --- | --- |
| Python → ESP32 | Entero entre `0` y `170` | Fija la consigna en rpm. `0` detiene el motor. |
| Terminal → ESP32 | `RPM` | Solicita una lectura de RPM. |
| Python o terminal → ESP32 | `ROJO`, `AMARILLO` o `VERDE` | Comunica el color al firmware. El sketch determina cuándo activar el desviador. |
| ESP32 → Python | Texto con `RPM deseadas:` y `RPM reales:` | Permite leer consigna y medición del encoder. |

La implementación está en `enviar_comando` y `leer_esp32` del programa Python y en el procesamiento de comandos y telemetría de `sketch_nov24a.ino`. El enlace entre este puerto y CoppeliaSim queda pendiente. [Programa de visión](../03_Vision_Artificial/prueba_camara.py) · [Firmware](../02_Control_ESP32/sketch_nov24a/sketch_nov24a.ino)

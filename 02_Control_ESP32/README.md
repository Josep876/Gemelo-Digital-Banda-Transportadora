# Control del ESP32

El sketch `sketch_nov24a/sketch_nov24a.ino` es la versión local del 6 de noviembre de 2026 que coincide con el programa de visión entregado. El cable USB lleva comandos y lectura de RPM a 115 200 baudios. El sketch usa el núcleo Arduino-ESP32 y su API LEDC, sin dependencias de bibliotecas Arduino adicionales declaradas en el código.

1. Abre el archivo en Arduino IDE 2.x con el núcleo de placas **esp32 by Espressif Systems 2.0.17**.
2. Selecciona la placa ESP32 que estés usando y el puerto USB. En el código se declaran GPIO 25, 33 y 32 para el control del motor, GPIO 27 para el servo y GPIO 35 para la entrada A del encoder. Contrasta el cableado con esas declaraciones antes de cargar el sketch.
3. Usa **Verificar** para compilar. Para cargarlo en el banco, selecciona **Subir** desde el IDE. El monitor serial puede probar los comandos con fin de línea, y debe quedar cerrado cuando Python abra el mismo puerto.

El núcleo 2.x incluye `ledcSetup` y `ledcAttachPin`, las llamadas que usa esta versión. [Guía de migración de Espressif](https://docs.espressif.com/projects/arduino-esp32/en/latest/migration_guides/2.x_to_3.0.html) · [Protocolo serial](../04_Documentacion/Protocolo_serial.md)

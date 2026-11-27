# Visión artificial

`prueba_camara.py` es la versión local del 6 de noviembre de 2026. Procesa la imagen de la webcam USB con OpenCV, lee las RPM del ESP32 y permite enviar comandos de color y velocidad por el puerto serial.

1. Desde esta carpeta, instala las dependencias del entorno registrado con `python -m pip install -r requirements.txt`, preferiblemente dentro de un entorno virtual de Python 3.11.
2. Abre `prueba_camara.py` y ajusta `PUERTO` y `CAMARA_INDEX` a tu equipo. Los valores existentes son `COM4` y `0`. El ESP32 debe estar conectado con el firmware de [02_Control_ESP32](../02_Control_ESP32/README.md).
3. Con el prototipo preparado y el monitor serial cerrado, ejecuta `python prueba_camara.py`. El programa envía al arrancar la consigna inicial de 90 rpm. En la ventana se puede llevar a 0 rpm o ajustar la consigna con la barra de velocidad.

La detección usa máscaras HSV y contornos. El programa y el sketch comparten el protocolo local descrito en la documentación. [Protocolo serial](../04_Documentacion/Protocolo_serial.md)

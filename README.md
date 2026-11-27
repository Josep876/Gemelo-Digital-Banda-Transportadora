# Gemelo digital de la banda transportadora

**V2.1 — Validación mecánica y simulación dinámica preliminar**

Proyecto de grado para desarrollar un gemelo digital bidireccional que detecte y diagnostique fallas de una banda transportadora física en tiempo real. Esta versión reúne el ensamblaje validado en CAD, la simulación dinámica preliminar y el código existente de control y visión del prototipo.

## Arquitectura del proyecto

| Parte | Qué hace en V2.1 |
| --- | --- |
| Autodesk Inventor | Define la geometría, los materiales y las relaciones mecánicas del transportador. El STEP, las mallas STL y el manifiesto sirven de entrada para la escena. |
| CoppeliaSim | Simula el transporte, la clasificación y la dinámica equivalente del motor, el acople y la banda. Ejecuta casos de falla con datos sintéticos. |
| ESP32 | Aplica PWM al motor y al servomotor. Lee el encoder y transmite las RPM registradas por USB serial. |
| Python y OpenCV | Procesan la imagen de la webcam USB, detectan piezas por color e intercambian consignas y telemetría con el ESP32. |

La comunicación incluida une el ESP32 y el programa de visión. La sincronización entre CoppeliaSim y el prototipo físico, la comparación en vivo con el modelo esperado y el diagnóstico físico en tiempo real siguen pendientes. [Protocolo serial del prototipo](04_Documentacion/Protocolo_serial.md)

## Banda y componentes

- Banda continua de hule SBR con inserción textil, de 100 mm de ancho y 1 mm de espesor en el CAD. El ramal superior se apoya en seis soportes transversales de PLA.
- Bastidor y rieles, rodillos motriz y conducidos, rodamientos, soportes, piezas impresas en PLA grafito y desviador accionado por servomotor.
- Motorreductor JGA25 con encoder, eje de salida D4 y arrastre directo del rodillo mediante prisionero M3×4.
- ESP32, etapa de potencia del motor, servomotor del desviador y webcam USB. El código registra los GPIO y parámetros usados por el prototipo.

## Contenido

| Carpeta | Contenido |
| --- | --- |
| `01_CAD/BANDA TRANSPORTADORA VALIDACION MECANICA V2` | Proyecto Inventor, ensambles y piezas con sus dependencias, texturas, STEP, escena y mallas, scripts Lua, parámetros, resultados, capturas e informe técnico. |
| `02_Control_ESP32` | Sketch actual y notas de compilación. |
| `03_Vision_Artificial` | Programa de cámara, dependencias y notas de ejecución. |
| `04_Documentacion` | Protocolo serial, informes del prototipo e instrucciones de portabilidad. |

Consulta el detalle del montaje, las interferencias residuales y los ensayos en el [informe técnico de fase 2.1](<01_CAD/BANDA TRANSPORTADORA VALIDACION MECANICA V2/INFORME_FASE_2_1.html>). Descarga o clona el repositorio para abrir el HTML y sus archivos vinculados desde una misma carpeta.

## Descargar y abrir

1. Una vez recibido el acceso al repositorio privado, abre su página en GitHub. Usa **Code → Download ZIP** y descomprime el conjunto, o copia la URL HTTPS de **Code** y úsala con `git clone`. En Windows conviene extraerlo en una ruta corta.
2. En **Inventor 2025.3**, abre **Proyectos → Examinar** y activa `Banda_Transportadora_V21.ipj` dentro de la carpeta CAD. Abre `ESAMBLAJECOMPLETO_VALIDADO_SIMULACION_V2.iam` desde ahí. Conserva las subcarpetas `Texturas` y `BANDA_TRANSPORTADORA_PLA_SBR_FINAL/AIP/FEA`. [Portabilidad en Inventor](04_Documentacion/Portabilidad.md)
3. En **CoppeliaSim Edu 4.10.0**, abre `EXPORTACION_COPPELIASIM/Banda_clasificadora_V2.ttt`. La escena ya contiene sus objetos y scripts. Los resultados registrados se pueden revisar sin ejecutar nuevos ensayos. Si quieres reproducir la batería de casos o reconstruir la escena, usa otra copia de la carpeta CAD y sigue la guía. [Escena, scripts y parámetros](04_Documentacion/Portabilidad.md#coppeliasim)
4. Revisa el sketch en **Arduino IDE 2.x** con el núcleo **Arduino-ESP32 2.0.17**. Revisa el programa de visión con **Python 3.11** y las dependencias especificadas. Ajusta el puerto COM y el índice de cámara en tu copia. [ESP32](02_Control_ESP32/README.md) · [Visión artificial](03_Vision_Artificial/README.md)

## Avances y resultados

- **CAD.** El ensamble V2.1 conserva las apariencias y materiales asignados a la banda y a las piezas impresas. Incorpora el motorreductor con encoder y la corrección del acoplamiento directo. El CAD registró tangencias en cinco rodillos y asiento en los seis apoyos. Quedan cinco interferencias B-Rep residuales descritas en el informe.
- **Transporte y clasificación simulados.** Se evaluaron 16 casos. Las cuatro consignas de transporte completaron el recorrido del testigo. El desviador se probó a −40° y +40° y clasificó hacia ambos lados. En posición neutra se observó deriva lateral dependiente de la consigna.
- **Dinámica simulada.** A 170 rpm de consigna, el caso de referencia calculó 0,2409 m/s de banda. Con más fricción y 80 g de carga simulada se obtuvieron 0,1912 m/s. Los escenarios de falla incluyen resistencia adicional en apoyos, atasco, prisionero aflojado, desacoplamiento, tracción reducida y deriva sintética del encoder. [Resultados JSON](<01_CAD/BANDA TRANSPORTADORA VALIDACION MECANICA V2/EXPORTACION_COPPELIASIM/Resultados-V21.json>) · [Animación](<01_CAD/BANDA TRANSPORTADORA VALIDACION MECANICA V2/Capturas/Recorrido-y-clasificacion-derecha.gif>)
- **Prototipo físico.** Los documentos de instrumentación, control de calidad y avance de visión registran el trabajo en el banco a sus respectivas fechas. Los resultados dinámicos de V2.1 proceden de la simulación, con el prototipo y el ESP32 fuera del bucle. [Documentación de apoyo](04_Documentacion/README.md)

## Trabajo pendiente

- Calibrar la curva par–velocidad, la fricción del laminado, la pretensión, las fuerzas de apoyo y el ángulo real del desviador.
- Medir de forma independiente la velocidad de la banda o del rodillo para distinguir deslizamiento de pérdida de acople. Ajustar la calibración óptica y temporal de la cámara.
- Resolver o confirmar en el prototipo las interferencias documentadas.
- Integrar CoppeliaSim con el control físico y validar el diagnóstico de fallas en tiempo real con ensayos instrumentados.

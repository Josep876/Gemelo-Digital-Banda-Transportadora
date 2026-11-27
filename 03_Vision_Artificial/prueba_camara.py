import cv2
import numpy as np
import serial
import time
import re


# ============================================================
# CONFIGURACION GENERAL
# ============================================================

# Webcam utilizada por la banda
CAMARA_INDEX = 0

# Puerto del ESP32
PUERTO = "COM4"

# Debe coincidir con Serial.begin(115200) del ESP32
BAUDIOS = 115200

# Area minima para considerar que realmente hay una pieza
AREA_MINIMA = 1000

# Tiempo que debe desaparecer la pieza antes
# de permitir una nueva deteccion
TIEMPO_LIBERACION = 0.5


# ============================================================
# HSV - ROJO
# ============================================================
#
# El rojo aparece en dos extremos del espacio HSV.
# Por eso se utilizan dos rangos.
#
# Si tus valores anteriores funcionaban mejor,
# reemplaza solamente estos limites.
# ============================================================

ROJO_BAJO_1 = np.array([0, 100, 80])
ROJO_ALTO_1 = np.array([10, 255, 255])

ROJO_BAJO_2 = np.array([170, 100, 80])
ROJO_ALTO_2 = np.array([179, 255, 255])


# ============================================================
# HSV - AMARILLO
# ============================================================

AMARILLO_BAJO = np.array([20, 100, 100])
AMARILLO_ALTO = np.array([35, 255, 255])


# ============================================================
# VARIABLES DEL SISTEMA
# ============================================================

rpm_deseadas = 90
rpm_reales = 0.0

ultimo_color = "NINGUNO"

pieza_activa = False
ultimo_instante_pieza = 0

ultimo_valor_enviado_rpm = None

esp32 = None


# ============================================================
# CONECTAR ESP32
# ============================================================

try:

    esp32 = serial.Serial(
        PUERTO,
        BAUDIOS,
        timeout=0.05
    )

    print()
    print("====================================")
    print(" ESP32 CONECTADO")
    print("====================================")
    print("Puerto:", PUERTO)
    print("Baudios:", BAUDIOS)
    print()

    # Al abrir el puerto el ESP32 puede reiniciarse
    time.sleep(2)

    esp32.reset_input_buffer()

except Exception as error:

    print()
    print("ERROR: no se pudo abrir", PUERTO)
    print(error)
    print()
    print("Revisa:")
    print("- Que el Monitor Serial este cerrado")
    print("- Que el ESP32 este conectado")
    print("- Que el puerto COM sea correcto")

    raise SystemExit


# ============================================================
# FUNCION PARA ENVIAR COMANDOS AL ESP32
# ============================================================

def enviar_comando(comando):

    try:

        texto = str(comando).strip()

        esp32.write(
            (texto + "\n").encode("utf-8")
        )

        esp32.flush()

        print(">> ENVIADO:", texto)

    except Exception as error:

        print(
            "Error enviando comando:",
            error
        )


# ============================================================
# LEER INFORMACION DEL ESP32
# ============================================================

def leer_esp32():

    global rpm_reales
    global rpm_deseadas

    try:

        while esp32.in_waiting > 0:

            linea = (
                esp32.readline()
                .decode(
                    "utf-8",
                    errors="ignore"
                )
                .strip()
            )

            if not linea:
                continue


            # Mostrar informacion en consola
            print("ESP32:", linea)


            # =================================================
            # FORMATO:
            #
            # RPM deseadas: 90 | RPM reales: 72.73
            # =================================================

            coincidencia = re.search(
                r"RPM deseadas:\s*([0-9.]+)"
                r".*?"
                r"RPM reales:\s*([0-9.]+)",
                linea
            )

            if coincidencia:

                rpm_deseadas = int(
                    float(
                        coincidencia.group(1)
                    )
                )

                rpm_reales = float(
                    coincidencia.group(2)
                )

                continue


            # =================================================
            # POR SI APARECE:
            #
            # RPM reales: 72.73
            # =================================================

            coincidencia_real = re.search(
                r"RPM real(?:es)?:\s*([0-9.]+)",
                linea
            )

            if coincidencia_real:

                rpm_reales = float(
                    coincidencia_real.group(1)
                )

    except Exception as error:

        print(
            "Error leyendo ESP32:",
            error
        )


# ============================================================
# FUNCION DE LA BARRA DE RPM
# ============================================================

def cambiar_rpm(valor):

    global rpm_deseadas
    global ultimo_valor_enviado_rpm

    valor = int(valor)

    # Limite real del motorreductor
    valor = max(
        0,
        min(
            170,
            valor
        )
    )

    rpm_deseadas = valor


    # Evitar enviar repetidamente el mismo valor
    if valor != ultimo_valor_enviado_rpm:

        enviar_comando(
            valor
        )

        ultimo_valor_enviado_rpm = valor


# ============================================================
# LIMPIAR MASCARA
# ============================================================

kernel = np.ones(
    (5, 5),
    np.uint8
)


def limpiar_mascara(mascara):

    mascara = cv2.morphologyEx(
        mascara,
        cv2.MORPH_OPEN,
        kernel
    )

    mascara = cv2.morphologyEx(
        mascara,
        cv2.MORPH_CLOSE,
        kernel
    )

    return mascara


# ============================================================
# BUSCAR CONTORNO
# ============================================================

def buscar_objeto(mascara):

    contornos, _ = cv2.findContours(
        mascara,
        cv2.RETR_EXTERNAL,
        cv2.CHAIN_APPROX_SIMPLE
    )

    mejor_contorno = None
    mayor_area = 0


    for contorno in contornos:

        area = cv2.contourArea(
            contorno
        )

        if (
            area > AREA_MINIMA
            and
            area > mayor_area
        ):

            mejor_contorno = contorno
            mayor_area = area


    return mejor_contorno, mayor_area


# ============================================================
# ABRIR CAMARA
# ============================================================

camara = cv2.VideoCapture(
    CAMARA_INDEX
)


if not camara.isOpened():

    print()
    print(
        "ERROR: no se pudo abrir "
        "la camara indice",
        CAMARA_INDEX
    )

    esp32.close()

    raise SystemExit


# ============================================================
# CREAR VENTANA
# ============================================================

NOMBRE_VENTANA = (
    "Banda transportadora - Vision y Control"
)

cv2.namedWindow(
    NOMBRE_VENTANA
)


# ============================================================
# CREAR BARRA RPM
# ============================================================
#
# Rango:
# 0 - 170 RPM
#
# ============================================================

cv2.createTrackbar(
    "RPM",
    NOMBRE_VENTANA,
    rpm_deseadas,
    170,
    cambiar_rpm
)


# Enviar velocidad inicial
enviar_comando(
    rpm_deseadas
)

ultimo_valor_enviado_rpm = (
    rpm_deseadas
)


print()
print("====================================")
print(" SISTEMA LISTO")
print("====================================")
print()
print("La barra RPM controla el motor.")
print()
print("0 RPM   = motor detenido")
print("90 RPM  = velocidad media")
print("170 RPM = referencia maxima")
print()
print("ROJO     -> desviador")
print("AMARILLO -> desviador")
print("VERDE    -> pasa derecho")
print()
print("Presiona Q para cerrar.")
print()


# ============================================================
# BUCLE PRINCIPAL
# ============================================================

while True:

    ahora = time.time()


    # ========================================================
    # LEER ESP32
    # ========================================================

    leer_esp32()


    # ========================================================
    # LEER CAMARA
    # ========================================================

    ret, frame = camara.read()


    if not ret:

        print(
            "ERROR: no se pudo leer la camara."
        )

        break


    # ========================================================
    # CONVERTIR BGR -> HSV
    # ========================================================

    hsv = cv2.cvtColor(
        frame,
        cv2.COLOR_BGR2HSV
    )


    # ========================================================
    # DETECCION DE ROJO
    # ========================================================

    mascara_rojo_1 = cv2.inRange(
        hsv,
        ROJO_BAJO_1,
        ROJO_ALTO_1
    )

    mascara_rojo_2 = cv2.inRange(
        hsv,
        ROJO_BAJO_2,
        ROJO_ALTO_2
    )

    mascara_rojo = cv2.bitwise_or(
        mascara_rojo_1,
        mascara_rojo_2
    )


    # ========================================================
    # DETECCION DE AMARILLO
    # ========================================================

    mascara_amarillo = cv2.inRange(
        hsv,
        AMARILLO_BAJO,
        AMARILLO_ALTO
    )


    # ========================================================
    # LIMPIAR RUIDO
    # ========================================================

    mascara_rojo = limpiar_mascara(
        mascara_rojo
    )

    mascara_amarillo = limpiar_mascara(
        mascara_amarillo
    )


    # ========================================================
    # BUSCAR PIEZAS
    # ========================================================

    contorno_rojo, area_rojo = (
        buscar_objeto(
            mascara_rojo
        )
    )

    contorno_amarillo, area_amarillo = (
        buscar_objeto(
            mascara_amarillo
        )
    )


    # ========================================================
    # DETERMINAR COLOR
    # ========================================================

    color_detectado = None

    contorno_detectado = None

    area_detectada = 0


    # ROJO
    if (
        contorno_rojo is not None
        and
        area_rojo > area_detectada
    ):

        color_detectado = "ROJO"

        contorno_detectado = (
            contorno_rojo
        )

        area_detectada = area_rojo


    # AMARILLO
    if (
        contorno_amarillo is not None
        and
        area_amarillo > area_detectada
    ):

        color_detectado = "AMARILLO"

        contorno_detectado = (
            contorno_amarillo
        )

        area_detectada = (
            area_amarillo
        )


    # ========================================================
    # PIEZA DETECTADA
    # ========================================================

    if color_detectado is not None:

        ultimo_instante_pieza = ahora


        # Dibujar pieza
        x, y, w, h = cv2.boundingRect(
            contorno_detectado
        )


        cv2.rectangle(
            frame,
            (x, y),
            (x + w, y + h),
            (255, 255, 255),
            2
        )


        cv2.putText(
            frame,
            color_detectado,
            (
                x,
                max(
                    25,
                    y - 10
                )
            ),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.8,
            (255, 255, 255),
            2
        )


        # ====================================================
        # SOLO UNA ORDEN POR PIEZA
        # ====================================================

        if not pieza_activa:

            ultimo_color = (
                color_detectado
            )


            enviar_comando(
                color_detectado
            )


            pieza_activa = True


    # ========================================================
    # NO HAY ROJO NI AMARILLO
    # ========================================================
    #
    # Puede ser:
    #
    # - una pieza verde
    # - banda vacia
    #
    # En ambos casos NO se mueve el servo.
    #
    # ========================================================

    else:

        if (
            pieza_activa
            and
            ahora - ultimo_instante_pieza
            >
            TIEMPO_LIBERACION
        ):

            pieza_activa = False


    # ========================================================
    # PANEL DE INFORMACION
    # ========================================================

    cv2.rectangle(
        frame,
        (10, 10),
        (445, 155),
        (0, 0, 0),
        -1
    )


    # COLOR
    cv2.putText(
        frame,
        "Ultimo color: " + ultimo_color,
        (20, 42),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.65,
        (255, 255, 255),
        2
    )


    # RPM DESEADAS
    cv2.putText(
        frame,
        f"RPM solicitadas: {rpm_deseadas}",
        (20, 75),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.65,
        (255, 255, 255),
        2
    )


    # RPM REALES
    cv2.putText(
        frame,
        f"RPM reales: {rpm_reales:.2f}",
        (20, 108),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.65,
        (255, 255, 255),
        2
    )


    # MOTOR
    if rpm_deseadas == 0:

        estado_motor = "DETENIDO"

    else:

        estado_motor = "ENCENDIDO"


    cv2.putText(
        frame,
        "Motor: " + estado_motor,
        (20, 141),
        cv2.FONT_HERSHEY_SIMPLEX,
        0.65,
        (255, 255, 255),
        2
    )


    # ========================================================
    # MOSTRAR IMAGEN
    # ========================================================

    cv2.imshow(
        NOMBRE_VENTANA,
        frame
    )


    # ========================================================
    # TECLADO
    # ========================================================

    tecla = (
        cv2.waitKey(1)
        &
        0xFF
    )


    # Q = salir
    if tecla == ord("q"):

        break


# ============================================================
# CERRAR PROGRAMA
# ============================================================

# Detener motor antes de cerrar
enviar_comando(
    0
)

time.sleep(
    0.2
)

camara.release()

cv2.destroyAllWindows()

esp32.close()

print()
print("Sistema cerrado.")
print("Motor detenido.")
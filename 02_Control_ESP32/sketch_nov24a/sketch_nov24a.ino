// ============================================================
// BANDA TRANSPORTADORA
// ESP32 + MOTORREDUCTOR + ENCODER + SERVO + VISION ARTIFICIAL
// ============================================================


// ==========================
// SERVO
// ==========================

const int SERVO_PIN = 27;

const int PWM_SERVO_CH   = 1;
const int PWM_SERVO_FREQ = 50;
const int PWM_SERVO_RES  = 10;

const int SERVO_DUTY_UP   = 20;
const int SERVO_DUTY_DOWN = 63;

const unsigned long SERVO_PRE_DELAY_MS = 500;
const unsigned long SERVO_DOWN_TIME_MS = 300;
const unsigned long SERVO_HOLD_DOWN_MS = 5000;
const unsigned long SERVO_UP_TIME_MS   = 300;

const int SERVO_MOVE_STEPS = 40;


// ==========================
// MOTOR
// ==========================

const int ENA = 25;
const int IN1 = 33;
const int IN2 = 32;

const int PWM_MOTOR_CH   = 0;
const int PWM_MOTOR_FREQ = 3000;
const int PWM_MOTOR_RES  = 10;

// PWM mínimo para vencer fricción
const int MIN_PWM = 220;

// RPM máximas nominales
const int MAX_RPM = 170;


// ==========================
// ENCODER
// ==========================

const int ENCODER_A = 35;

volatile long pulsos = 0;

unsigned long tiempoAnterior = 0;

long pulsosPrevios = 0;

// Valor actual del proyecto
const int pulsosPorVuelta = 330;


// ==========================
// RPM
// ==========================

// Arranque inicial
int rpmDeseado = 90;

// RPM calculadas con encoder
float rpmReal = 0.0;


// ==========================
// ESTADOS DEL SERVO
// ==========================

enum TriggerState {
  IDLE,
  WAIT_PRE_DELAY,
  WAIT_HOLD_DOWN
};

TriggerState trig = IDLE;

unsigned long tMark = 0;


// ==========================
// PROTOTIPOS
// ==========================

void setRPM(int rpmValor);

void IRAM_ATTR contarPulsos();

void servoWriteDuty(int duty);

void servoMoveTo(
  int dutyTarget,
  unsigned long duration_ms
);

void activarClasificacion(
  String color
);

void procesarComando(
  String comando
);


// ============================================================
// SETUP
// ============================================================

void setup() {

  Serial.begin(115200);

  delay(500);


  // ==========================
  // MOTOR
  // ==========================

  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);

  ledcSetup(
    PWM_MOTOR_CH,
    PWM_MOTOR_FREQ,
    PWM_MOTOR_RES
  );

  ledcAttachPin(
    ENA,
    PWM_MOTOR_CH
  );

  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);


  // ==========================
  // SERVO
  // ==========================

  ledcSetup(
    PWM_SERVO_CH,
    PWM_SERVO_FREQ,
    PWM_SERVO_RES
  );

  ledcAttachPin(
    SERVO_PIN,
    PWM_SERVO_CH
  );

  servoMoveTo(
    SERVO_DUTY_UP,
    250
  );


  // ==========================
  // ENCODER
  // ==========================

  pinMode(
    ENCODER_A,
    INPUT
  );

  attachInterrupt(
    digitalPinToInterrupt(ENCODER_A),
    contarPulsos,
    RISING
  );


  // ==========================
  // ARRANCAR MOTOR
  // ==========================

  setRPM(
    rpmDeseado
  );


  Serial.println();
  Serial.println("============================");
  Serial.println(" BANDA TRANSPORTADORA");
  Serial.println("============================");
  Serial.println();

  Serial.println("COMANDOS MOTOR:");
  Serial.println("0      -> detener");
  Serial.println("1-170  -> cambiar velocidad");
  Serial.println("RPM    -> consultar RPM");

  Serial.println();

  Serial.println("COMANDOS VISION:");
  Serial.println("ROJO");
  Serial.println("AMARILLO");
  Serial.println("VERDE");

  Serial.println();

  Serial.println("Sistema iniciado.");
}


// ============================================================
// LOOP
// ============================================================

void loop() {

  unsigned long ahora = millis();


  // ==========================================================
  // RECIBIR COMANDOS DE PYTHON O MONITOR SERIAL
  // ==========================================================

  if (Serial.available()) {

    String comando =
      Serial.readStringUntil('\n');

    comando.trim();

    if (
      comando.length() > 0
    ) {

      procesarComando(
        comando
      );
    }
  }


  // ==========================================================
  // SECUENCIA SERVO
  // ==========================================================

  switch (trig) {

    case IDLE:

      break;


    case WAIT_PRE_DELAY:

      if (
        ahora - tMark
        >=
        SERVO_PRE_DELAY_MS
      ) {

        servoMoveTo(
          SERVO_DUTY_DOWN,
          SERVO_DOWN_TIME_MS
        );

        tMark = millis();

        trig =
          WAIT_HOLD_DOWN;

        Serial.println(
          "Servo abajo."
        );
      }

      break;


    case WAIT_HOLD_DOWN:

      if (
        ahora - tMark
        >=
        SERVO_HOLD_DOWN_MS
      ) {

        servoMoveTo(
          SERVO_DUTY_UP,
          SERVO_UP_TIME_MS
        );

        trig =
          IDLE;

        Serial.println(
          "Servo arriba."
        );
      }

      break;
  }


  // ==========================================================
  // RPM REAL
  // ==========================================================

  if (
    ahora - tiempoAnterior
    >=
    1000
  ) {

    long pulsosActuales =
      pulsos;

    long diferencia =
      pulsosActuales
      -
      pulsosPrevios;


    rpmReal =
      (
        diferencia
        /
        (float)pulsosPorVuelta
      )
      *
      60.0;


    Serial.print(
      "RPM deseadas: "
    );

    Serial.print(
      rpmDeseado
    );

    Serial.print(
      " | RPM reales: "
    );

    Serial.println(
      rpmReal,
      2
    );


    pulsosPrevios =
      pulsosActuales;

    tiempoAnterior =
      ahora;
  }


  delay(10);
}


// ============================================================
// PROCESAR COMANDOS
// ============================================================

void procesarComando(
  String comando
) {

  comando.trim();

  comando.toUpperCase();


  // ==========================================================
  // COLORES
  // ==========================================================

  if (
    comando == "ROJO" ||
    comando == "AMARILLO" ||
    comando == "VERDE"
  ) {

    activarClasificacion(
      comando
    );

    return;
  }


  // ==========================================================
  // CONSULTAR RPM
  // ==========================================================

  if (
    comando == "RPM"
  ) {

    Serial.println();

    Serial.print(
      "RPM deseadas: "
    );

    Serial.println(
      rpmDeseado
    );

    Serial.print(
      "RPM reales: "
    );

    Serial.println(
      rpmReal,
      2
    );

    Serial.println();

    return;
  }


  // ==========================================================
  // VERIFICAR SI ES UN NUMERO
  // ==========================================================

  bool esNumero = true;


  for (
    int i = 0;
    i < comando.length();
    i++
  ) {

    if (
      !isDigit(
        comando[i]
      )
    ) {

      esNumero =
        false;

      break;
    }
  }


  // ==========================================================
  // CAMBIAR RPM
  // ==========================================================

  if (
    esNumero &&
    comando.length() > 0
  ) {

    int nuevaRPM =
      comando.toInt();


    if (
      nuevaRPM >= 0 &&
      nuevaRPM <= MAX_RPM
    ) {

      rpmDeseado =
        nuevaRPM;

      setRPM(
        rpmDeseado
      );


      if (
        rpmDeseado == 0
      ) {

        Serial.println(
          "MOTOR DETENIDO"
        );
      }

      else {

        Serial.print(
          "Nueva referencia: "
        );

        Serial.print(
          rpmDeseado
        );

        Serial.println(
          " RPM"
        );
      }
    }

    else {

      Serial.println(
        "ERROR: use RPM entre 0 y 170."
      );
    }


    return;
  }


  // ==========================================================
  // COMANDO DESCONOCIDO
  // ==========================================================

  Serial.print(
    "Comando no reconocido: "
  );

  Serial.println(
    comando
  );
}


// ============================================================
// ACTIVAR CLASIFICACION
// ============================================================

void activarClasificacion(
  String color
) {

  Serial.print(
    "Color detectado: "
  );

  Serial.println(
    color
  );


  // ==========================================================
  // VERDE
  // ==========================================================
  // Verde sigue derecho.
  // NO mueve el servo.
  // ==========================================================

  if (
    color == "VERDE"
  ) {

    Serial.println(
      "VERDE -> paso directo."
    );

    return;
  }


  // ==========================================================
  // ROJO Y AMARILLO
  // ==========================================================
  // Ambos usan actualmente la misma salida física.
  // ==========================================================

  if (
    color == "ROJO" ||
    color == "AMARILLO"
  ) {

    if (
      trig == IDLE
    ) {

      tMark =
        millis();

      trig =
        WAIT_PRE_DELAY;

      Serial.println(
        "Esperando llegada de pieza..."
      );
    }

    else {

      Serial.println(
        "Servo ocupado."
      );
    }
  }
}


// ============================================================
// MOTOR
// ============================================================

void setRPM(
  int rpmValor
) {

  rpmValor =
    constrain(
      rpmValor,
      0,
      MAX_RPM
    );


  int pwm;


  // ==========================
  // MOTOR APAGADO
  // ==========================

  if (
    rpmValor == 0
  ) {

    pwm = 0;
  }


  // ==========================
  // MOTOR ENCENDIDO
  // ==========================

  else {

    pwm =
      map(
        rpmValor,
        1,
        MAX_RPM,
        MIN_PWM,
        1023
      );
  }


  ledcWrite(
    PWM_MOTOR_CH,
    pwm
  );


  Serial.print(
    "RPM deseadas: "
  );

  Serial.println(
    rpmValor
  );


  Serial.print(
    "PWM aplicado: "
  );

  Serial.println(
    pwm
  );
}


// ============================================================
// ENCODER
// ============================================================

void IRAM_ATTR contarPulsos() {

  pulsos++;
}


// ============================================================
// SERVO
// ============================================================

void servoWriteDuty(
  int duty
) {

  duty =
    constrain(
      duty,
      0,
      (1 << PWM_SERVO_RES) - 1
    );


  ledcWrite(
    PWM_SERVO_CH,
    duty
  );
}


// ============================================================
// MOVIMIENTO SUAVE
// ============================================================

void servoMoveTo(
  int dutyTarget,
  unsigned long duration_ms
) {

  static int lastDuty =
    SERVO_DUTY_UP;


  int start =
    lastDuty;


  int end =
    constrain(
      dutyTarget,
      0,
      (1 << PWM_SERVO_RES) - 1
    );


  int steps =
    max(
      1,
      SERVO_MOVE_STEPS
    );


  unsigned long stepDelay =
    duration_ms
    /
    steps;


  for (
    int i = 1;
    i <= steps;
    i++
  ) {

    int duty =
      start
      +
      (end - start)
      *
      i
      /
      steps;


    servoWriteDuty(
      duty
    );


    if (
      stepDelay > 0
    ) {

      delay(
        stepDelay
      );
    }
  }


  lastDuty =
    end;
}
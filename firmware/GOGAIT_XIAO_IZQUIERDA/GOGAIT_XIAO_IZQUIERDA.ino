#include <bluefruit.h>

// PLANTILLA IZQUIERDA (Xiao nRF52840) — mismo firmware que la derecha, pero
// con nombre BLE y UUIDs propios para que la app pueda distinguir de qué pie
// vienen los datos al conectarse a las dos placas a la vez.

const int PIN_SENSOR = A0;

// Ya no se usa para el envío BLE: la app calcula el % con la calibración
// del usuario (ver VistaPreparacion en la app), calibración que se hace por
// separado para cada plantilla. Se dejan solo como referencia para el print
// de debug por serie.
const int ADC_MIN = 1100;
const int ADC_MAX = 1800;

// UUIDs de la plantilla IZQUIERDA (distinto del de la derecha para que ambas
// placas puedan anunciarse y conectarse a la vez sin chocar).
#define BLE_UUID_SERVICE     "b9058af5-cb7a-4de0-8753-67184b634064"
#define BLE_UUID_CHARACT_TX  "7886f4fc-3ad6-4f8d-b0bf-62bea816a66f"

BLEService        goGaitService = BLEService(BLE_UUID_SERVICE);
BLECharacteristic txCharacteristic = BLECharacteristic(BLE_UUID_CHARACT_TX);

unsigned long previousMillis = 0;
const long interval = 10; // 100 Hz

unsigned long previousMillisDebug = 0;
const long debugInterval = 300;


void setup() {
  Serial.begin(115200);

  pinMode(PIN_SENSOR, INPUT);
  analogReadResolution(12);

  Bluefruit.begin();
  Bluefruit.setName("GOGAIT_XIAO_IZQUIERDA");

  goGaitService.begin();

  txCharacteristic.setProperties(CHR_PROPS_NOTIFY);
  txCharacteristic.setPermission(SECMODE_OPEN, SECMODE_OPEN);
  txCharacteristic.setMaxLen(20);
  txCharacteristic.begin();

  Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
  Bluefruit.Advertising.addTxPower();
  Bluefruit.Advertising.addService(goGaitService);
  Bluefruit.Advertising.addName();
  Bluefruit.Advertising.restartOnDisconnect(true);
  Bluefruit.Advertising.setInterval(32, 244); // ~20-152.5 ms
  Bluefruit.Advertising.start(0);

  Serial.println("GOGAIT_XIAO_IZQUIERDA activo, esperando conexion...");
}

void loop() {
  unsigned long currentMillis = millis();

  if (currentMillis - previousMillis >= interval) {
    previousMillis = currentMillis;

    int lecturaVoltaje = analogRead(PIN_SENSOR);

    // Se envía el ADC crudo, no el % calculado.
    if (Bluefruit.connected() && txCharacteristic.notifyEnabled()) {
      String tramaDatos = String(lecturaVoltaje);
      txCharacteristic.notify(tramaDatos.c_str());
    }

    if (currentMillis - previousMillisDebug >= debugInterval) {
      previousMillisDebug = currentMillis;

      // Solo para el monitor serie, con la calibración fija de referencia.
      int presion = map(lecturaVoltaje, ADC_MIN, ADC_MAX, 100, 0);
      presion = constrain(presion, 0, 100);

      Serial.print("[IZQUIERDA] ADC: ");
      Serial.print(lecturaVoltaje);
      Serial.print("  Presion (ref. debug): ");
      Serial.print(presion);
      Serial.println("%");
    }
  }
}

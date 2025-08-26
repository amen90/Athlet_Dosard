#include <WiFi.h>
#include <HTTPClient.h>
#include <Wire.h>
#include "MAX30100_PulseOximeter.h"
#include "mbedtls/aes.h"

#define SENSOR_UPDATE_PERIOD_MS   10     // appel pox.update() toutes les 10 ms
#define REPORTING_PERIOD_MS     30000     // envoi UART + Firebase toutes les 30 s

// Configuration Wi-Fi
const char* ssid     = "Airbox-0D54";
const char* password = "E32GGH7H";

// Configuration Firestore REST
const char* projectId  = "trackervest-4e4f4";
const char* apiKey     = "AIzaSyCwXZesct-l45z1ZqaLdA9XGDX4pnPzMbM";
const char* collection = "users";
const char* docId      = "aLNCySCiPmgxUdvK1KJ7Y9C9hv13";

// Optional ingestion endpoint (Cloud Function) that accepts POST { hr, spo2, temp, timestamp }
// If empty, the sketch falls back to calling Firestore REST per-field (not recommended).
const char* ingestionUrl = "";

// UART1 (ESP32) → RX1 du STM32 en GPIO16, TX1 vers STM32 en GPIO17
static const int RX1_PIN = 16;
static const int TX1_PIN = 17;

PulseOximeter pox;
uint32_t  tsLastSensorUpdate = 0;
uint32_t  tsLastReport       = 0;

float     lastTemp     = -1.0f;   // température reçue du STM32
String    tempBuffer   = "";
bool      hasTempLine  = false;

// --- AES-CTR framed UART reception from STM32 ---
// Frame: [0xAA 0x55][IV(16)][LEN(2, BE)][CIPHERTEXT(len)] ; plaintext is ASCII line(s)
static const uint8_t AES_KEY_128[16] = { 0x2b,0x7e,0x15,0x16,0x28,0xae,0xd2,0xa6,0xab,0xf7,0x15,0x88,0x09,0xcf,0x4f,0x3c };

enum UartRxState { WAIT_HDR1, WAIT_HDR2, READ_IV, READ_LEN, READ_PAYLOAD };
static UartRxState rxState = WAIT_HDR1;
static uint8_t rxIv[16];
static uint8_t rxLenBE[2];
static uint16_t rxLen = 0;
static uint8_t rxPayload[256];
static uint16_t rxCount = 0;

static String plainLineBuffer = "";
static uint16_t hrFromSTM = 0;
static uint16_t spo2FromSTM = 0;
static bool haveHrSpo2FromSTM = false;

static void aesCtrDecrypt(const uint8_t* key, const uint8_t* iv, const uint8_t* ct, uint8_t* pt, size_t len)
{
  mbedtls_aes_context ctx;
  mbedtls_aes_init(&ctx);
  mbedtls_aes_setkey_enc(&ctx, key, 128);
  unsigned char nonce_counter[16];
  unsigned char stream_block[16];
  size_t nc_off = 0;
  memcpy(nonce_counter, iv, 16);
  memset(stream_block, 0, sizeof(stream_block));
  mbedtls_aes_crypt_ctr(&ctx, len, &nc_off, nonce_counter, stream_block, ct, pt);
  mbedtls_aes_free(&ctx);
}

static void processPlaintextLine(const String& line)
{
  if (line.startsWith("LM35 Temp:")) {
    float t = 0.0f;
    if (sscanf(line.c_str(), "LM35 Temp: %f", &t) == 1) {
      lastTemp = t;
      Serial.printf("▶ STM32 Temp: %.1f °C\n", lastTemp);
    }
    return;
  }
  if (line.startsWith("MAX30100 Die Temp:")) {
    float t = 0.0f;
    if (sscanf(line.c_str(), "MAX30100 Die Temp: %f", &t) == 1) {
      Serial.printf("ℹ️ STM32 Sensor Die Temp: %.2f °C\n", t);
    }
    return;
  }
  if (line.startsWith("HR:")) {
    float hr = 0.0f, spo2 = 0.0f;
    if (sscanf(line.c_str(), "HR:%f", &hr) == 1) {
      const char* p = strstr(line.c_str(), "SpO2:");
      if (p) {
        sscanf(p, "SpO2:%f", &spo2);
      }
      hrFromSTM = (uint16_t)roundf(hr);
      spo2FromSTM = (uint16_t)roundf(spo2);
      haveHrSpo2FromSTM = true;
      Serial.printf("▶ STM32 HR/SPO2: %u / %u\n", hrFromSTM, spo2FromSTM);
    }
    return;
  }
  // Unknown line: just log
  Serial.printf("STM32: %s\n", line.c_str());
}

static void pumpUartFrames()
{
  while (Serial1.available() > 0) {
    int byteIn = Serial1.read();
    if (byteIn < 0) return;
    uint8_t b = (uint8_t)byteIn;
    switch (rxState) {
      case WAIT_HDR1:
        if (b == 0xAA) rxState = WAIT_HDR2;
        break;
      case WAIT_HDR2:
        if (b == 0x55) {
          rxState = READ_IV;
          rxCount = 0;
        } else {
          rxState = WAIT_HDR1;
        }
        break;
      case READ_IV:
        rxIv[rxCount++] = b;
        if (rxCount >= 16) {
          rxState = READ_LEN;
          rxCount = 0;
        }
        break;
      case READ_LEN:
        rxLenBE[rxCount++] = b;
        if (rxCount >= 2) {
          rxLen = ((uint16_t)rxLenBE[0] << 8) | rxLenBE[1];
          if (rxLen == 0 || rxLen > sizeof(rxPayload)) {
            // invalid length, reset
            rxState = WAIT_HDR1;
          } else {
            rxState = READ_PAYLOAD;
            rxCount = 0;
          }
        }
        break;
      case READ_PAYLOAD:
        rxPayload[rxCount++] = b;
        if (rxCount >= rxLen) {
          // decrypt
          uint8_t pt[256];
          aesCtrDecrypt(AES_KEY_128, rxIv, rxPayload, pt, rxLen);
          // append to line buffer and split on \n
          for (uint16_t i = 0; i < rxLen; i++) {
            char c = (char)pt[i];
            if (c == '\r') continue;
            if (c == '\n') {
              String line = plainLineBuffer;
              line.trim();
              if (line.length() > 0) processPlaintextLine(line);
              plainLineBuffer = "";
            } else {
              if (plainLineBuffer.length() < 256) plainLineBuffer += c;
            }
          }
          // ready for next frame
          rxState = WAIT_HDR1;
        }
        break;
    }
  }
}

void onBeatDetected()
{
  // Exemple de callback : on ne fait rien de spécial ici
  // Juste pour démontrer que la librairie peut nous avertir
  Serial.println("💓 Battement détecté !");
}

bool updateFieldInFirestore(const char* field, double value) {
  HTTPClient http;
  String url = String("https://firestore.googleapis.com/v1/projects/")
             + projectId
             + "/databases/(default)/documents/"
             + collection + "/" + docId
             + "?updateMask.fieldPaths=" + field
             + "&key=" + apiKey;

  String body = String("{\"fields\":{\"")
              + field
              + "\":{\"doubleValue\":"
              + String(value, 2)
              + "}}}";

  http.begin(url);
  http.addHeader("Content-Type", "application/json");
  int code = http.PATCH(body);

  if (code == HTTP_CODE_OK || code == HTTP_CODE_ACCEPTED) {
    Serial.printf("✔️ Updated %s → %.2f\n", field, value);
    http.end();
    return true;
  } else {
    Serial.printf("❌ HTTP %d: %s\n", code, http.errorToString(code).c_str());
    http.end();
    return false;
  }
}

bool sendTelemetryJSON(uint16_t hr, uint16_t spo2, float temp) {
  if (strlen(ingestionUrl) == 0) return false;

  HTTPClient http;
  http.begin(ingestionUrl);
  http.addHeader("Content-Type", "application/json");

  unsigned long ts = (unsigned long) (millis() / 1000UL);
  String body = String("{")
    + "\"hr\":" + String(hr) + ","
    + "\"spo2\":" + String(spo2) + ","
    + "\"temp\":" + String(temp,1) + ","
    + "\"timestamp\":" + String(ts)
    + "}";

  int code = http.POST(body);
  if (code == HTTP_CODE_OK || code == HTTP_CODE_ACCEPTED) {
    Serial.println("✔️ Telemetry sent to ingestion endpoint");
    http.end();
    return true;
  } else {
    Serial.printf("❌ Ingestion HTTP %d: %s\n", code, http.errorToString(code).c_str());
    http.end();
    return false;
  }
}

void setup() {
  Serial.begin(115200);
  delay(100);
  Serial.println("ESP32 : Démarrage...");

  // 1) Connexion Wi-Fi
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(300);
    Serial.print(".");
  }
  Serial.println("\n✅ Connected to WiFi!");

  // 2) Initialisation I2C
  Wire.begin(21, 22);

  // 3) Initialisation du capteur MAX30100
  if (!pox.begin()) {
    Serial.println("❌ Échec de l'initialisation du MAX30100 !");
    while (1) {
      delay(500);
      Serial.println("…vérifiez le câblage I2C/power");
    }
  }
  Serial.println("✅ MAX30100 initialisé.");
  pox.setIRLedCurrent(MAX30100_LED_CURR_24MA);
  pox.setOnBeatDetectedCallback(onBeatDetected);

  // 4) Initialisation UART1 (pour parler au STM32)
  Serial1.begin(115200, SERIAL_8N1, RX1_PIN, TX1_PIN);
  Serial.println("✅ UART1 initialisé (GPIO16=RX, GPIO17=TX).");

  // Initialisons les timestamps
  tsLastSensorUpdate = millis();
  tsLastReport       = millis();
}

void loop() {
  uint32_t now = millis();

  // === 1) Mise à jour du capteur (fréquence élevée) ===
  if (now - tsLastSensorUpdate >= SENSOR_UPDATE_PERIOD_MS) {
    tsLastSensorUpdate = now;
    pox.update();   // Appeler obligatoirement souvent (sinon HR/SPO2 restera à 0)
  }

  // === 2) Lecture de la ligne Temp reçue du STM32 (UART1) ===
  // Désormais, on traite des trames AES-CTR au lieu de texte brut
  pumpUartFrames();

  // === 3) Envoi toutes les 30 s (reporting) ===
  if (now - tsLastReport >= REPORTING_PERIOD_MS) {
    tsLastReport = now;

    // Préférence aux mesures reçues du STM32 si disponibles
    uint16_t hr   = haveHrSpo2FromSTM ? hrFromSTM : pox.getHeartRate();
    uint16_t spo2 = haveHrSpo2FromSTM ? spo2FromSTM : pox.getSpO2();

    // → 3a) On envoie HR/SPO2 au STM32 (UART1)
    char buf[32];
    snprintf(buf, sizeof(buf), "HR=%03u,SPO2=%03u\n", hr, spo2);
    Serial1.write(buf);
    Serial.print("ESP32 → STM32 : ");
    Serial.print(buf);

    // → 3b) On envoie la télémétrie au backend. Prefer ingestionUrl if configured.
    if (WiFi.status() == WL_CONNECTED) {
      bool ok = false;
      if (strlen(ingestionUrl) > 0) {
        ok = sendTelemetryJSON(hr, spo2, (lastTemp >= 0.0f) ? lastTemp : 0.0f);
      }
      if (!ok) {
        // fallback: update individual fields via Firestore REST (requires API key)
        updateFieldInFirestore("hr",   hr);
        updateFieldInFirestore("spo2", spo2);
        if (lastTemp >= 0.0f) {
          updateFieldInFirestore("temp", lastTemp);
        }
      }
    } else {
      Serial.println("⚠️ WiFi déconnecté : impossible de mettre à jour Firebase");
    }
  }

  // Ne jamais bloquer trop longtemps : sortir rapidement pour laisser "pox.update()" s'exécuter
}

#include "ESP32Encoder.h"     //Uso de encoders rotativos con ESP32 (mide RPM reales)
#include <AccelStepper.h>     //Controla motores paso a paso
#include <EEPROM.h>           //Guarda datos permanentes en la memoria EEPROM del ESP32
#include <TaskManagerIO.h>    //Ejecuta funciones en intervalos de tiempo
#include "Downloads_menu.h"   //Interfaz del usuario, códio Downloads_menu.h
#include <MultiStepper.h>     //Coordinación de múltiples motores paso a paso
#include <QuickPID.h>         //Control PID en tiempo real
#include <sTune.h>            //Autotuning parámetros PID, ajusta kp, ki y kd automáticamente
#include <WiFi.h>             //Conexión del ESP32 a una red wifi
#include <WiFiClient.h>       //Envía datos o activa actualización OTA
#include <WebServer.h>        //Crea servidor web en el ESP32. Se usa para alojar la página de actualización OTA donde subo el nuevo firmware
#include <ESPmDNS.h>          //Permite usar un nombre tipo http://esp32.local en vez de una IP
#include <Update.h>           //Permite manejar la actualización de firmware OTA
#include <Adafruit_ADS1X15.h> //Meneja el ADS1115 (convertidor analógico a digital ADC de 16 bits), usando I2C.
#include "BluetoothSerial.h"  //Habilita la comunicación bluetooth serial para enviar comandos o recibir datos desde el pc

#if !defined(CONFIG_BT_ENABLED) || !defined(CONFIG_BLUEDROID_ENABLED)
#error Bluetooth is not enabled! Please run `make menuconfig` to and enable it
#endif // Si el sistema bt del ESP32 no está activado, lanza un error

// Direcciones I2C, direcciones de los módulos ADS1115. Cada uno mide la corriente de 3 motores
#define I2C_ADDRESS1 0x48
#define I2C_ADDRESS2 0x49

// Control de plataforma (movimiento arriba y abajo) & Pines físicos del ESP32
#define stepper1_step 19 // Generan pulsos para girar los motores de paso
#define stepper2_step 13
#define stepper_dir 5  // Pin5, define si el motor va hacia arriba o abajo
#define stepper_ena 18 // Pin18, habilita o desactiva físicamente los motores

// Valores de configuración de movimientos de plataforma (distancias, aceleraciones, velocidades)
#define pos_up -3500            // El valor negativo mueve hacia arriba y se miden la cantidad de pasos, no mm
#define velocity 8000           // Velocidad máxima permitida del motor (pasos por segundo)
#define acceleration 800        // Aceleración para movimientos regulares, sin frenos de golpe
#define RPM_MAX 250             // RPM maxima
#define RPM_MIN 40              // RPM minima
#define stopAcceleration 200000 // Detener lo más rápido posible (inmediatamente)

// Posición absoluta (en pasos) y representa la posición a la que debe llegar la plataforma para estar completamente abajo (GAP mayor)
#define pos_down_abs -73200 // 45.75mm desde home, 1600 pasos/mm

const char *host = "ESP32_Visco"; // Se define el nombre del dispositivo en la red
String ssid = "biomat2_2.4G";     // Nombre de la red wifi a la que el ESP32 debe conectarse
String password = "biomat2022";   // Contraseña
WebServer server(80);             // Servidor web

// Crea una página de login en HTML y Javascript que se muestra cuando se accede al ESP32 por el navegador

/*
 * Login page
 */

const char *loginIndex =
    "<form name='loginForm'>"
    "<table width='20%' bgcolor='A09F9F' align='center'>"
    "<tr>"
    "<td colspan=2>"
    "<center><font size=4><b>ESP32 Login Page</b></font></center>"
    "<br>"
    "</td>"
    "<br>"
    "<br>"
    "</tr>"
    "<tr>"
    "<td>Username:</td>"
    "<td><input type='text' size=25 name='userid'><br></td>"
    "</tr>"
    "<br>"
    "<br>"
    "<tr>"
    "<td>Password:</td>"
    "<td><input type='Password' size=25 name='pwd'><br></td>"
    "<br>"
    "<br>"
    "</tr>"
    "<tr>"
    "<td><input type='submit' onclick='check(this.form)' value='Login'></td>"
    "</tr>"
    "</table>"
    "</form>"
    "<script>"
    "function check(form)"
    "{"
    "if(form.userid.value=='admin' && form.pwd.value=='admin')"
    "{"
    "window.open('/serverIndex')"
    "}"
    "else"
    "{"
    " alert('Error Password or Username')/*displays error message*/"
    "}"
    "}"
    "</script>";

// Página de interfaz que carga la OTA para actualizar el firmware del dispositivo
/*
 * Server Index Page
 */

const char *serverIndex =
    "<script src='https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js'></script>"
    "<form method='POST' action='#' enctype='multipart/form-data' id='upload_form'>"
    "<input type='file' name='update'>"
    "<input type='submit' value='Update'>"
    "</form>"
    "<div id='prg'>progress: 0%</div>"
    "<script>"
    "$('form').submit(function(e){"
    "e.preventDefault();"
    "var form = $('#upload_form')[0];"
    "var data = new FormData(form);"
    " $.ajax({"
    "url: '/update',"
    "type: 'POST',"
    "data: data,"
    "contentType: false,"
    "processData:false,"
    "xhr: function() {"
    "var xhr = new window.XMLHttpRequest();"
    "xhr.upload.addEventListener('progress', function(evt) {"
    "if (evt.lengthComputable) {"
    "var per = evt.loaded / evt.total;"
    "$('#prg').html('progress: ' + Math.round(per*100) + '%');"
    "}"
    "}, false);"
    "return xhr;"
    "},"
    "success:function(d, s) {"
    "console.log('success!')"
    "},"
    "error: function (a, b, c) {"
    "}"
    "});"
    "});"
    "</script>";

/*
 * setup function
 */

int pos_down = -80000;    // Posición a la que debe ir la plataforma cuando baja. Esta variable se puede ajustar dinámicamente en setup() con pos_down = pos_down_abs - (5.0 - value)*1600;
int interruptPinSup = 23; // Fin de carrera superior
int interruptPinInf = 39; // Fin de carrera inferior

bool isHoming = false;      // El sistema está buscando la posición 0
bool homed = false;         // El homing se hizo correctamente
bool stopMotorFlag = false; // Detiene el sistema ante errores

int imot = 0;

// int motor_pins[6] =   { 15,  2,  3,  4, 16, 17 };
// int encoder_pins[6] = { 12, 14, 27, 26, 25, 33 };

int motor_pins[6] = {15, 3, 4, 2, 17, 16};      // Pines físicos motores
int encoder_pins[6] = {12, 27, 26, 14, 33, 25}; // Pines físicos encoders (miden cuánto ha girado y qué tan rápido gira el eje del motor)

// Configuración control PWM y PID
const int freq = 500;                  // freq del PWM para controlar la velocidad de cada motor (500Hz), se puede aumentar?
const int resolution = 12;             // Resolución del PWM, cuántos niveles de potencia se pueden generar. La resolución de 12 bits permite controlar desde 0 a 4095
float Kp = 1.5, Ki = 24.0, Kd = 0.001; // Parámetros del controlador PID: kp (proporcional) cuánto corrige el error actual, ki (integral) cuánto corrige el error acumulado, kd (derivativo) cuánto responde a cambios en el error
unsigned long sineInitTime = 0;        // tiempo de referencia para calcular la onda sin con el paso del tiempo

// Control individual de cada motor
struct motor
{
  long enc = 0;        // valor actual del contador del encoder
  long enc_prev = 0;   // valor anterior del encoder, calcula la RPM a partir del cambio de posición
  float pwm = 0;       // PWM aplicada al motor. Se calcula por el PID y luego se aplica con ledcWrite
  float rpm = 0;       // Velocidad real del motor. Se calcula con el encoder en RPM()
  float target = 0;    // RPM objetivo que el motor debe alcanzar
  float current = 0;   // Valor de la corriente eléctrica consumida por el motor
  bool pulse = false;  // Indica si el motor debe trabajar oscilando o con RPM cte
  float amplitude = 0; // Amplitud de la onda de RPM (si pulse == true)
  float period = 0;    // Periodo de la onda (cuanto dura un ciclo de subida y bajada de la RPM) ****Este parámetro puedo trabajar***
  // Controlador PID individual para cada motor, se basa en los punteros rpm: entrada (valor actual), target: referencia (setpoint), pwm: salida (señal de control). El PID compara rpm con target y ajusta PWM para acercarse al objetivo
  QuickPID PID = QuickPID(&rpm, &pwm, &target);
  ESP32Encoder encoder;
  sTune tuner = sTune(&rpm, &pwm, tuner.ZN_PID, tuner.directIP, tuner.printALL); // Instancia para ajusta automáticamente el PID (Ziegler-Nichols ZN_PID)
};

motor motors[6] = {}; // Arreglo de 6 estructuras motor y se inicia

// QuickPID myPID(&motors[0].rpm, &motors[0].pwm, &motors[0].target);

// Configuración de los motores paso a paso (2) que controlan el movimiento vertical de la plataforma
AccelStepper stepper1(1, stepper1_step, stepper_dir); // 1, step, direction
AccelStepper stepper2(1, stepper2_step, stepper_dir); // 1, step, direction
MultiStepper steppers;                                // Permite mover múltiples motores a la vez
unsigned long rpmCalcTime = 0;                        // marca el tiempo de la última vez que se calculó la RPM
String OTAst = "OFF";                                 // Activa o desactiva el modo OTA

// Declaración de funciones
void RPM();          // Calcula la RPM real de cada motor
void PID();          // Ejecuta el controlador PID para cada motor
void currentMeter(); // Mide la corriente eléctrica consumida por cada motor
void log();          // Imprime por bt el estado actual del: corriente y RPM de cada motor
void sineWave();     // Si la opción pule está activada, modifica el target (RPM deseada) de cada motor en una onda senoidal: motors[i].target = valor_base+amplitud+sin(2*3.1415*tiempo/periodo)
void btRead();       // Leer comandos bt recibidos desde el pc

// Tareas periódicas usando la librería TaskManagerIO
uint8_t taskRPMMeter = taskManager.scheduleFixedRate(120, RPM);         // Ejecuta la función RPM() cada 700 ms (0.7 seg)
uint8_t taskPID = taskManager.scheduleFixedRate(60, PID);               // Ejecuta la función PID() cada 300 ms (0.3 seg)
uint8_t taskCurrent = taskManager.scheduleFixedRate(120, currentMeter); // Ejecuta la funcieon currentMeter() cada 1000 ms (1 seg)
uint8_t taskLog = taskManager.scheduleFixedRate(125, log);              // Ejecuta la función log() cada 300 ms (0.03 seg)
uint8_t taskSineWave = taskManager.scheduleFixedRate(30, sineWave);     // Ejecuta la función sineWave() cada 200 ms (0.2 seg)
uint8_t taskBT = taskManager.scheduleFixedRate(1000, btRead);           // Ejecuta la función btRead() cada 1000 ms (1 seg)

// Lectura de corriente de los motores mediante un ADC. ads1 mide la corriente de 3 motores y ads2 de los otros 3 motores
Adafruit_ADS1115 ads1; /* Use this for the 16-bit version */
Adafruit_ADS1115 ads2; /* Use this for the 16-bit version */

// ADS1115 adc1;
// ADS1115 adc2;

BluetoothSerial SerialBT; // Permite usar el bt clásico del ESP32 para enviar y recibir datos
String status = "off";    // Guarda el estado actual de la plataforma (posición?)
bool onoff = true;
String tune = "OFF"; // Guarda el estaod del autotuning PID
// variables
float Input, Output, Setpoint = 250, Kp1, Ki1, Kd1; // variables auxiliares para el autotuning PID: Input (RPM del motor), Output (PWM), Setpoint (RPM objetivo)

// user settings
uint32_t settleTimeSec = 2; // Tiempo estabilización inicial (en seg)
// Proceso de prueba activa, el autotuner genera PWM y observa la respuesta de las RPM
uint32_t testTimeSec = 5;      // runPid interval = testTimeSec / samples
const uint16_t samples = 10;   // Cantidad de muestras de datos para autotuning
const float inputSpan = 300;   // Rango máximo para el Input (RPM)
const float outputSpan = 4096; // Rango máximo de Output (PWM)
float outputStart = 500;       // Valor inicial de PWM antes de iniciar el test
float outputStep = 200;        // Amplitud de la oscilación del PWM durante el test
// float tempLimit = 150;
uint8_t debounce = 0; // Controla si el sistema está usando PWM continuo

// Función que se ejecuta una sola vez al iniciar el simulador de flujos, preparando el hardware y las variales de funcionamiento
void setup()
{
  // REG_WRITE(GPIO_FUNC0_OUT_SEL_CFG_REG, SIG_GPIO_OUT_IDX);
  EEPROM.begin(100);                                  // Inicia el acceso a la EEPROM simulada del ESP32 (tamaño 100 bytes). Guarda configuraciones usadas del menu (RPM, GAP, Posición)
  Wire.begin();                                       // Inicia la comunicación del ESP32 con los ADS1115
  Wire.setClock(400000);                              // Aumenta la velocidad del I2C a 400KHz para lecturas rápidas
  setupMenu();                                        // Inicia el menú interactivo del dispositivo
  menuMgr.load();                                     // Carga los valores previamente guardados del menú desde EEPROM
  int value = menuPosicion.getAsFloatingPointValue(); // Lee el valor actual de la posición desde el menú interactivo (GAP). Este valor será usado para ajustar pos_down
  pos_down = pos_down_abs - (5.0 - value) * 1600;     // Calcula la posición final hacia donde debe bajar la plataforma. Leído el valor desde el menú para ajustar dinámicamente la posición según el GAP seleccionado.

  pinMode(interruptPinSup, INPUT_PULLUP); // Pines de los interruptores de fin de carrera superior
  pinMode(interruptPinInf, INPUT_PULLUP); // Pines de los interruptores de fin de carrera inferior
  pinMode(stepper_ena, OUTPUT);           // Configura el pin que habilida o deshabilida los drivers de los motores paso a paso como salida.
  // attachInterrupt() asocia una función a cada sensor fin de carrera, cuando detecta un flanco de subida (RISING), ejecuta
  attachInterrupt(digitalPinToInterrupt(interruptPinSup), interruptStopMotorSup, RISING); // Frena al motor si sube de más
  attachInterrupt(digitalPinToInterrupt(interruptPinInf), interruptStopMotorInf, RISING); // Frena al motor si baja de más
  // ads1.begin();
  // ads2.begin(I2C_ADDRESS2);
  SerialBT.begin("BKrause_visco"); // Bluetooth device name. Inicia la conexión bt
  Serial.begin(460800);            // Comunicación por USB de alta velocidad

  // Configuración de los motores paso a paso
  stepper1.setEnablePin(stepper_ena); // Define al pin que habilita el driver de ambos motores
  stepper1.setPinsInverted(false, false, true);
  stepper1.setMaxSpeed(velocity);         // Define la velocidad máxima que se mueven los motores
  stepper1.setAcceleration(acceleration); // Define la aceleración máxima que se mueven los motores
  stepper1.disableOutputs();              // Desactiva los motores al inicio por seguridad

  stepper2.setEnablePin(stepper_ena); // Define al pin que habilita el driver de ambos motores
  stepper2.setPinsInverted(false, false, true);
  stepper2.setMaxSpeed(velocity);
  stepper2.setAcceleration(acceleration);
  stepper2.disableOutputs();

  // Sincronización de los motores
  steppers.addStepper(stepper1);
  steppers.addStepper(stepper2);
  // Posición inicial de ambos motores 0 = home
  stepper1.setCurrentPosition(0);
  stepper2.setCurrentPosition(0);
  // Inicia todos los motores rotatorios
  config_motors();

  // Inicialización de ADC para medire corriente, si falla lo muestra por serial
  if (!ads1.begin())
  {
    Serial.println("Failed to initialize ADS.");
  }
  if (!ads2.begin(I2C_ADDRESS2))
  {
    Serial.println("Failed to initialize ADS.");
  }
  ads1.setGain(GAIN_ONE);
  ads2.setGain(GAIN_ONE);

  // Programa una tarea para verificar cada 100 ms si los motores deben desactivarse cuando termina su movimiento
  uint8_t taskId1 = taskManager.scheduleFixedRate(100, disableMotors);
  // Desactiva otras tareas al inicio por seguridad, esto cambia cuando status == ON
  taskManager.setTaskEnabled(taskRPMMeter, false);
  taskManager.setTaskEnabled(taskPID, false);
  taskManager.setTaskEnabled(taskCurrent, false);
  taskManager.setTaskEnabled(taskLog, false);
  taskManager.setTaskEnabled(taskSineWave, false);

  // Oculta las opciones de subir/bajar en la interfaz de usuario, sólo se mostrarán luego de hacer homing, para evitar movimientos inseguros sin tener referencia inicial
  menuSubir.setVisible(false);
  menuBajar.setVisible(false);
}

// Función de ejecución continua
void loop()
{
  if (OTAst == "ON")
  { // Si el sistema está en modo OTA, activa el servidor web y pausa el resto
    server.handleClient();
  }
  else
  {
    taskManager.runLoop();
    if (stopMotorFlag)
      stopMotor();
    stepper1.run();
    stepper2.run();
  }

  if (tune == "ON" and OTAst != "ON")
  {                                                                                                              // Si el sistema está modo autotuning PID y no OTA, ejecuta las tareas del sistema (lectura RPM, PID, corriente)
    float optimumOutput = motors[0].tuner.softPwm(motor_pins[0], Input, Output, Setpoint, outputSpan, debounce); // Se genera una señal PWM para probar la respuesta del sistema

    switch (motors[0].tuner.Run())
    {
    case motors[0].tuner.sample: // active once per sample during test
      Input = motors[0].rpm;
      // tuner.plotter(Input, Output, Setpoint, 0.5f, 3);  // output scale 0.5, plot every 3rd sample
      break;

    case motors[0].tuner.tunings:                       // active just once when sTune is done
      motors[0].tuner.GetAutoTunings(&Kp1, &Ki1, &Kd1); // sketch variables updated by sTune
      motors[0].PID.SetOutputLimits(0, outputSpan);
      motors[0].PID.SetSampleTimeUs((outputSpan - 1) * 1000);
      debounce = 0; // ssr mode
      Output = outputStep;
      motors[0].PID.SetMode(motors[0].PID.Control::automatic); // the PID is turned on
      motors[0].PID.SetProportionalMode(motors[0].PID.pMode::pOnMeas);
      motors[0].PID.SetAntiWindupMode(motors[0].PID.iAwMode::iAwClamp);
      motors[0].PID.SetTunings(Kp1, Ki1, Kd1); // update PID with the new tunings
      char buffer[40];
      sprintf(buffer, "%.2f %.2f %.2f\n", Kp1, Ki1, Kd1); // Imprime los nuevos parámetros por bt
      bluetoothPrint(buffer);
      break;

    case motors[0].tuner.runPid: // active once per sample after tunings
      Input = motors[0].rpm;
      motors[0].PID.Compute();
      // motors[0].tuner.plotter(Input, optimumOutput, Setpoint, 0.5f, 3);
      break;
    }
    delay(200);
  }
}

// Extrae un valor específico y separa los comandos que se envían por bt
String getValue(String data, char separator, int index)
{
  int found = 0;
  int strIndex[] = {0, -1};
  int maxIndex = data.length() - 1;

  for (int i = 0; i <= maxIndex && found <= index; i++)
  {
    if (data.charAt(i) == separator || i == maxIndex)
    {
      found++;
      strIndex[0] = strIndex[1] + 1;
      strIndex[1] = (i == maxIndex) ? i + 1 : i;
    }
  }
  return found > index ? data.substring(strIndex[0], strIndex[1]) : "";
}

// Función que permite al usuario controlar el simulador de flujo vía bt. Permite enviar comandos para: cambiar la red wifi (OTA), activar OTA, ajustar los valores del PID (Kp, Ki, Kd) e iniciar el autotuning
void btRead()
{
  if (SerialBT.available())
  {
    String ts = SerialBT.readString();

    ts.trim();

    String command = getValue(ts, ' ', 0);
    String arg1 = getValue(ts, ' ', 1);
    arg1.trim();
    if (command == "ssid")
    {
      ssid = arg1;
      bluetoothPrint("ssid changed to: ");
      bluetoothPrint(arg1.c_str());
      bluetoothPrint("\n");
    }

    if (command == "password")
    {
      password = arg1;
      bluetoothPrint("password changed to: ");
      bluetoothPrint(arg1.c_str());
      bluetoothPrint("\n");
    }
    if (command == "OTA")
    {
      bluetoothPrint("Init OTA....\n");
      wifiSetup();
      OTAst = "ON";
      taskManager.setTaskEnabled(taskBT, false);
    }

    if (command == "kp")
    {
      bluetoothPrint("Changing kp: ");
      bluetoothPrint(arg1.c_str());
      bluetoothPrint("\n");
      Kp = arg1.toFloat();
      motors[0].PID.SetTunings(Kp, Ki, Kd);
    }
    if (command == "ki")
    {
      bluetoothPrint("Changing ki: ");
      bluetoothPrint(arg1.c_str());
      bluetoothPrint("\n");
      Ki = arg1.toFloat();
      motors[0].PID.SetTunings(Kp, Ki, Kd);
    }
    if (command == "kd")
    {
      bluetoothPrint("Changing kd: ");
      bluetoothPrint(arg1.c_str());
      bluetoothPrint("\n");
      Kd = arg1.toFloat();
      motors[0].PID.SetTunings(Kp, Ki, Kd);
    }

    if (command == "tune")
    {
      tune = arg1;
      bluetoothPrint("Start tuning process....\n");
      tune = "ON";
      ledcDetachPin(motor_pins[0]);
      pinMode(motor_pins[0], OUTPUT);
      taskManager.setTaskEnabled(taskRPMMeter, true);
      Output = 0;
      motors[0].tuner.Configure(inputSpan, outputSpan, outputStart, outputStep, testTimeSec, settleTimeSec, samples);
    }
  }
}

void wifiSetup()
{
  // Connect to WiFi network
  WiFi.begin(ssid, password);
  bluetoothPrint(ssid.c_str());
  bluetoothPrint(" ");
  bluetoothPrint(password.c_str());
  bluetoothPrint("\n");

  // Wait for connection
  while (WiFi.status() != WL_CONNECTED)
  {
    delay(500);
    bluetoothPrint(".");
  }
  bluetoothPrint("\n");
  bluetoothPrint("Connected to: ");
  bluetoothPrint(ssid.c_str());
  bluetoothPrint("\n");
  bluetoothPrint("IP address: ");
  bluetoothPrint(WiFi.localIP().toString().c_str());
  bluetoothPrint("\n");

  /*use mdns for host name resolution*/
  if (!MDNS.begin(host))
  { // http://esp32.local
    bluetoothPrint("Error setting up MDNS responder!\n");
    while (1)
    {
      delay(1000);
    }
  }
  bluetoothPrint("mDNS responder started\n");
  /*return index page which is stored in serverIndex */
  server.on("/", HTTP_GET, []()
            {
    server.sendHeader("Connection", "close");
    server.send(200, "text/html", loginIndex); });
  server.on("/serverIndex", HTTP_GET, []()
            {
    server.sendHeader("Connection", "close");
    server.send(200, "text/html", serverIndex); });
  /*handling uploading firmware file */
  server.on(
      "/update", HTTP_POST, []()
      {
      server.sendHeader("Connection", "close");
      server.send(200, "text/plain", (Update.hasError()) ? "FAIL" : "OK");
      ESP.restart(); },
      []()
      {
        HTTPUpload &upload = server.upload();
        if (upload.status == UPLOAD_FILE_START)
        {
          Serial.printf("Update: %s\n", upload.filename.c_str());
          if (!Update.begin(UPDATE_SIZE_UNKNOWN))
          { // start with max available size
            Update.printError(Serial);
          }
        }
        else if (upload.status == UPLOAD_FILE_WRITE)
        {
          /* flashing firmware to ESP*/
          if (Update.write(upload.buf, upload.currentSize) != upload.currentSize)
          {
            Update.printError(Serial);
          }
        }
        else if (upload.status == UPLOAD_FILE_END)
        {
          if (Update.end(true))
          { // true to set the size to the current progress
            Serial.printf("Update Success: %u\nRebooting...\n", upload.totalSize);
          }
          else
          {
            Update.printError(Serial);
          }
        }
      });
  server.begin();
}

// Configuración de todos los controladores PID de los motores
void configPID()
{
  for (int i = 0; i <= 5; i++)
  {                                                          // Bucle que recorre los 6 motores
    motors[i].PID.SetTunings(Kp, Ki, Kd);                    // Aplica los valores actuales de los parámetros PID
    motors[i].PID.SetOutputLimits(0, 4096);                  // Limita la salida del controlador PID (PWM) entre 0 y 4096
    motors[i].PID.SetMode(motors[i].PID.Control::automatic); // Modo automático del PID, recibe las RPM compara con target y ajusta las PWM
  }
}

// Inicia y configura los motores, cargando los valores definidos en el menú, asignando los pines de control PWM, conectando los encoders y dejando listos los parámetros de pulso (amplitud y periódo)
void config_motors()
{ // Arreglo para guardar las RPM objetivo (target) de los motores que se obtienen del menú, donde cada línea es una valor de RPM para cada motor desde la interfaz del equipo
  float value[6];
  value[0] = menuM1_RPM.getAsFloatingPointValue();
  value[1] = menuM2_RPM.getAsFloatingPointValue();
  value[2] = menuM3_RPM.getAsFloatingPointValue();
  value[3] = menuM4_RPM.getAsFloatingPointValue();
  value[4] = menuM5_RPM.getAsFloatingPointValue();
  value[5] = menuM6_RPM.getAsFloatingPointValue();
  // Lee si está activado el modo de pulso oscilante desde el menú
  bool b = menuPulse.getBoolean();
  float amp = menuAmplitude.getAsFloatingPointValue(); // Amplitud de la onda (cuánto varía la RPM hacia arriba y abajo)
  float period = menuPeriod.getAsFloatingPointValue(); // Periodo en cuanto se completa el ciclo de la onda (segundos)
  // float value = 100.0;
  // Se inicia un bucle para aplicar la configuración a cada motor
  for (int i = 0; i <= 5; i++)
  {
    // Serial.println(i);
    // Serial.println(motor_pins[i]);
    // Serial.println(encoder_pins[i]);
    // Configuración el canal PWM
    ledcSetup(i, freq, resolution); // freq 500Hz y resolution 12 bits
    // Conecta el pin de salida PWM correspondiente a ese motor i
    ledcAttachPin(motor_pins[i], i);
    ledcWrite(i, 0);
    motors[i].encoder.attachSingleEdge(encoder_pins[i]);
    motors[i].encoder.setCount(0); // Reinicia el contador a 0
    motors[i].target = value[i];   // Asigna la RPM al motor desde el menú
    motors[i].pulse = b;           // Asigna a cada motor si va a oscilar, amplitud y peiodo
    motors[i].amplitude = amp;
    motors[i].period = period;
  }
}

// Desactiva los motores paso a paso cuando temrinan su movimiento
void disableMotors()
{ // Verifica si ambos motores ya llegaron a su destino
  if (stepper1.distanceToGo() == 0 && stepper2.distanceToGo() == 0)
  { // Entrega cuantos pasos le quedan por recorrer, si ambos son 0, significa que ya no están en movimiento
    // Desactiva físicamente los motores
    stepper1.disableOutputs();
    stepper2.disableOutputs();

    if (isHoming)
    { // Revisa si el sistema estaba en proceso de home
      isHoming = false;
      stepper1.setCurrentPosition(0);
      stepper2.setCurrentPosition(0);
      menuSubir.setVisible(true);
      menuBajar.setVisible(true);
      menuHome.setVisible(false);
      stepper1.setCurrentPosition(0);
      stepper2.setCurrentPosition(0);
      homed = true;
      // renderer.redrawRequirement(MenuRedrawState::MENUDRAW_COMPLETE_REDRAW);
    }
  }
}

// Mueve la plataforma hacia abajo hasta activar el sensor superior, luego sube completamente para establecer el punto cero de referencia (home)
void CALLBACK_FUNCTION homing(int id)
{
  bool stat = digitalRead(interruptPinSup);
  Serial.println(stat);

  if (!homed)
  {                  // Lee el estado del sensor superior
    isHoming = true; // true=sensor libre, false=sensor presionado
    status = "bajando";
    if (stat)
    {
      move_motor(-5000);
    }

    while (stepper1.distanceToGo() != 0 && stepper2.distanceToGo() != 0)
    {
      stepper1.run();
      stepper2.run();
    }

    status = "subiendo";
    move_motor(150000);
  }
}

// Bajar la plataforma hasta la posición definida en pos_down, pero sólo si el sensor inferior no está activado
void CALLBACK_FUNCTION down(int id)
{
  bool stat = digitalRead(interruptPinInf);
  status = "bajando";
  if (!stat)
  {
    move_motor(pos_down);
  }
}

// Subir la plataforma a una posición definida, pero no necesariamente a home
void CALLBACK_FUNCTION up(int id)
{
  status = "subiendo";
  move_motor(pos_up);
}

// Asigna una RPM común para todos los motores y actualiza esa información tanto en el sistema como en el menú, además guardala en la EEPROM para que persista tras reiniciarla
void CALLBACK_FUNCTION setRPM(int id)
{                                                    // Se ejecuta cuando se selecciona la opción de aplicar a todos los motores
  float value = menuMotor.getAsFloatingPointValue(); // Lee el valor que el usuario ingresó
  for (int i = 0; i <= 5; i++)
  { // Asigna el mismo valor de RPM a cada motor y este valor será usado por el controlador PID para ajustar la velocidad real
    motors[i].target = value;
  }
  menuM1_RPM.setFromFloatingPointValue(value);
  menuM2_RPM.setFromFloatingPointValue(value);
  menuM3_RPM.setFromFloatingPointValue(value);
  menuM4_RPM.setFromFloatingPointValue(value);
  menuM5_RPM.setFromFloatingPointValue(value);
  menuM6_RPM.setFromFloatingPointValue(value);
  menuMgr.save(); // Guarda el nuevo estado de los ítems del menu en la memoria temporal
  EEPROM.commit();
}

// Detiene el movimiento de la plataforma, si se activan los sensores en un momento que no corresponde. Para el sensor superior e inferior
void interruptStopMotorSup()
{

  if (status != "bajando")
  {
    stopMotorFlag = true;
  }
}

void interruptStopMotorInf()
{
  if (status != "subiendo")
  {
    stopMotorFlag = true;
  }
}

// Detener ambos motores paso a paso de forma suave (disminuyendo la aceleración)
void stopMotor()
{
  stepper1.setAcceleration(stopAcceleration);
  stepper2.setAcceleration(stopAcceleration);
  stepper1.stop();
  stepper2.stop();
}

// Mueve la plataforma a una posición específica en pasos, activando ambos motores paso a paso con aceleración definidia y saliendo de cualquier estado de detención
void move_motor(long pos)
{
  stopMotorFlag = false;
  stepper1.enableOutputs();
  stepper2.enableOutputs();
  stepper1.setAcceleration(acceleration);
  stepper2.setAcceleration(acceleration);
  stepper1.moveTo(pos);
  stepper2.moveTo(pos);
}

// Calcula las RPM que está realizando cada motor, usando la diferencia de pasos del encoder en un intervalo de tiempo, y actualizando la información en la pantalla menú.
void RPM()
{
  unsigned long del = millis() - rpmCalcTime; // calcula el tiempo transcurrido desde la última vez que se ejecutó esta función, donde millis() da el tiempo actual en ms desde que inicio el ESP32 y rpmCalcTime es una variable global que se actualiza al final de esta función. del se usa para saber en cuánto tiempo ocurrieron los nuevos pasos medidos por los encoders
  for (int i = 0; i <= 5; i++)
  {
    motors[i].enc = abs(motors[i].encoder.getCount()); // Lee el número actual de pulsos del motor i-ésimo y getcount() entrega la cantidad de pasos que ha girado el eje desde el inicio, abs se usa para asegurar que el valor sea positivo
    long dif = motors[i].enc - motors[i].enc_prev;     // calcula cuántos pasos nuevos ha dado el motor desde la última medición
    motors[i].rpm = (((float(dif) / 11.0 / (float(del) / 1000.0)) * 60.0) / 21.3) * 1.0 + 0.0 * motors[i].rpm;
    // motors[i].rpm = (((dif / 11 / (float(del) / 1000.0)) * 60) / 21.3) * 1.0 + 0.0 * motors[i].rpm; //(dif/11) supone que cada vuelta del motor produce 11 pulsos en el encoder, esta división estima cuántas vueltas completas se dieron. /(del/1000.0) convierte el tiempo de ms a seg. *60 pasa de vueltas por seg a RPM. /21.3 es un factor de reduccieon o transmisión, probablemente porque el encoder no está directamente en el eje del motor y divide para ajustar la velocidad real del motor
    motors[i].enc_prev = motors[i].enc; // Guarda la lectura del encoder como la anterior para el sisguiente cálculo.
  }
  // Actualiza los valores en el menú para cada motor
  menuM1.setFromFloatingPointValue(motors[0].rpm);
  menuM2.setFromFloatingPointValue(motors[1].rpm);
  menuM3.setFromFloatingPointValue(motors[2].rpm);
  menuM4.setFromFloatingPointValue(motors[3].rpm);
  menuM5.setFromFloatingPointValue(motors[4].rpm);
  menuM6.setFromFloatingPointValue(motors[5].rpm);

  rpmCalcTime = millis(); // Actualiza el tiempo de referencia para la próxima predicción
}

// Aplica el control PID a cada motor, calcula el PWM que necesita cada motor para alcanzar su RPM objetivo (target)
void PID()
{
  for (int i = 0; i <= 5; i++)
  {
    motors[i].PID.Compute();
    ledcWrite(i, motors[i].pwm);
  }
}

// Enciende o apaga todo el sistema de control cuando se cambia el estado del switch principal en el menú.
void CALLBACK_FUNCTION statusOnChange(int id)
{
  bool b = menuStatus.getBoolean();
  float value = menuMotor.getAsFloatingPointValue();
  if (b)
  {
    resetMotorData(); // Reinicia todos los contadores de los encoders, el PWM y la corriente de los motores
    taskManager.setTaskEnabled(taskRPMMeter, true);
    taskManager.setTaskEnabled(taskPID, true);
    taskManager.setTaskEnabled(taskCurrent, true);

    taskManager.setTaskEnabled(taskLog, true);
    // taskManager.setTaskEnabled(taskId2, true);
    menuMover.setVisible(false); // Oculta el menú manual de mover la plataforma

    configPID();                     // configura los valores PID actuales para todos los motores
    rpmCalcTime = millis();          // reinicia el tiempo apra calcular la próxima medición de RPM
    bool b = menuPulse.getBoolean(); // Se verifica si el modo pulsatorio está activado
    if (b)
    {
      taskManager.setTaskEnabled(taskSineWave, true);
      sineInitTime = millis();
    }
    else
    {
      taskManager.setTaskEnabled(taskSineWave, false);
    }
  }
  else
  {
    // Desactiva todas las tareas activas del sistema
    taskManager.setTaskEnabled(taskRPMMeter, false);
    taskManager.setTaskEnabled(taskPID, false);
    taskManager.setTaskEnabled(taskCurrent, false);
    taskManager.setTaskEnabled(taskLog, false);
    menuMover.setVisible(true);
    // Apaga el PWM de todos los motores y reinicia los controles PID
    for (int i = 0; i <= 5; i++)
    {
      ledcWrite(i, 0);
      motors[i].PID.Reset();
    }
    menuM1.setFromFloatingPointValue(0.0);
    menuM2.setFromFloatingPointValue(0.0);
    menuM3.setFromFloatingPointValue(0.0);
    menuM4.setFromFloatingPointValue(0.0);
    menuM5.setFromFloatingPointValue(0.0);
    menuM6.setFromFloatingPointValue(0.0);
  }
  // Serial.println(b);
}

// Leer el valor de corriente de cada motor desde los sensores ADS
void currentMeter()
{
  motors[0].current = ads1.readADC_SingleEnded(2); // * 0.1875F;
  delay(5);
  motors[1].current = ads1.readADC_SingleEnded(1);
  delay(5);
  motors[2].current = ads1.readADC_SingleEnded(0);
  delay(5);
  motors[3].current = ads2.readADC_SingleEnded(2);
  delay(5);
  motors[4].current = ads2.readADC_SingleEnded(1);
  delay(5);
  motors[5].current = ads2.readADC_SingleEnded(0);
  for (int i = 0; i <= 5; i++)
  {
    motors[i].current *= 0.1875F * 0.3030303; // cada bit equivale a 0.1875 mV
  }
}

// Contruye cadenas de texto con las mediciones de corriente y RPM para cada motor y se envían por bt al usuario
void log()
{
  // char buffer[85];
  // sprintf(buffer, "Ma_c=%.2f, Mb_c=%.2f, Mc_c=%.2f, Md_c=%.2f, Me_c=%.2f, Mf_c=%.2f,\n", motors[0].current, motors[1].current, motors[2].current, motors[3].current, motors[4].current, motors[5].current);
  // bluetoothPrint(buffer);

  char bufferR[85];
  sprintf(bufferR, "Ma_r=%.2f, Mb_r=%.2f, Mc_r=%.2f, Md_r=%.2f, Me_r=%.2f, Mf_r=%.2f,\n", motors[0].rpm, motors[1].rpm, motors[2].rpm, motors[3].rpm, motors[4].rpm, motors[5].rpm);
  bluetoothPrint(bufferR);

  // char buffer2[85];
  // sprintf(buffer2, "Ma_c=%.2f, Mb_c=%.2f, Mc_c=%.2f, Md_c=%.2f, Me_c=%.2f, Mf_c=%.2f,\n", motors[0].current, motors[1].current, motors[2].current, motors[3].current, motors[4].current, motors[5].current);
  // bluetoothPrint(buffer2);

  char bufferT[85];
  sprintf(bufferT, "Ma_t=%.2f, Mb_t=%.2f, Mc_t=%.2f, Md_t=%.2f, Me_t=%.2f, Mf_t=%.2f #\n", motors[0].target, motors[1].target, motors[2].target, motors[3].target, motors[4].target, motors[5].target);
  bluetoothPrint(bufferT);
}

// Reestablece todas las variables internas asociadas a cada motor (i.e. contador encoder, PWM, corriente) para que el control comience desde cero y sin datos previos
void resetMotorData()
{
  for (int i = 0; i <= 5; i++)
  {
    motors[i].enc = 0;
    motors[i].enc_prev = 0;
    motors[i].pwm = 0;
    motors[i].current = 0;
    motors[i].encoder.setCount(0);
  }
}

// Envía texto vía bt carácter por carácter
void bluetoothPrint(const char *line)
{
  uint8_t *p = (uint8_t *)line;
  while (*p)
    SerialBT.write(*p++);
}

// Actualiza el parámetro pos_down según el valor definido en el menú
void CALLBACK_FUNCTION poschanged(int id)
{
  int value = menuPosicion.getAsFloatingPointValue();
  pos_down = pos_down_abs - (5.0 - value) * 1600;
  menuMgr.save();
  EEPROM.commit();
  Serial.println(value);
  // TODO - your menu change code
}

// Se definen callbacks individuales que se ejecutan cuando el usuario cambio la RPM de un motor específico en el menú del sistema y están diseñados para actualizar la velocidad objetivo (target RPM) de cada motor
void CALLBACK_FUNCTION M1Changed(int id)
{
  float value = menuM1_RPM.getAsFloatingPointValue();
  motors[0].target = value;
  menuMgr.save();
  EEPROM.commit();
}

void CALLBACK_FUNCTION M2Changed(int id)
{
  float value = menuM2_RPM.getAsFloatingPointValue();
  motors[1].target = value;
  menuMgr.save();
  EEPROM.commit();
}

void CALLBACK_FUNCTION M3Changed(int id)
{
  float value = menuM3_RPM.getAsFloatingPointValue();
  motors[2].target = value;
  menuMgr.save();
  EEPROM.commit();
}

void CALLBACK_FUNCTION M4Changed(int id)
{
  float value = menuM4_RPM.getAsFloatingPointValue();
  motors[3].target = value;
  menuMgr.save();
  EEPROM.commit();
}

void CALLBACK_FUNCTION M5Changed(int id)
{
  float value = menuM5_RPM.getAsFloatingPointValue();
  motors[4].target = value;
  menuMgr.save();
  EEPROM.commit();
}

void CALLBACK_FUNCTION M6Changed(int id)
{
  float value = menuM6_RPM.getAsFloatingPointValue();
  motors[5].target = value;
  menuMgr.save();
  EEPROM.commit();
}

// Modifica la RPM target de cada motor en el tiempo usando una función seno con una amplitud y periodo definidos por el usuario.
void sineWave()
{
  unsigned long del = millis() - sineInitTime; // Calcjula cuánto tiempo "del" ha transcurrido desde que comenzó el modo senoidal
  float value[6];
  value[0] = menuM1_RPM.getAsFloatingPointValue();
  value[1] = menuM2_RPM.getAsFloatingPointValue();
  value[2] = menuM3_RPM.getAsFloatingPointValue();
  value[3] = menuM4_RPM.getAsFloatingPointValue();
  value[4] = menuM5_RPM.getAsFloatingPointValue();
  value[5] = menuM6_RPM.getAsFloatingPointValue();
  const float LPM = 30.0; // 100.0; //Latidos por minuto
  // const float period = 60.0/LPM; //Perido: 1 seg
  const float N_cycles_in_doppler = 7.0;
  const float N = 156.0; // number of pixels in the Doppler
  const float N_aux = 46.0;    // number of pixels for a pair of cycles (2 cycles = 46 pixels)
  // float w = 2 * M_PI/period; //Frecuencia angular
  const float time_doppler = (N_cycles_in_doppler / LPM) * 60.0;
  const float time_of_two_cycles = (1 / (N / N_aux)) * time_doppler;
  const float w = 2 * M_PI / time_of_two_cycles; // fundamental FFT frequency
  float t_sec = (float)del / 1000.0;

  for (int i = 0; i <= 5; i++)
  {
    if (motors[i].pulse)
    {
      // const float LPM = 20.0;//100.0; //Latidos por minuto
      // const float period = 60.0/LPM; //Perido: 1 seg
      // float w = 2 * M_PI/period; //Frecuencia angular
      // float t_sec = (float)del/1000.0;
      float FFT_mean = 6.66087 + 0.1997 * cos(1 * w * t_sec) + 0.03202 * sin(1 * w * t_sec) - 1.925 * cos(2 * w * t_sec) + 4.911 * sin(2 * w * t_sec) + 0.04863 * cos(3 * w * t_sec) + 0.0898 * sin(3 * w * t_sec) - 1.42 * cos(4 * w * t_sec) - 0.4395 * sin(4 * w * t_sec) - 0.06233 * cos(5 * w * t_sec) + 0.146 * sin(5 * w * t_sec) - 0.04577 * cos(6 * w * t_sec) - 0.2415 * sin(6 * w * t_sec); // Actulización 2025/09/12

      motors[i].target = value[i] + motors[i].amplitude * (FFT_mean);

      // float sinfx = sin(2 * 3.1415 / motors[i].period * del / 1000.0);//Esta es la función seno que genera la oscilación, donde 2*3.1415 define la frecuencia angular, del/1000.0 convierte el tiempo de ms a seg, el periodo queda definido por motors[i].period (en seg) Original
      // motors[i].target = value[i] + motors[i].amplitude * sinfx;//Actualiza el valor target RPM del motor
      // cambio que afecta únicamente en cómo varía el valor de motors[i].target con el tiempo cuando el modo pulsátil (pulse==True) está activado. Este nuevo valor es usado en la función PID() para calcular la señal de control (PWM)
      // float FFT = -(18.2593 + 5.3397 * cos(w * t_sec) -2.9672 * sin(w * t_sec) -0.2013 * cos(2 * w * t_sec) + 2.6988 * sin(2 * w * t_sec) - 1.0163 * cos(3 * w * t_sec) + 0.0791 * sin(3 * w * t_sec) -0.1370 * cos(4 * w * t_sec) - 0.5116 * sin(4 * w * t_sec));
      // motors[i].target = value[i]+motors[i].amplitude*(FFT+15);
    }
    else
    {
      motors[i].target = value[i]; // Si el modo pulsatil está desactivado, simplemente asiga el valor que el usuario ingresó
    }
  }
}
// Activa o desactiva la modulación sinusoidal de RPM en cada motor, dependiendo de la opción seleccionada en el menú
void CALLBACK_FUNCTION pulseChanged(int id)
{
  bool b = menuPulse.getBoolean();
  if (b)
  {
    taskManager.setTaskEnabled(taskSineWave, true);
    sineInitTime = millis();
  }
  else
  {
    taskManager.setTaskEnabled(taskSineWave, false);
    float value[6];
    value[0] = menuM1_RPM.getAsFloatingPointValue();
    value[1] = menuM2_RPM.getAsFloatingPointValue();
    value[2] = menuM3_RPM.getAsFloatingPointValue();
    value[3] = menuM4_RPM.getAsFloatingPointValue();
    value[4] = menuM5_RPM.getAsFloatingPointValue();
    value[5] = menuM6_RPM.getAsFloatingPointValue();
    for (int i = 0; i <= 5; i++)
    {
      motors[i].target = value[i];
    }
  }
  for (int i = 0; i <= 5; i++)
  {
    motors[i].pulse = b;
  }
  menuMgr.save();
  EEPROM.commit();
}

// Permite al usuario modificar la amplitud de la onda senoidal aplicada a cada motor. Esto afecta qué tan lejos se aleja la RPM real de su valor medio
void CALLBACK_FUNCTION amplitudeChanged(int id)
{
  float value = menuAmplitude.getAsFloatingPointValue();
  for (int i = 0; i <= 5; i++)
  {
    motors[i].amplitude = value;
  }
  menuMgr.save();
  EEPROM.commit();
}

// Permite al usuario modificar el periodo de la onda senoidal aplicada a cada motor
void CALLBACK_FUNCTION periodChanged(int id)
{
  float value = menuPeriod.getAsFloatingPointValue();
  for (int i = 0; i <= 5; i++)
  {
    motors[i].period = value;
  }
  menuMgr.save();
  EEPROM.commit();
}

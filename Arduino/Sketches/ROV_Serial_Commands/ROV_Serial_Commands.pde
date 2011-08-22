// ROV Serial Commands Receiver and Control
// C.Tilt
// Aug-2011
// Board: Arduino Duemilanove
//
// This sketch implements the Remotely Operated Vehicle, we named "Spears".
// It receives ASCII commands over the USB Serial device and interprets those
// commands to control Electronic Speed Controllers and LEDs. It expects a
// Ping message every second and if that Ping is not received, the ROV's
// speed controllers will be set to the off position. Each Ping command is
// echo'd back to the host over the serial port.
//
// Commands Received by ROV:
// Mn d#xx    Set Motor n to value of hex XX (256 values) in direction d (F | R)
// Mn d%pp    Set Motor n to pp % power in direction d (F | R)
// Ln s%pp    Set LED number n to pp % brightness at s seconds (0-9) delay between ON periods
// P          Ping. ROV will echo P back
//
// Commands Sent by ROV to host:
// P          Pong
// Tn t       Temperature sensor n reports Ferenheight Temperature t (decimal string)

#include <Servo.h>

#define LED0  10 // PWM uses analogWrite. Engineering. Keep dim.
#define LED1  9  // PWM uses analogWrite. Control Tower and Rescue light.

typedef struct led_state
{
  int led;        // The led number
  int brightness; // number from 0..255 will set pulse width
  int onSecs;     // Duty cycle ON time
  int offSecs;    // Duty cycle OFF time
  int lastTimeSet; // The last time (in millis) we changed our value
  int state;       // current state is ON(1) or OFF(0)
} led_state_t;

int incomingByte = 0;
int lastTimeDataSent = 0;

#define LED_STATE_ENGINEERING  0
#define LED_STATE_TOWER        1

led_state_t led_states [] =
{
  { LED0, 0x88, 1000, 0, 0, 1 },  // Engineering. Normally on dim. Blink in Emergency.
  { LED1, 0x50, 5000, 1000, 0, 1 }   // Control Tower. Most on. Blink rarely unless Emergency.
};

#define servo1Pin 2
#define servo2Pin 3
#define servo3Pin 4

//#define servo4Pin 4
//#define servo5Pin 5
//#define servo6Pin 6

// Servo controls for the ESC, in microseconds
// TODO: read their manual and find the actual values
#define FULL_REVERSE  800
#define FULL_FORWARD  2400
#define NEUTRAL       ((FULL_FORWARD + FULL_REVERSE) / 2)

int minPulse = FULL_REVERSE;
int maxPulse = FULL_FORWARD;

typedef struct servo_state
{
  int pin;
  int usecs;
  Servo *servo;
} servo_state_t;

Servo servo1;
Servo servo2;
Servo servo3;

servo_state servo_states [] =
{
  { servo1Pin, NEUTRAL, &servo1 },
  { servo2Pin, NEUTRAL, &servo2 },
  { servo3Pin, NEUTRAL, &servo3 }
};

// Give a short two-cycle blink to show this LED is ready.
// Requires prior OUTPUT pin mode setup, e.g. run initLEDs() first.
void blinkReady(int led)
{
  for( int i=0; i<2; i++ )
  {
    analogWrite(led, 0x255);
    delay(500);
    analogWrite(led, 0x00);
    delay(500);
  }
}

// Initialize the LEDs for later use in the cycler
void initLEDs()
{
  int numLEDs = sizeof(led_states) / sizeof(led_state_t);
  for( int i=0; i<numLEDs; i++ )
  {
    led_state_t* led_state = &led_states[i]; 
    pinMode( led_state->led, OUTPUT ); // Tell Arduino this pin is an output
    blinkReady( led_state->led );
  }
  
  // Set the initial value and last modified time of each LED
  for( int i=0; i<numLEDs; i++ )
  {
    led_state_t* led_state = &led_states[i];
    analogWrite( led_state->led, led_state->brightness );
    led_state->lastTimeSet = millis();
  }

}

void cycleLEDs()
{
  const int numLEDs = sizeof(led_states) / sizeof(led_state_t);
  int currentTime = millis();
  for( int i=0; i<numLEDs; i++ )
  {
    led_state_t* led_state = &led_states[i];
    int secsSinceLastChange = (currentTime - led_state->lastTimeSet);
    if( led_state->state == 1
        && led_state->offSecs != 0
        && secsSinceLastChange >= led_state->onSecs )
    {
      // Time to switch the LED state to off
      digitalWrite( led_state->led, LOW );
      led_state->lastTimeSet = currentTime;
      led_state->state = 0;
    }
    else if( led_state->state == 0
             && secsSinceLastChange >= led_state->offSecs )
    {
      // Time to switch the LED to ON
      analogWrite( led_state->led, led_state->brightness );
      led_state->lastTimeSet = currentTime;
      led_state->state = 1;
    }
  }
}

#pragma mark Hand coded Servo Control

void initServos()
{
  int numServos = sizeof(servo_states) / sizeof(servo_state_t);
  for( int i=0; i<numServos; i++ )
  {
    servo_state *s = &servo_states[i];
    s->servo->attach(s->pin, minPulse, maxPulse);
    s->servo->writeMicroseconds(NEUTRAL);
  }
}

int range( int value, int minRange, int maxRange )
{
  float ratio = (float)value / (float)255;
  return minRange + (int)(ratio * (float)(maxRange - minRange));
} 

void setServo(int servoNum, int direction, int value)
{
  int newUsecs;
  if( direction )
  {
    newUsecs = range( value, NEUTRAL, FULL_FORWARD);
  }
  else
  {
    newUsecs = range( value, NEUTRAL, FULL_REVERSE);
  }
  servo_state *s = &servo_states[servoNum];
  Serial.print("Setting servo "); Serial.print(servoNum, DEC); Serial.print(" to ");
  Serial.println(newUsecs, DEC);
  s->servo->writeMicroseconds(newUsecs);
}


void setup()
{
  // Initialize the LED cycler and do a blinky system check
  initLEDs();
  
  // Initialize Servo pins and set their level to OFF
  initServos();
  
  // Initialize the serial port and send the host a message that we're up and runnin.
  Serial.begin(38400);  
  Serial.println("ROV --> Host, Awaiting Commands");

}

// Converts one HEX character into a numeric value
int hex2dec(byte c)
{
  if( c >= '0' && c <= '9' )
    return c - '0';
  else if( c >= 'A' && c <= 'F' )
    return c - 'A' + 10;
  else if( c >= 'a' && c <= 'f' )
    return c - 'a' + 10;
  else
    return 0;
}

// Wait for a character from the serial port and return it.
int getc()
{
  while( Serial.available() == 0 )
  ;
  return Serial.read();
}

// Read characters from serial port and discard until CR is read and skipped.
void eatCharsToEOL()
{
  int c;
  while( c = getc() != '\r' )
  ;
}

// Mn d#xx    Set Motor n to value of hex XX (256 values) in direction d (F | R)
// Mn d%pp    Set Motor n to pp % power in direction d (F | R)
void processMotorCommand()
{
  int dir;
  int hhigh = 0;
  int hlow = 0;
  int control = 0x00; // default in case of failure
  boolean forward = true;
  // read LED number
  int motor = hex2dec(getc());
  // read space
  if( getc() != ' ' )
  {
    Serial.println("Motor command was expecting a space");
    goto error;
  }
  // read motor direction
  dir = getc();
  if( dir == 'f' || dir == 'F' )
    forward = true;
  else if( dir == 'r' || dir == 'R' )
    forward = false;
  // skip #
  if( getc() != '#' )
  {
    Serial.println("Motor command was expecting #xx");
    goto error;
  }
  // read motor value
  hhigh = getc();
  hlow = getc();
  control = hex2dec(hlow) + hex2dec(hhigh)*16;
  // Set motor value
  Serial.print("ROV: setting Motor["); Serial.print(motor, DEC);
  Serial.print("] control to "); Serial.print(control, HEX);
  if( forward )
    Serial.println(" forward ");
  else
    Serial.println(" reverse ");
  setServo(motor, forward, control);
    
  error:
    eatCharsToEOL();
}

// Ln h,l#xx    Set LED number n to brightness xx and delays h (High) and l (low)
void processLEDCommand()
{
  int onSecs = 0;
  int offSecs = 0;
  int hhigh = 0;
  int hlow = 0;
  int brightness = 0xff; // default in case of failure
  const int numLEDs = sizeof(led_states) / sizeof(led_state_t);
  
  // read LED number
  int led = hex2dec(getc());
  // read space
  if( getc() != ' ' )
  {
    Serial.println("LED command was expecting a space");
    goto error;
  }
  // read high cycle time
  onSecs = hex2dec(getc());
  // skip comma
  if( getc() != ',' )
  {
    Serial.println("LED command was expecting a comma");
    goto error;
  }
  // read low cycle time
  offSecs = hex2dec(getc());
  // skip #
  if( getc() != '#' )
  {
    Serial.println("LED command was expecting #xx");
    goto error;
  }
  // Read brightness. Read two hex digits and make number from 0..255
  hhigh = getc();
  hlow = getc();
  brightness = hex2dec(hlow) + hex2dec(hhigh)*16;
  // Set led's value
  if( led < numLEDs )
  {
    Serial.print("ROV: setting LED["); Serial.print(led, DEC);
    Serial.print("] brightness to "); Serial.print(brightness, HEX);
    Serial.print(" on="); Serial.print(onSecs, DEC);
    Serial.print(" off="); Serial.println(offSecs, DEC);
 
    led_state_t* led_state = &led_states[led];
    led_state->brightness = brightness;
    led_state->onSecs = onSecs * 1000;
    led_state->offSecs = offSecs * 1000;
  }
  else
  {
    Serial.print("ROV: LED command specified LED[");
    Serial.print(led, DEC);
    Serial.println("] out of bounds");
    goto error;
  }
  // Universal error label just throws away the reset of command.
  // This is OK for a good command too because we still need to read the CR.
  error:
  eatCharsToEOL();
}

void conditionRed()
{
  Serial.println("ROV: >>>> Condition RED <<<<");
  
  // Stop all engines
  Serial.println("Stopping all motors...");
  
  // Activate Emergency Beacons
  Serial.println("Emergency beacons activated.");
  led_state *led = &led_states[LED_STATE_TOWER];
  led->onSecs = 100;
  led->offSecs = 1000;
  led->brightness = 0xff;
 
  eatCharsToEOL();
}

void processUnknownCommand(int c)
{
  Serial.print("Unknown command: ");
  Serial.println(c, DEC);
  eatCharsToEOL();
}
  
void processCommandIfAvailable()
{  
  if (Serial.available() > 0)
  {
    int c = getc();
    switch(c)
    {
      case 'P': Serial.println("Pong"); eatCharsToEOL(); break;
      case 'L': processLEDCommand(); break;
      case 'M': processMotorCommand(); break;
      case 'E': conditionRed(); break;
      case 'R': conditionRed(); break;
      default: processUnknownCommand(c); break;
    }
  }
}

void sendSensorData()
{
  Serial.println("T0 42");
}

void systemCheck()
{
  // Send sensor data back to host every second.
  int currentTime = millis();
  if( currentTime - lastTimeDataSent >= 1000 )
  {
    sendSensorData();
    lastTimeDataSent = currentTime;
  }
}

void loop()
{
  static boolean firstTime = true;

  // If there is a command waiting to be read from the HOST, do it now.
  processCommandIfAvailable();

  // Some of the LEDs may be blinking and have different brightnesses.
  cycleLEDs();
  
  // Send sensor data if it's time. Possibly take emergency actions locally
  // if we lost touch with the host.
  // systemCheck();

}

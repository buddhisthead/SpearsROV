/*
 * ESC_Programmer sketch for the Arduino
 * C.Tilt 20-Aug-2011
 * This sketch allows me to program an Electronic Speed Controller that will be controlled
 * by the Arduino (as the servo input to the ESC). It is designed for an ESC with forward
 * and reverse (e.g. for a car).
 *
 * Initial use was for brushless motors on an ROV (mini-sub).
 */
#include <Servo.h>

#pragma mark Hand coded Servo Control

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

#ifdef unused
long lastPulse = 0;

void sendPulse(int pinNumber, int pulseWidth)
{
    digitalWrite(pinNumber, HIGH);
    delayMicroseconds(pulseWidth);
    digitalWrite(pinNumber, LOW);
}

void cycleServos()
{
    if(millis() - lastPulse > 20) {
        lastPulse=millis();
        
        int numServos = sizeof(servo_states) / sizeof(servo_state_t);
        for( int i=0; i<numServos; i++ )
        {
          servo_state *s = &servo_states[i];
          sendPulse(s->pin, s->usecs);
        }
    }
}
#endif

void initServos()
{
  int numServos = sizeof(servo_states) / sizeof(servo_state_t);
  for( int i=0; i<numServos; i++ )
  {
    servo_state *s = &servo_states[i];
    //pinMode(s->pin, OUTPUT);
    //sendPulse(s->pin, NEUTRAL);
    s->servo->attach(s->pin, minPulse, maxPulse);
  }
}

void setAllServos(int newUsecs)
{
  int numServos = sizeof(servo_states) / sizeof(servo_state_t);
  for( int i=0; i<numServos; i++ )
  {
    servo_state *s = &servo_states[i];
    // sendPulse(s->pin, value);
    s->servo->writeMicroseconds(newUsecs);
  }
}

// Wait for a character from the serial port and return it.
int getc()
{
  while( Serial.available() == 0 )
    //cycleServos();
    ;

  return Serial.read();
}

// Read characters from serial port and discard until CR is read and skipped.
void eatCharsToEOL()
{
  int c;
  while( c = getc() != '\n' )
  ;
}

void setup()
{
  // Initialize Servo pins and set their level to OFF
  initServos();
  
  setAllServos(NEUTRAL);
  
  // Initialize the serial port and send the host a message that we're up and runnin.
  Serial.begin(38400);  
  Serial.println("Arduino ready to program ESC");

}

void loop()
{
  static boolean firstTime = true;
  
  if( firstTime )
  {
    Serial.println("Waiting for key command to engage full Forward...");
    int key = getc();
    eatCharsToEOL();
    setAllServos(FULL_FORWARD);
    //cycleServos();
    
    // Full throttle
    Serial.println("Full Throttle on until next key, then full Reverse.");
    key = getc();
    eatCharsToEOL();
    setAllServos(FULL_REVERSE);
    //cycleServos();

    Serial.println("Full Reverse on until next key, then Neutral.");
    key = getc();
    eatCharsToEOL();
    setAllServos(NEUTRAL);
    //cycleServos();
    
    #ifdef unused
    Serial.println("Neutral for three seconds.");
    delay(3000);
    Serial.println("Sweep test.");
    for( int usecs=minPulse; usecs<maxPulse; usecs += 10 )
    {
      Serial.print("Speed: ");
      Serial.println(usecs, DEC);
      setAllServos(usecs);
      delay(100);
    }
#endif
    setAllServos(NEUTRAL);
    
    
    firstTime = false;
  }
  
  // cycleServos();

}

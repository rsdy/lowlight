#include "TimerOne.h"
#include "OneWire.h"
#include "DallasTemperature.h"
#include "EEPROM.h"

#include "util.h"

static void _blink_leds();

static OneWire _onewire(2);
static DallasTemperature _sensors(&_onewire);

static struct {
	uint8_t i;
	uint8_t v[2][3];
} leds = { 0, {{255,100,255}, {0,128,255}}};

static void _blink_leds() {
	leds.i ^= 1;
	PORTB ^= _BV(0) | _BV(1);

	analogWrite(3, leds.v[leds.i][0]); // red
	analogWrite(5, leds.v[leds.i][1]); // green
	analogWrite(6, leds.v[leds.i][2]); // blue
}

void setup() {
	Serial.begin(9600);

	DDRB |= _BV(0) | _BV(1);
	PORTB &= ~_BV(0);
	PORTB |= _BV(1);

	// by experimentation. this gives nice, constant light on both leds, with
	// minimal overlap
	Timer1.attachInterrupt(_blink_leds, 2000000);

//	_sensors.begin();
}

void loop() {
	int i;
/* commented section, because we're not quite here yet
    float temp;

	_sensors.requestTemperatures(); // Send the command to get temperatures
	temp = _sensors.getTempCByIndex(0);
	Serial.println(temp);
*/
	// will change this to ethernet communication in the future
	if(Serial.available() >= 4) {
		i = Serial.read(); // which led to screw around with

		if(i < 2) { // for security reasons
			// also, it would be ugly if the interrupt occured while modifying
			// the led colours. detach the interrupt then reattach it if we're
			// done with setting the levels
			Timer1.detachInterrupt();
			leds.v[i][0] = Serial.read();
			leds.v[i][1] = Serial.read();
			leds.v[i][2] = Serial.read();
			Timer1.attachInterrupt(_blink_leds, 2000000);
		}
	}
}


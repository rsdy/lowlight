/*
 * Time-division multiplexed RGB LED driver with temperature sensor support
 *
 * Copyright (c) 2010 Peter Parkanyi <me@rhapsodhy.hu>.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */
#include "TimerOne.h"
#include "OneWire.h"
#include "DallasTemperature.h"
#include "EEPROM.h"

#include "util.h"

static void _blink__leds();

enum _colours {
	RED = 0,
	GREEN = 1,
	BLUE = 2
};

// initializing to the specified colours is only for test purposes, gonna change
// it in the future
static struct {
	uint8_t i;
	uint8_t v[2][3];
} _leds = { 0, {{255,100,255}, {0,128,255}}};

/*
static OneWire _onewire(2);
static DallasTemperature _sensors(&_onewire);
*/

static void _blink_leds() {
	_leds.i ^= 1;
	PORTB ^= _BV(0) | _BV(1);

	analogWrite(3, _leds.v[_leds.i][RED]);
	analogWrite(5, _leds.v[_leds.i][GREEN]);
	analogWrite(6, _leds.v[_leds.i][BLUE]);
}

void setup() {
	Serial.begin(9600);

	DDRB |= _BV(0) | _BV(1);
	PORTB &= ~_BV(0);
	PORTB |= _BV(1);

	// by experimentation. this gives nice, constant light on both _leds, with
	// minimal overlap (although i experienced flickering when showing particular
	// colours)
	Timer1.attachInterrupt(_blink_leds, 2000000);

//	_sensors.begin();
}

void loop() {
	int i;
	uint8_t *led;

/* commented section, because we're not quite here yet
    float temp;

	_sensors.requestTemperatures(); // Send the command to get temperatures
	temp = _sensors.getTempCByIndex(0);
	Serial.println(temp);
*/

	// will change this to ethernet communication in the future
	if(Serial.available() > 3) {
		i = Serial.read(); // which led to screw around with

		if(i < 2) { // for security reasons
			led = _leds.v[i];

			// also, it would be ugly if the interrupt occured while modifying
			// the led colours. detach the interrupt then reattach it if we're
			// done with setting the levels
			TIMSK1 &= ~_BV(TOIE1);
			led[RED]   = Serial.read();
			led[GREEN] = Serial.read();
			led[BLUE]  = Serial.read();
			TIMSK1 |= _BV(TOIE1);
		}
	}
}


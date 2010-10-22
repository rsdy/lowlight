#include "TimerOne.h"
#include "OneWire.h"
#include "DallasTemperature.h"
#include "util.h"

static void blink_leds();

static OneWire onewire(2);
static DallasTemperature _sensors(&onewire);

static struct {
	uint8_t i;
	uint8_t v[2][3];
} leds = { 0, {{0,0,0}, {0,0,0}}};

static void blink_leds() {
	leds.i ^= 1;
	PORTB ^= _BV(0) | _BV(1);

	analogWrite(3, leds.v[leds.i][0]);
	analogWrite(5, leds.v[leds.i][1]);
	analogWrite(6, leds.v[leds.i][2]);
}

void setup() {
	Serial.begin(9600);

	DDRB |= _BV(0) | _BV(1);
	PORTB &= ~_BV(0);
	PORTB |= _BV(1);

	// by experimentation. this gives nice, constatn light on both leds, with
	// minimal overlap
	Timer1.attachInterrupt(blink_leds, 1500000);

	_sensors.begin();
}

void loop() {
	_sensors.requestTemperatures(); // Send the command to get temperatures
	float temp = _sensors.getTempCByIndex(0);
	Serial.println(temp);

	leds.v[0][0] = 255 * sin((temp / 10) * PI);
	leds.v[0][1] = 128 + 128 * cos((temp / 10) * PI);
	leds.v[0][2] = 128 + 128 * sin((temp / 10) * PI);

	leds.v[1][0] = 128 + 128 * sin((temp / 10) * PI);
	leds.v[1][1] = 255 * sin((temp / 10) * PI);
	leds.v[1][2] = 128 + 128 * cos((temp / 10) * PI);

	delay(1000);
}


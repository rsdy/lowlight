#include <stdio.h>
#include <stdlib.h>
#include <linux/soundcard.h>

int main() {
	printf("%llx\n", SNDCTL_DSP_SPEED);
	return 0;
}


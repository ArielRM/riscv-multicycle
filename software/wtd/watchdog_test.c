/*
 * Instituto Federal de Santa Catarina - C�mpus Florian�polis
 * Departamento Acad�mico de Eletr�nica
 * Curso de Engenharia Eletr�nica
 * Unidade Curricular: Dispositivos L�gico-Program�veis (PLD)
 * Professor:
 * -	Renan Augusto Starke	- renan.starke@ifsc.edu.br
 * Estudantes:
 * -	Heloiza Schaberle 		- heloizaschaberle@gmail.com
 * -	V�tor Faccio 			- vitorfaccio.ifsc@gmail.com
 *
 * watchdog_test.c
 *
 */

#include "../_core/utils.h"
#include "../_core/hardware.h"
#include "../gpio/gpio.h"
#include "watchdog.h"


int main(){

	uint32_t wtd_mode = 1;
	uint32_t prescaler = 1;
	uint32_t top_counter = 250; // pra dar +- em 1/8 da simula��o

	wtd_config(wtd_mode, prescaler, top_counter);

	wtd_enable();
	delay_(10);
	wtd_disable();
	delay_(10);


	wtd_enable();
	delay_(3);
	wtd_hold(1);
	delay_(3);
	wtd_hold(0);

	delay_(40);
	wtd_disable();

	delay_(10);
	wtd_enable();
	while(!wtd_interrupt_read());
	OUTBUS = 1;

	while (1){

		delay_(10000);

	}

	return 0;
}

/*
 * uart.h
 *
 *  Created on: July 1, 2019
 *      Author: Marcos VinÃ­cius Leal da Silva e Daniel Pereira
 *      Instituto Federal de Santa Catarina
 * 
 * UART functions
 *  - write
 *  - send
 *	- read
 *	- (...)
 * 
 */

#include <stdint.h>
#include "uart.h"
#include "hardware.h"

void UART_write(int character){
	/* To do:
		- Change variable "character" to uint8_t
	*/
	UART_TX = (0x01 << 8) | character;
	return;
}

void UART_setup(int baud, int parity){
	/* To do:
		baud = 0 => baud_rate = 38400
		baud = 1 => baud_rate = 19200
		baud = 2 => baud_rate = 09600
		baud = 3 => baud_rate = 04800
		
		parity = 0 => parity_off
		parity = 1 => parity_off
		parity = 2 => parity_on odd
		parity = 3 => parity_on even
	*/
	
	
	UART_SETUP = (baud & 0x03) | ((0x3 & parity) << 2);
	return;
} 

int UART_read(void){
	/* To do:
		- Change variable "byte" to uint8_t
	*/
	int byte;
	
	byte = UART_RX;
	return byte;
}


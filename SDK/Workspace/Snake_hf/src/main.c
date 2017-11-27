/*
 * Copyright (c) 2009-2012 Xilinx, Inc.  All rights reserved.
 *
 * Xilinx, Inc.
 * XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" AS A
 * COURTESY TO YOU.  BY PROVIDING THIS DESIGN, CODE, OR INFORMATION AS
 * ONE POSSIBLE   IMPLEMENTATION OF THIS FEATURE, APPLICATION OR
 * STANDARD, XILINX IS MAKING NO REPRESENTATION THAT THIS IMPLEMENTATION
 * IS FREE FROM ANY CLAIMS OF INFRINGEMENT, AND YOU ARE RESPONSIBLE
 * FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE FOR YOUR IMPLEMENTATION.
 * XILINX EXPRESSLY DISCLAIMS ANY WARRANTY WHATSOEVER WITH RESPECT TO
 * THE ADEQUACY OF THE IMPLEMENTATION, INCLUDING BUT NOT LIMITED TO
 * ANY WARRANTIES OR REPRESENTATIONS THAT THIS IMPLEMENTATION IS FREE
 * FROM CLAIMS OF INFRINGEMENT, IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.
 *
 */

/*
 * helloworld.c: simple test application
 *
 * This application configures UART 16550 to baud rate 9600.
 * PS7 UART (Zynq) is not initialized by this application, since
 * bootrom/bsp configures it to baud rate 115200
 *
 * ------------------------------------------------
 * | UART TYPE   BAUD RATE                        |
 * ------------------------------------------------
 *   uartns550   9600
 *   uartlite    Configurable only in HW design
 *   ps7_uart    115200 (configured by bootrom/bsp)
 */

#include <stdio.h>
#include "platform.h"
#include "fonts.h"
#include <xio.h>
#include <xparameters.h>
#include <stdint.h>
#include <stdlib.h>
#include <xtmrctr.h>
#include <xintc_l.h>
#include <mb_interface.h>
#include <time.h>



#define LCD_W 102
#define LCD_H 64
#define XSIZE 25
#define YSIZE 15
#define SNAKE 1
#define FOOD 3
#define BORDER 5
#define MAX_LENGTH 360
#define LEVEL_LIMIT 10
enum { RIGHT = -1, UP = 1, LEFT = -2, DOWN = 2};

volatile int SPI_ACK;
volatile unsigned char lcd_map[LCD_W][LCD_H];

//Gamefield
volatile uint8_t map[XSIZE][YSIZE];

//Circular buffers for snake coordinates
volatile uint8_t snake_x[MAX_LENGTH];
volatile uint8_t snake_y[MAX_LENGTH];
volatile int	 head_index = 0;
volatile uint8_t length = 4;

//Head direction and coordinates
volatile int		direction = RIGHT;
volatile int		x_position = 10;
volatile int		y_position = 10;

//Food coordinates
volatile uint8_t food_x;
volatile uint8_t food_y;

//Control variables
volatile uint8_t level = 1;
volatile uint8_t food_eaten = 0;
volatile uint8_t alive = 0;
volatile uint8_t lcd_rewrite = 0;

void timer_callback() {
	int offset, index;

	//Check wall collision
	switch (direction) {
	case RIGHT: {
		x_position++;
		if (x_position >= XSIZE) {
			alive = 0;
			return;
		}
		break;
	}
	case UP: {
		y_position--;
		if (y_position < 0) {
			alive = 0;
			return;
		}
		break;
	}
	case LEFT: {
		x_position--;
		if (x_position < 0) {
			alive = 0;
			return;
		}
		break;
	}
	case DOWN: {
		y_position++;
		if (y_position >= YSIZE) {
			alive = 0;
			return;
		}
		break;
	}
	default: return;
	}

	//Check self collision
	if (map[x_position][y_position] == SNAKE) {
		alive = 0;
		return;
	}

	//Save offset
	offset = length - 1;

	//Check food
	if (map[x_position][y_position] == FOOD) {
		if (++length >= MAX_LENGTH) {
			alive = 2;	//Winner
			return;
		}
		food_eaten++;
		//Generate new food
		while (map[food_x][food_y] != 0) {
			food_x = rand() % XSIZE;
			food_y = rand() % YSIZE;
		}
		map[food_x][food_y] = FOOD;
	}
	else {
		//Remove tail
		index = head_index - offset;
		if (index < 0) index = index + MAX_LENGTH;
		map[snake_x[index]][snake_y[index]] = 0;
	}

	//Add new head
	if (++head_index >= MAX_LENGTH)
		head_index = 0;
	snake_x[head_index] = x_position;
	snake_y[head_index] = y_position;
	map[x_position][y_position] = SNAKE;
}

void SPI_Send(int data){
	while(SPI_ACK == 0);
	SPI_ACK = 0;
	XIo_Out32(XPAR_SPI_IO_0_BASEADDR, data);
}

void LCD_send_command(int command){
	SPI_Send(0x01010000 | command);
	return;
}
void LCD_send_data(int data){
	SPI_Send(0x01010100 | data);
	return;
}

void LCD_write_full_display(){
	unsigned char a, b, c;
	char d;
	//Resize matrix
	for(a = 0; a < (LCD_H-4); a++)
		for(b = 0; b < (LCD_W-2); b++)
			lcd_map[b+1][a+2]= map[b/4][a/4];

	//Redesign food
	lcd_map[4*food_x+1][4*food_y+2] = 0;
	lcd_map[4*food_x+1+3][4*food_y+2] = 0;
	lcd_map[4*food_x+1][4*food_y+2+3] = 0;
	lcd_map[4*food_x+1+3][4*food_y+2+3] = 0;

	for(a = 0; a < (LCD_H / 8); a++){
		LCD_send_command(0x010100B0 | a);
		LCD_send_command(0x0101000E);
		LCD_send_command(0x01010011);
		for(b = 0; b < LCD_W; b++){
			for(c = 0, d = 7; d >= 0; d--){
				c = (c << 1) + (lcd_map[b][a * 8 + d] & 0x01);
			}
			LCD_send_data(c);
		}
	}
	return;
}

void timer_int_handler(void *instancePtr){
	unsigned long csr;
	if(alive == 1)
		timer_callback();
	lcd_rewrite = 1;

	csr = XTmrCtr_GetControlStatusReg(XPAR_AXI_TIMER_0_BASEADDR, 0);
	XTmrCtr_SetControlStatusReg(XPAR_AXI_TIMER_0_BASEADDR, 0, csr);
}

void spi_int_handler(void *instancePtr){
	SPI_ACK = 1;
}

void LCD_init(){
	int i, a, b;
	int command[13] = {0x40,0xA0,0xC8,0xA4,0xA6,0xA2,0x2F,0x27,0x81,0x10,0xFA,0x90,0xAF};
	for(i = 0; i < 13; i++)
		LCD_send_command(command[i]);

	//Initialize clear map with border
	for(a = 0; a < LCD_H; a++){
		for(b = 0; b < LCD_W; b++){
			if ((b > 0 && b < (LCD_W-1) && a > 1 && a < (LCD_H-2)) || a == 0 || a == (LCD_H-1))
				lcd_map[b][a] = 0;
			else
				lcd_map[b][a] = BORDER;
		}
	}
}

void LCD_bitmap(const unsigned char *bitmap){
	int a, b;
	for(a = 0; a < (LCD_H / 8); a++){
		LCD_send_command(0x010100B0 | a);
		LCD_send_command(0x0101000E);
		LCD_send_command(0x01010011);
		for(b = 0; b < LCD_W; b++){
			LCD_send_data(bitmap[a*LCD_W + b]);
		}
	}
}

void init_game(){
	int offset, index, i, j;

	alive = 0;
	level = 1;
	length = 4;
	food_eaten = 0;
	x_position = 10;
	y_position = 10;

	//Initialize clear game map
	for (j = 0; j < YSIZE; j++)
		for (i = 0; i < XSIZE; i++)
			map[i][j] = 0;

	//Initialize snake (using circular buffer)
	for (i = 0; i < length; i++) {
		snake_x[i] = ++x_position;
		snake_y[i] = y_position;
	}
	head_index = length - 1;

	//Draw snake
	for (offset = 0; offset < length; offset++) {
		index = head_index - offset;
		if (index < 0)
			index = index + MAX_LENGTH;
		map[snake_x[index]][snake_y[index]] = SNAKE;
	}

	//Generate random new food
	do {
		food_x = rand() % XSIZE;
		food_y = rand() % YSIZE;
	} while (map[food_x][food_y] != 0);
	map[food_x][food_y] = FOOD;
}

int main()
{
	int control, new_dir, a, i;
	SPI_ACK = 1;
	srand(time(NULL));

	init_platform();

	//Interrupt routines
	XIntc_RegisterHandler(XPAR_INTC_SINGLE_BASEADDR, XPAR_MICROBLAZE_0_INTC_SPI_IO_0_READY_INTR, (XInterruptHandler) spi_int_handler, NULL);
	XIntc_RegisterHandler(XPAR_MICROBLAZE_0_INTC_BASEADDR, XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR,(XInterruptHandler) timer_int_handler,	NULL);

	//Enable interrupts
	XIntc_MasterEnable(XPAR_MICROBLAZE_0_INTC_BASEADDR);
	XIntc_EnableIntr(XPAR_INTC_0_BASEADDR, XPAR_AXI_TIMER_0_INTERRUPT_MASK | XPAR_SPI_IO_0_READY_MASK);
	microblaze_enable_interrupts();

	//Enable SPI interrupt
	XIo_Out32(0x77A0000B, 0xF0000000);

	//Setup timer
	XTmrCtr_SetLoadReg(XPAR_AXI_TIMER_0_BASEADDR, 0, XPAR_AXI_TIMER_0_CLOCK_FREQ_HZ/4);
	XTmrCtr_SetControlStatusReg(XPAR_AXI_TIMER_0_BASEADDR,0,XTC_CSR_INT_OCCURED_MASK | XTC_CSR_LOAD_MASK);

	//Start timer
	XTmrCtr_SetControlStatusReg(XPAR_AXI_TIMER_0_BASEADDR,0,XTC_CSR_ENABLE_TMR_MASK | XTC_CSR_ENABLE_INT_MASK |XTC_CSR_AUTO_RELOAD_MASK | XTC_CSR_DOWN_COUNT_MASK);

	//Welcome screen
	LCD_init();
	LCD_bitmap(welcome);

	// Game
	while(1){
		// Init game
		direction = RIGHT;
		init_game();

		//Wait for input
		do {
			//Set level
			a = (~XIo_In32(0x7e400004) & 0xFF);
			for (i = 0; i < 8; i++){
				if ((a & (1 << i)) != 0){
					level = 8-i;
					break;
				}
				else
					level = 1;
			}
			//Level rewrite
			a = 0x00FF & ~((1 << (8-level))-1);
			XIo_Out32(0x7e400000, a);
		}while (((XIo_In32(0x7e400004) & 0xF00) >> 8) == 0);

		//Init LCD
		LCD_write_full_display();

		//Set timer clock (speed)
		XTmrCtr_SetLoadReg(XPAR_AXI_TIMER_0_BASEADDR, 0, XPAR_AXI_TIMER_0_CLOCK_FREQ_HZ/(level+2));

		//Game start
		alive = 1;
		while(alive == 1) {
			if (lcd_rewrite == 1){
				//LCD rewrite
				LCD_write_full_display();

				//Level up
				if (food_eaten > LEVEL_LIMIT){
					level++;
					if (level > 8)
						alive = 2;
					food_eaten = 0;
					//Set timer clock (speed)
					XTmrCtr_SetLoadReg(XPAR_AXI_TIMER_0_BASEADDR, 0, XPAR_AXI_TIMER_0_CLOCK_FREQ_HZ/(level+2));
				}

				//Level rewrite
				a = 0x00FF & ~((1 << (8-level))-1);

				//Score rewrite
				a = a | (0x0F00 & ((food_eaten%10) << 8));
				a = a | (0xF000 & ((food_eaten/10) << 12));

				XIo_Out32(0x7e400000, a);
				lcd_rewrite = 0;
			}

			//Controls
			control = (XIo_In32(0x7e400004) & 0xF00) >> 8;
			switch (control) {
			case 4: {
				new_dir = LEFT;
				break;
			}
			case 8: {
				new_dir = RIGHT;
				break;
			}
			case 1: {
				new_dir = UP;
				break;
			}
			case 2: {
				new_dir = DOWN;
				break;
			}
			default:
				new_dir = direction;
			}

			//Prevent 180 degree turn
			if ((direction*new_dir) < 0)
				direction = new_dir;
		}

		if(alive == 0){
			//GAME OVER
			LCD_bitmap(gameover);
		}
		else if(alive == 2){
			//WINNER
			LCD_bitmap(winner);
		}
	}
}

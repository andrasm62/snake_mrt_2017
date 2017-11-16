/*
 * Copyright (c) 2009-2012 Xilinx, Inc.  All rights reserved.
 *
 * Xilinx, Inc.
 * XILINX IS PROVIDING THIS DESIGN, CODE, OR INFORMATION "AS IS" AS A
 * COURTESY TO YOU.  BY PROVIDING THIS DESIGN, CODE, OR INFORMATION AS
 * ONE POSSIBLE   IMPLEMSPI_IRQ_ACKTATION OF THIS FEATURE, APPLICATION OR
 * STANDARD, XILINX IS MAKING NO REPRESSPI_IRQ_ACKTATION THAT THIS IMPLEMSPI_IRQ_ACKTATION
 * IS FREE FROM ANY CLAIMS OF INFRINGEMSPI_IRQ_ACKT, AND YOU ARE RESPONSIBLE
 * FOR OBTAINING ANY RIGHTS YOU MAY REQUIRE FOR YOUR IMPLEMSPI_IRQ_ACKTATION.
 * XILINX EXPRESSLY DISCLAIMS ANY WARRANTY WHATSOEVER WITH RESPECT TO
 * THE ADEQUACY OF THE IMPLEMSPI_IRQ_ACKTATION, INCLUDING BUT NOT LIMITED TO
 * ANY WARRANTIES OR REPRESSPI_IRQ_ACKTATIONS THAT THIS IMPLEMSPI_IRQ_ACKTATION IS FREE
 * FROM CLAIMS OF INFRINGEMSPI_IRQ_ACKT, IMPLIED WARRANTIES OF MERCHANTABILITY
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

#define LCD_W 102
#define LCD_H 64


#include <stdio.h>
#include "platform.h"
#include <xio.h>
#include <xparameters.h>

#include <xtmrctr.h>
#include <xintc_l.h>
#include <mb_interface.h>

volatile unsigned long iValue;
volatile int SPI_IRQ_ACK;
unsigned char map[LCD_H][LCD_W];
XTmrCtr* gpTmrCtr;	// Pointer to Timer Counter, used for general timing
XTmrCtr* gpTimer;	// Pointer to 64-bit Timer, used for absolute time



void timer_int_handler(void *instancePtr){
	unsigned long csr;
	int a;
	a = XIo_In32(0x7e400000);
	a = ~a;
	XIo_Out32(0x7e400000, a);
	csr = XTmrCtr_GetControlStatusReg(XPAR_AXI_TIMER_0_BASEADDR, 0);
	XTmrCtr_SetControlStatusReg(XPAR_AXI_TIMER_0_BASEADDR, 0, csr);
}

void spi_int_handler(void *instancePtr)
{
	unsigned long csr = 0x55;
	XIo_Out32(0x7e400000, csr);
	SPI_IRQ_ACK = 1;
}

void SPI_Send(int data){
	while(SPI_IRQ_ACK == 0);
	SPI_IRQ_ACK = 0;
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

void LCD_init(){
	int i, a, b;
	int command[13] = {0x40,0xA0,0xC8,0xA4,0xA6,0xA2,0x2F,0x27,0x81,0x10,0xFA,0x90,0xAF};
	for(i = 0; i < 13; i++){
		LCD_send_command(command[i]);
	   }
	for(a = 0; a < (LCD_H); a++){
		for(b = 0; b < (LCD_W); b++){
			map[a][b] = 0;
		}
	}
map[1][1] = 1;

map[1][2] = 1;

map[2][2] = 1;

map[20][30] = 1;
for(i = 0; i< LCD_W; i++)
	map[5][i] = 1;

	return;
}

void LCD_write_full_display(){
	unsigned char a, b, c;
	char d;
	for(a = 0; a < (LCD_H / 8); a++){
		LCD_send_command(0x010100B0 | a);
		LCD_send_command(0x0101000E);
		LCD_send_command(0x01010011);
		for(b = 0; b < LCD_W; b++){
			for(c = 0, d = 7; d >= 0; d--){
				c = (c << 1) + (map[a * 8 + d][b] & 0x01);
			}
			LCD_send_data(c);
		}
	}
	return;
}

int main()
{
	unsigned long a;
	int i, j;
	XTmrCtr tmrctr;
	gpTmrCtr = &tmrctr;


	init_platform();

	SPI_IRQ_ACK = 1;
    //A megszakításkezelõ rutin beállítása.
    XIntc_RegisterHandler(XPAR_INTC_SINGLE_BASEADDR, XPAR_MICROBLAZE_0_INTC_SPI_IO_0_READY_INTR, (XInterruptHandler) spi_int_handler, NULL);
	XIntc_RegisterHandler(XPAR_MICROBLAZE_0_INTC_BASEADDR, XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR,(XInterruptHandler) timer_int_handler,	NULL);

    //A megszakítás vezérlõ konfigurálása.
	XIntc_MasterEnable(XPAR_MICROBLAZE_0_INTC_BASEADDR);

	//A megszakítások engedélyezése a processzoron.
	XIntc_EnableIntr(XPAR_INTC_0_BASEADDR, XPAR_AXI_TIMER_0_INTERRUPT_MASK | XPAR_SPI_IO_0_READY_MASK);

    //A megszakítások engedélyezése a processzoron.
    microblaze_enable_interrupts();

    //Kapcsolók beolvasása és LED-ekre írás
    a = XIo_In32(0x7e400004);
    XIo_Out32(0x7e400000, a);
    //SPI interrupt engedélyezés
    XIo_Out32(0x77A0000B, 0xF0000000);

	XTmrCtr_SetLoadReg(XPAR_AXI_TIMER_0_BASEADDR, 0, XPAR_AXI_TIMER_0_CLOCK_FREQ_HZ/4);
    XTmrCtr_SetControlStatusReg(XPAR_AXI_TIMER_0_BASEADDR,0,XTC_CSR_INT_OCCURED_MASK | XTC_CSR_LOAD_MASK);
    //A timer elindítása.
    XTmrCtr_SetControlStatusReg(XPAR_AXI_TIMER_0_BASEADDR,0,XTC_CSR_ENABLE_TMR_MASK | XTC_CSR_ENABLE_INT_MASK |XTC_CSR_AUTO_RELOAD_MASK | XTC_CSR_DOWN_COUNT_MASK);

   LCD_init();
   LCD_write_full_display();
/*
   for(i = 0; i < 8; i++){
	   while(SPI_IRQ_ACK == 0);
   	   SPI_IRQ_ACK = 0;
   	   XIo_Out32(0x77a00000, 0x010100B0 | i);
	   while(SPI_IRQ_ACK == 0);
   	   SPI_IRQ_ACK = 0;
   	   XIo_Out32(0x77a00000, 0x01010000);
	   while(SPI_IRQ_ACK == 0);
   	   SPI_IRQ_ACK = 0;
   	   XIo_Out32(0x77a00000, 0x01010010);
   	   for(j = 0; j< 200; j++){
   		   while(SPI_IRQ_ACK == 0);
		   SPI_IRQ_ACK = 0;
		   XIo_Out32(0x77a00000, 0x01010155);
   	   }
   }
*/
//while((XIo_In32(0x7e400004)&0xFF) != 0x00){};

	while(1){
		a=XIo_In32(0x7e400004);
		//XIo_Out32(0x7e400000, a);
	}
    return 0;
}

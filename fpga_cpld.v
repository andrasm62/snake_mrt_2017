`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    11:02:20 02/08/2017 
// Design Name: 
// Module Name:    fpga_cpld 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module fpga_cpld(
   input clk,
   input rst,
   
   input [7:0] led,
   input [3:0] seg0,
   input [3:0] seg1,
   output [7:0] sw,
   output [4:0] nav_sw
   
   output reg  cpld_clk,
   output reg  cpld_ld,
   output reg  cpld_mosi,
   input       cpld_miso
);
   
wire [3:0] seg_mux;

reg [15:0] shiftreg, shiftreg_2;
reg [11:0] szamlalo_12;
reg [7:0] seg_data, sw_reg;
reg [4:0] szamlalo_5, nav_sw_reg;
reg eldetektalo, ce;
	
	
//12 bites számláló
always @(posedge clk)
begin
if(rst)
	szamlalo_12 <= 0;
else
	szamlalo_12 <= szamlalo_12 + 1;
end

//Éldetektáló
always @(posedge clk)
begin
if(rst)
	eldetektalo <= 0;
else
	if(eldetektalo == 1 && szamlalo_12[11] == 0)
		ce <= 1;
	else
		ce <= 0;
	eldetektalo <= szamlalo_12[11];
end

//5 bites számláló
always @(posedge clk)
begin
if(rst)
	szamlalo_5 <= 0;
else
	if(ce)
		szamlalo_5 <= szamlalo_5 +1;
end

//Hétszegmenses kijelzo multiplexer

assign seg_mux = szamlalo_5[4] ? seg1 : seg0;

//Bin to 7SEG
always @(seg_mux)
case (seg_mux)
   4'b0001 : seg_data = 8'b11111001;   // 1
   4'b0010 : seg_data = 8'b10100100;   // 2
   4'b0011 : seg_data = 8'b10110000;   // 3
   4'b0100 : seg_data = 8'b10011001;   // 4
   4'b0101 : seg_data = 8'b10010010;   // 5
   4'b0110 : seg_data = 8'b10000010;   // 6
   4'b0111 : seg_data = 8'b11111000;   // 7
   4'b1000 : seg_data = 8'b10000000;   // 8
   4'b1001 : seg_data = 8'b10010000;   // 9
   4'b1010 : seg_data = 8'b10001000;   // A
   4'b1011 : seg_data = 8'b10000011;   // b
   4'b1100 : seg_data = 8'b11000110;   // C
   4'b1101 : seg_data = 8'b10100001;   // d
   4'b1110 : seg_data = 8'b10000110;   // E
   4'b1111 : seg_data = 8'b10001110;   // F
   default : seg_data = 8'b11000000;   // 0
endcase

//Shiftregiszter
always @(posedge clk)
begin
if(rst) begin
	shiftreg <= 0;
	shiftreg_2 <= 0;
	end
else if(ce)
	begin
		if(szamlalo_5[3:0] == 15) begin
			shiftreg <= {~seg_data,led};
			sw_reg <= shiftreg_2[7:0];
			nav_sw_reg <= shiftreg_2[12:8];
			end
		else
			begin
			shiftreg <= {1'b0,shiftreg[15:1]};
			shiftreg_2 <= {cpld_miso,shiftreg_2[15:1]};
			end
	end
end

//Kimenet állítás
always @(posedge clk)
begin
if(rst)
	begin
		cpld_ld <= 0;
		cpld_clk <= 0;
		cpld_mosi <= 0;
	end
else
	begin
		cpld_ld <= (szamlalo_5[3:0] == 15);
		cpld_clk <= szamlalo_12[11];
		cpld_mosi <= shiftreg[0];
	end
end

assign sw = sw_reg;
assign nav_sw = nav_sw_reg;

endmodule

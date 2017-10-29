`timescale 1ns / 1ps

module spi_master (
input clk,
input rst,
input miso,
output mosi,
output sck,
input start,
output busy,
input ready_en,
output ready,
input[7:0] data_in,
output[7:0] data_out
);

localparam STATE_SIZE = 2;
localparam IDLE = 2'b00, START = 2'b01, TRANSFER = 2'b10, READY = 2'b11;
localparam CLK_DIV_VAL_HALF = 24999;
localparam CLK_DIV_VAL = 49999;


reg [15:0] clk_cntr;
reg [7:0] data_reg;
reg [3:0] sck_cntr;
reg [2:0] state_reg;
reg mosi_reg, start_reg, sck_reg, ready_reg, ready_en_reg;
wire en;

assign en = (clk_cntr == CLK_DIV_VAL);
assign mosi = mosi_reg;
assign sck = (sck_reg);
assign ready = ready_reg;
assign busy = (state_reg != IDLE);
assign data_out = data_reg;


//CLK divide
always @(posedge clk) begin
	if(rst)
		clk_cntr <= 0;
	else if(state_reg != IDLE) begin
		if(clk_cntr == CLK_DIV_VAL)
			clk_cntr <= 0;
		else
			clk_cntr <= clk_cntr + 1;
	end
end

//Counting SCK pulses
always @(posedge clk) begin
	if(rst)
		sck_cntr <= 0;
	else if(clk_cntr == CLK_DIV_VAL)
		sck_cntr <= sck_cntr + 1;
end

//Status register
always @(posedge clk) begin
	if(rst) begin
		state_reg <= IDLE;
		start_reg <= 0;
	end
	else begin
		start_reg <= start;
		case(state_reg)
			IDLE: begin
				if(start_reg == 1)
					state_reg <= START;
			end
			START: begin
				state_reg <= TRANSFER;
				end
			TRANSFER: begin
				if(sck_cntr == 4'd8)
				state_reg <= READY;
			end
			READY:
				state_reg <= IDLE;
		endcase
	end
end


//data register
always @(posedge clk) begin
	if(rst)
		data_reg <= 0;
	else if(state_reg == START)
		data_reg <= data_in;
	else if((state_reg == TRANSFER) && (clk_cntr == CLK_DIV_VAL_HALF))
		data_reg <= {data_reg[6:0], miso};
end

//SCK counter register
always @(posedge clk) begin
	if(rst)
		sck_cntr <= 0;
	else if(state_reg == TRANSFER && en)
		sck_cntr <= sck_cntr + 1;
end

//SCK register
always @(posedge clk) begin
	if(rst)
		sck_reg <= 0;
	else if(clk_cntr == CLK_DIV_VAL_HALF)
	sck_reg <= 1;
	else if(clk_cntr == CLK_DIV_VAL)
	sck_reg <= 0;
end

//MOSI register
always @(posedge clk) begin
	if(rst)
		mosi_reg <= 0;
	else if((state_reg == START) || (clk_cntr == CLK_DIV_VAL))
		mosi_reg <= data_reg[7];
end	

//Ready register
always @(posedge clk) begin
	if (rst) begin
		ready_reg <= 0;
		ready_en_reg <= 0;
	end
	else begin
		ready_en_reg <= ready_en;
		if(state_reg == READY && ready_en_reg)
			ready_reg <= 1;
		else 
			ready_reg <= 0;
	end
end

endmodule


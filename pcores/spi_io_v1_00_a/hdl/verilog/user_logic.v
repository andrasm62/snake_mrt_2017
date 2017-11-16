`uselib lib=unisims_ver
`uselib lib=proc_common_v3_00_a

module user_logic #(
	//Az IPIF interf�szhez tartoz� param�terek.
	parameter C_NUM_REG                      = 3,		//Az IPIF �ltal dek�dolt 32 bites regiszterek sz�ma.
	parameter C_SLV_DWIDTH                   = 32		//Az adatbusz sz�less�ge bitekben.
   
	//Itt kell megadni a t�bbi saj�t param�tert.
) (
	//Az IPIF interf�szhez tartoz� portok. Ha a Create or Import Peripheral
	//Wizard-ban nem jel�lt�k be a mem�ria interf�szhez tartoz� Bus2IP_Addr,
	//Bus2IP_CS �s Bus2IP_RNW jelek hozz�ad�s�t, akkor ezeket innen t�r�lj�k.
	input  wire                      Bus2IP_Clk,			//�rajel.
	input  wire                      Bus2IP_Resetn,		//Akt�v alacsony reset jel.
//	input  wire [31:0]               Bus2IP_Addr,		//C�mbusz.
//	input  wire [0:0]                Bus2IP_CS,			//A perif�ria c�mtartom�ny�nak el�r�s�t jelzo jel.
//	input  wire                      Bus2IP_RNW,			//A muvelet t�pus�t (0: �r�s, 1: olvas�s) jelzo jel.
	input  wire [C_SLV_DWIDTH-1:0]   Bus2IP_Data,		//�r�si adatbusz.
	input  wire [C_SLV_DWIDTH/8-1:0] Bus2IP_BE,			//B�jt enged�lyezo jelek (csak �r�s eset�n �rv�nyesek).
	input  wire [C_NUM_REG-1:0]      Bus2IP_RdCE,		//A regiszterek olvas�s enged�lyezo jelei.
	input  wire [C_NUM_REG-1:0]      Bus2IP_WrCE,		//A regiszterek �r�s enged�lyezo jelei.
	output reg  [C_SLV_DWIDTH-1:0]   IP2Bus_Data,		//Olvas�si adatbusz.
	output wire                      IP2Bus_RdAck,		//Az olvas�si muveletek nyugt�z� jele.
	output wire                      IP2Bus_WrAck,		//Az �r�si muveletek nyugt�z� jele.
	output wire                      IP2Bus_Error,		//Hibajelz�s.
   
   //Itt kell megadni a t�bbi saj�t portot.

	//input								miso_I,
	output							miso,
	//output							miso_T,
	output							mosi,
	output							sck,
	output							spi_sdcard_csn,
	output							spi_flash_csn,
	output							spi_lcd_csn,
	output							ready
);

localparam STATE_SIZE = 2;
localparam IDLE = 2'b00, START = 2'b01, TRANSFER = 2'b10, READY = 2'b11;
localparam CLK_DIV_VAL_HALF = 9; //CLK_DIV_VAL_HALF = (CLK_DIV_VAL - 1) / 2
localparam CLK_DIV_VAL = 19; // SPI Speed will be CPU_SPEED / 20

//
wire clk = Bus2IP_Clk;
wire rst = ~Bus2IP_Resetn;
wire en;

reg [15:0] clk_cntr;
reg [7:0] data_in_reg, data_out_reg, data_reg;
reg [3:0] sck_cntr;
reg [2:0] state_reg;
reg mosi_reg, miso_reg, sck_reg;
reg spi_sdcard_csn_reg, spi_flash_csn_reg, spi_lcd_csn_reg;


assign cpld_jtagen = 0;
assign cpld_rstn = Bus2IP_Resetn;
assign miso = c_d_reg;
//assign miso_O = c_d_reg;
//assign miso_T = (mode_reg && ~spi_lcd_csn_reg && state_reg == TRANSFER);

assign en = (clk_cntr == CLK_DIV_VAL);
assign mosi = mosi_reg;
assign sck = (sck_reg);
assign ready = ready_reg;
assign busy = (state_reg != IDLE);
assign data_out = data_out_reg;
assign spi_sdcard_csn = spi_sdcard_csn_reg;
assign spi_flash_csn = spi_flash_csn_reg;
assign spi_lcd_csn = spi_lcd_csn_reg;

//******************************************************************************
//* DATA_IN register (BASE+0x00, 8 bit, RW).                                       *
//******************************************************************************
wire		data_in_reg_wr = Bus2IP_WrCE[2];

always @(posedge clk)
begin
	if (rst)
		data_in_reg <= 8'd0;
	else if (data_in_reg_wr)
		data_in_reg <= Bus2IP_Data[7:0];
end

//******************************************************************************
//* Conversion START register (BASE+0x01, 1bit, RW).                                       *
//******************************************************************************
reg			start_reg;
wire		start_reg_wr = Bus2IP_WrCE[2];

always @(posedge clk)
begin
	if (rst)
		start_reg <= 1'd0;
	else if(start_reg == 1)
					start_reg <= 0;
	else if (start_reg_wr)
		start_reg <= Bus2IP_Data[24];
end

//******************************************************************************
//* CS and LCD MODE register (BASE+0x02, 1 + 3 bit, RW).                                       *
//******************************************************************************
reg [2:0]	cs_reg;
reg 		mode_reg;
wire		cs_reg_wr = Bus2IP_WrCE[2];

always @(posedge clk)
begin
	if (rst) begin
		mode_reg <= 1'd0;
		cs_reg <= 0;
	end
	else if (cs_reg_wr) begin
		mode_reg <= Bus2IP_Data[19];
		cs_reg <= Bus2IP_Data[18:16];
	end
end

//******************************************************************************
//* LCD Command/Data register (BASE+0x03, 1 bit, RW).                                       *
//******************************************************************************
reg			c_d_reg;
wire		c_d_reg_wr = Bus2IP_WrCE[2];

always @(posedge clk)
begin
	if (rst)
		c_d_reg <= 1'd0;
	else if (c_d_reg_wr)
		c_d_reg <= Bus2IP_Data[8];
end

//******************************************************************************
//* Interrupt register (BASE+0x0B, 1 bit, RW).                                       *
//******************************************************************************
reg			ready_reg, ready_en_reg;
wire		ready_reg_wr = Bus2IP_WrCE[0];

always @(posedge clk)
begin
	if (rst) begin
		ready_en_reg <= 1'd0;
	end
	else if (ready_reg_wr) begin
		ready_en_reg <= Bus2IP_Data[31];
	end
end

//******************************************************************************
//* Driving the AXI output ports.                                              *
//******************************************************************************
assign IP2Bus_RdAck = |Bus2IP_RdCE;
assign IP2Bus_WrAck = |Bus2IP_WrCE;
assign IP2Bus_Error = 1'b0;

always @(*)
begin
	case (Bus2IP_RdCE)
		3'b100: IP2Bus_Data <= {7'd0, start_reg, 4'd0, mode_reg, cs_reg, 7'd0, c_d_reg, data_in_reg};
		3'b010: IP2Bus_Data <= {23'd0, busy, data_out_reg};
		3'b001: IP2Bus_Data <= {ready_en_reg, 22'd0, ready_reg};
		default: IP2Bus_Data <= 32'd0;
	endcase
end

	
//CLK divide
always @(posedge clk) begin
	if(rst)
		clk_cntr <= 0;
	else if(state_reg == IDLE)
		clk_cntr <= 0;
	else begin
		if(clk_cntr == CLK_DIV_VAL)
			clk_cntr <= 0;
		else
			clk_cntr <= clk_cntr + 1;
	end
end

//Status register
always @(posedge clk) begin
	if(rst) begin
		state_reg <= IDLE;
	end
	else begin
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

//data_in register
always @(posedge clk) begin
	if(rst)
		data_reg <= 0;
	else if(state_reg == START)
		data_reg <= data_in_reg;
	else if((state_reg == TRANSFER) && (clk_cntr == CLK_DIV_VAL))
		data_reg <= {data_reg[6:0], miso_reg};
end

//data_out register
always @(posedge clk) begin
	if(rst)
		data_out_reg <= 0;
	else if(state_reg == READY)
		data_out_reg <= data_reg;
end

//SCK counter register
always @(posedge clk) begin
	if(rst)
		sck_cntr <= 0;
	else if(state_reg == START)
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
	else if(state_reg == TRANSFER)
		mosi_reg <= data_reg[7];
	else
		mosi_reg <= 0;
end	

/*
//MISO reg
always @(posedge clk) begin
	if(rst)
		miso_reg <= 0;
	else if((state_reg == TRANSFER) && (clk_cntr == CLK_DIV_VAL_HALF))
		miso_reg <= miso;
end
*/

//Ready register
always @(posedge clk) begin
	if (rst) begin
		ready_reg <= 0;
	end
	else begin
		if(state_reg == READY && ready_en_reg)
			ready_reg <= 1;
		else 
			ready_reg <= 0;
	end
end

// /CS registers
always @(posedge clk) begin
	if (rst) begin
		spi_sdcard_csn_reg <= 1;
		spi_flash_csn_reg <= 1;
		spi_lcd_csn_reg <= 1;
	end
	else case(cs_reg)
		3'b100: begin
			spi_sdcard_csn_reg <= 0;
			spi_flash_csn_reg <= 1;
			spi_lcd_csn_reg <= 1;
		end
		3'b010: begin
			spi_sdcard_csn_reg <= 1;
			spi_flash_csn_reg <= 0;
			spi_lcd_csn_reg <= 1;
		end
		3'b001: begin
			spi_sdcard_csn_reg <= 1;
			spi_flash_csn_reg <= 1;
			spi_lcd_csn_reg <= 0;
		end
		default: begin
			spi_sdcard_csn_reg <= 1;
			spi_flash_csn_reg <= 1;
			spi_lcd_csn_reg <= 1;
		end
	endcase
end

endmodule


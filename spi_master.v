`uselib lib=unisims_ver
`uselib lib=proc_common_v3_00_a

module user_logic #(
	//Az IPIF interfészhez tartozó paraméterek.
	parameter C_NUM_REG                      = 3,		//Az IPIF által dekódolt 32 bites regiszterek száma.
	parameter C_SLV_DWIDTH                   = 32		//Az adatbusz szélessége bitekben.
   
	//Itt kell megadni a többi saját paramétert.
) (
	//Az IPIF interfészhez tartozó portok. Ha a Create or Import Peripheral
	//Wizard-ban nem jelöltük be a memória interfészhez tartozó Bus2IP_Addr,
	//Bus2IP_CS és Bus2IP_RNW jelek hozzáadását, akkor ezeket innen töröljük.
	input  wire                      Bus2IP_Clk,			//Órajel.
	input  wire                      Bus2IP_Resetn,		//Aktív alacsony reset jel.
//	input  wire [31:0]               Bus2IP_Addr,		//Címbusz.
//	input  wire [0:0]                Bus2IP_CS,			//A periféria címtartományának elérését jelző jel.
//	input  wire                      Bus2IP_RNW,			//A művelet típusát (0: írás, 1: olvasás) jelző jel.
	input  wire [C_SLV_DWIDTH-1:0]   Bus2IP_Data,		//Írási adatbusz.
	input  wire [C_SLV_DWIDTH/8-1:0] Bus2IP_BE,			//Bájt engedélyező jelek (csak írás esetén érvényesek).
	input  wire [C_NUM_REG-1:0]      Bus2IP_RdCE,		//A regiszterek olvasás engedélyező jelei.
	input  wire [C_NUM_REG-1:0]      Bus2IP_WrCE,		//A regiszterek írás engedélyező jelei.
	output reg  [C_SLV_DWIDTH-1:0]   IP2Bus_Data,		//Olvasási adatbusz.
	output wire                      IP2Bus_RdAck,		//Az olvasási műveletek nyugtázó jele.
	output wire                      IP2Bus_WrAck,		//Az írási műveletek nyugtázó jele.
	output wire                      IP2Bus_Error,		//Hibajelzés.
   
   //Itt kell megadni a többi saját portot.

	inout							miso,
	output							mosi,
	output							sck,
	output							spi_sdcard_csn,
	output							spi_flash_csn,
	output							spi_lcd_csn
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
reg [7:0] data_in_reg, data_out_reg;
reg [3:0] sck_cntr;
reg [2:0] state_reg;
reg mosi_reg, miso_reg, sck_reg;
reg spi_sdcard_csn_reg, spi_flash_csn_reg, spi_lcd_csn_reg;


assign cpld_jtagen = 0;
assign cpld_rstn = Bus2IP_Resetn;
assign miso (mode_reg && ~spi_lcd_csn_reg) ? c_d_reg : 1'bz;

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
wire		data_in_reg_wr = Bus2IP_WrCE[2] & (Bus2IP_BE == 4'b0001);

always @(posedge clk)
begin
	if (rst == 0)
		data_in_reg <= 8'd0;
	else if (data_in_reg_wr)
		data_in_reg <= Bus2IP_Data[7:0];
end

//******************************************************************************
//* Conversion START register (BASE+0x01, 1bit, RW).                                       *
//******************************************************************************
reg			start_reg;
wire		start_reg_wr = Bus2IP_WrCE[2] & (Bus2IP_BE == 4'b0010);

always @(posedge clk)
begin
	if (rst == 0)
		start_reg <= 1'd0;
	else if (start_reg_wr)
		start_reg <= Bus2IP_Data[8];
end

//******************************************************************************
//* CS and LCD MODE register (BASE+0x02, 1 + 3 bit, RW).                                       *
//******************************************************************************
reg [2:0]	cs_reg;
reg 		mode_reg;
wire		cs_reg_wr = Bus2IP_WrCE[2] & (Bus2IP_BE == 4'b0100);

always @(posedge clk)
begin
	if (rst == 0) begin
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
wire		c_d_reg_wr = Bus2IP_WrCE[2] & (Bus2IP_BE == 4'b1000);

always @(posedge clk)
begin
	if (rst == 0)
		c_d_reg <= 1'd0;
	else if (c_d_reg_wr)
		c_d_reg <= Bus2IP_Data[24];
end

//******************************************************************************
//* Interrupt register (BASE+0x0B, 1 bit, RW).                                       *
//******************************************************************************
reg			ready_reg, ready_en_reg;
wire		ready_reg_wr = Bus2IP_WrCE[0] & (Bus2IP_BE == 4'b1000);

always @(posedge clk)
begin
	if (rst == 0) begin
		ready_en_reg <= 1'd0;
	end
	else if (ready_reg_wr) begin
		ready_en_reg <= Bus2IP_Data[24];
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
		3'b10: IP2Bus_Data <= {7'd0, c_d_reg, 4'd0, mode_reg, cs_reg, 7'd0, start_reg, data_in_reg};
		3'b10: IP2Bus_Data <= {23'd0, busy, data_out_reg};
		3'b01: IP2Bus_Data <= {ready_en_reg, 22'd0, ready_reg};
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
		start_reg <= 0;
	end
	else begin
		case(state_reg)
			IDLE: begin
				if(start_reg == 1) begin
					state_reg <= START;
					start_reg <= 0;
				end
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
		data_in_reg <= 0;
	else if((state_reg == TRANSFER) && (clk_cntr == CLK_DIV_VAL))
		data_in_reg <= {data_in_reg[6:0], miso_reg};
end

//data_out register
always @(posedge clk) begin
	if(rst)
		data_out_reg <= 0;
	else if(state_reg == READY)
		data_out_reg <= data_in_reg;
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
		mosi_reg <= data_in_reg[7];
	else
		mosi_reg <= 0;
end	

//MISO reg
always @(posedge clk) begin
	if(rst)
		miso_reg <= 0;
	else if((state_reg == TRANSFER) && (clk_cntr == CLK_DIV_VAL_HALF))
		miso_reg <= miso;
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

// /CS registers
always @(posedge clk) begin
	if (rst) begin
		spi_sdcard_csn_reg <= 0;
		spi_flash_csn_reg <= 0;
		spi_lcd_csn_reg <= 0;
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


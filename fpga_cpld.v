`uselib lib=unisims_ver
`uselib lib=proc_common_v3_00_a

module user_logic #(
   //Az IPIF interfészhez tartozó paraméterek.
   parameter C_NUM_REG                      = 2,		//Az IPIF által dekódolt 32 bites regiszterek száma.
   parameter C_SLV_DWIDTH                   = 32		//Az adatbusz szélessége bitekben.
   
   //Itt kell megadni a többi saját paramétert.
) (
   //Az IPIF interfészhez tartozó portok. Ha a Create or Import Peripheral
   //Wizard-ban nem jelöltük be a memória interfészhez tartozó Bus2IP_Addr,
   //Bus2IP_CS és Bus2IP_RNW jelek hozzáadását, akkor ezeket innen töröljük.
   input  wire                      Bus2IP_Clk,			//Órajel.
   input  wire                      Bus2IP_Resetn,		//Aktív alacsony reset jel.
//   input  wire [31:0]               Bus2IP_Addr,		//Címbusz.
//   input  wire [0:0]                Bus2IP_CS,			//A periféria címtartományának elérését jelzõ jel.
//   input  wire                      Bus2IP_RNW,			//A mûvelet típusát (0: írás, 1: olvasás) jelzõ jel.
   input  wire [C_SLV_DWIDTH-1:0]   Bus2IP_Data,		//Írási adatbusz.
   input  wire [C_SLV_DWIDTH/8-1:0] Bus2IP_BE,			//Bájt engedélyezõ jelek (csak írás esetén érvényesek).
   input  wire [C_NUM_REG-1:0]      Bus2IP_RdCE,		//A regiszterek olvasás engedélyezõ jelei.
   input  wire [C_NUM_REG-1:0]      Bus2IP_WrCE,		//A regiszterek írás engedélyezõ jelei.
   output reg [C_SLV_DWIDTH-1:0]   IP2Bus_Data,		//Olvasási adatbusz.
   output wire                      IP2Bus_RdAck,		//Az olvasási mûveletek nyugtázó jele.
   output wire                      IP2Bus_WrAck,		//Az írási mûveletek nyugtázó jele.
   output wire                      IP2Bus_Error,		//Hibajelzés.
   
   //Itt kell megadni a többi saját portot.

   output  cpld_jtagen,
   output  cpld_rstn,
   output reg  cpld_clk,
   output reg  cpld_ld,
   output reg  cpld_mosi,
   input       cpld_miso
);

//
wire clk = Bus2IP_Clk;
wire rst = ~Bus2IP_Resetn;
wire [3:0] seg_mux;

reg [15:0] shiftreg, shiftreg_2;
reg [11:0] szamlalo_12;
reg [7:0] seg_data, sw_reg;
reg [4:0] szamlalo_5, nav_sw_reg;
reg eldetektalo, ce;


assign cpld_jtagen = 0;
assign cpld_rstn = Bus2IP_Resetn;

//******************************************************************************
//* LED register (BASE+0x00, 8 bit, RW).                                       *
//******************************************************************************
reg  [7:0] led_reg;
wire       led_reg_wr = Bus2IP_WrCE[1] & (Bus2IP_BE == 4'b0001);

always @(posedge clk)
begin
   if (rst == 0)
      led_reg <= 8'd0;
   else
      if (led_reg_wr)
         led_reg <= Bus2IP_Data[7:0];
end

//******************************************************************************
//* 7SEG register (BASE+0x01, 8 bit, RW).                                       *
//******************************************************************************
reg  [3:0] seg0, seg1;
wire       seg_reg_wr = Bus2IP_WrCE[1] & (Bus2IP_BE == 4'b0010);

always @(posedge clk)
begin
   if (rst == 0) begin
      seg0 <= 4'd0;
      seg1 <= 4'd0;
	end
   else if (seg_reg_wr) begin
			seg0 <= Bus2IP_Data[11:8];
			seg1 <= Bus2IP_Data[15:12];
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
      2'b10: IP2Bus_Data <= {16'd0, seg0, seg1, led_reg};
      2'b01: IP2Bus_Data <= {19'd0, nav_sw_reg, sw_reg};
      default: IP2Bus_Data <= 32'd0;
   endcase
end

	
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
	if((eldetektalo == 1 && szamlalo_12[11] == 0)||(eldetektalo == 0 && szamlalo_12[11] == 1))
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
	sw_reg <= 0;
	nav_sw_reg <= 0;
	shiftreg <= 0;
	shiftreg_2 <= 0;
	end
else if(ce && ~eldetektalo)
	begin
		if(szamlalo_5[3:0] == 15) begin
			shiftreg <= {~seg_data,led};
			sw_reg <= shiftreg_2[7:0];
			nav_sw_reg <= shiftreg_2[12:8];
		end
		else begin
			shiftreg <= {1'b0,shiftreg[15:1]};
		end
		shiftreg_2 <= {cpld_miso,shiftreg_2[15:1]};
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

endmodule


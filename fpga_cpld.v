`uselib lib=unisims_ver
`uselib lib=proc_common_v3_00_a

module user_logic #(
   //Az IPIF interf�szhez tartoz� param�terek.
   parameter C_NUM_REG                      = 2,		//Az IPIF �ltal dek�dolt 32 bites regiszterek sz�ma.
   parameter C_SLV_DWIDTH                   = 32		//Az adatbusz sz�less�ge bitekben.
   
   //Itt kell megadni a t�bbi saj�t param�tert.
) (
   //Az IPIF interf�szhez tartoz� portok. Ha a Create or Import Peripheral
   //Wizard-ban nem jel�lt�k be a mem�ria interf�szhez tartoz� Bus2IP_Addr,
   //Bus2IP_CS �s Bus2IP_RNW jelek hozz�ad�s�t, akkor ezeket innen t�r�lj�k.
   input  wire                      Bus2IP_Clk,			//�rajel.
   input  wire                      Bus2IP_Resetn,		//Akt�v alacsony reset jel.
//   input  wire [31:0]               Bus2IP_Addr,		//C�mbusz.
//   input  wire [0:0]                Bus2IP_CS,			//A perif�ria c�mtartom�ny�nak el�r�s�t jelz� jel.
//   input  wire                      Bus2IP_RNW,			//A m�velet t�pus�t (0: �r�s, 1: olvas�s) jelz� jel.
   input  wire [C_SLV_DWIDTH-1:0]   Bus2IP_Data,		//�r�si adatbusz.
   input  wire [C_SLV_DWIDTH/8-1:0] Bus2IP_BE,			//B�jt enged�lyez� jelek (csak �r�s eset�n �rv�nyesek).
   input  wire [C_NUM_REG-1:0]      Bus2IP_RdCE,		//A regiszterek olvas�s enged�lyez� jelei.
   input  wire [C_NUM_REG-1:0]      Bus2IP_WrCE,		//A regiszterek �r�s enged�lyez� jelei.
   output reg [C_SLV_DWIDTH-1:0]   IP2Bus_Data,		//Olvas�si adatbusz.
   output wire                      IP2Bus_RdAck,		//Az olvas�si m�veletek nyugt�z� jele.
   output wire                      IP2Bus_WrAck,		//Az �r�si m�veletek nyugt�z� jele.
   output wire                      IP2Bus_Error,		//Hibajelz�s.
   
   //Itt kell megadni a t�bbi saj�t portot.

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

	
//12 bites sz�ml�l�
always @(posedge clk)
begin
if(rst)
	szamlalo_12 <= 0;
else
	szamlalo_12 <= szamlalo_12 + 1;
end

//�ldetekt�l�
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

//5 bites sz�ml�l�
always @(posedge clk)
begin
if(rst)
	szamlalo_5 <= 0;
else
	if(ce)
		szamlalo_5 <= szamlalo_5 +1;
end

//H�tszegmenses kijelzo multiplexer

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

//Kimenet �ll�t�s
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


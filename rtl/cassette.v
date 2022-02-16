
module cassette(
  input         clk,

  input         ioctl_download,
  input         ioctl_wr,
  input [24:0]  ioctl_addr,
  input [7:0]   ioctl_dout,

  output reg [15:0]  tape_addr,
  output reg         tape_wr,
  output reg [7:0]   tape_dout
);

// State machine constants
localparam SM_INIT	         =  0;
localparam SM_FIRSTQUOTE	 =  1;
localparam SM_FILETYPE       =  2;
localparam SM_PROGRAMLO      =  3;
localparam SM_PROGRAMHI      =  4;
localparam SM_LOADPOINTLO    =  5;
localparam SM_LOADPOINTHI    =  6;

localparam SM_EXECPOINTLO    =  7;
localparam SM_EXECPOINTHI    =  8;

localparam SM_PROGRAMCODE    =  9;
localparam SM_CHECKDIGIT     = 10;
localparam SM_MYSTERYBYTE    = 11;

// TAP
reg	[7:0]	fileType;           // 'h42 == "B"
reg	[15:0]	programLength;
reg	[15:0]	loadPoint;
reg	[15:0]	execPoint;
reg	[7:0]	checkDigit;
reg	[7:0]	mysteryByte;

reg [15:0]  state = SM_INIT;

always @(posedge clk) 
    begin
        if (ioctl_download && ioctl_wr)
        begin

            case (state)
                SM_INIT:
                if(ioctl_dout == 'h22)
                begin
                    state <= SM_FIRSTQUOTE;

                    // Bankswitch to write 1
                    tape_wr <= 'b1;
					tape_addr <= 'hFFFF; 						  
                    tape_dout <= 'b00000;
                end

                SM_FIRSTQUOTE:
                if(ioctl_dout == 'h22)
                    state <= SM_FILETYPE;

                SM_FILETYPE:
                begin
                    fileType <= ioctl_dout;
                    state <= SM_PROGRAMLO;
                end

                SM_PROGRAMLO:
                begin
                    programLength[7:0] <= ioctl_dout;
                    state <= SM_PROGRAMHI;
                end

                SM_PROGRAMHI:
                begin
                    programLength[15:8] <= ioctl_dout;
                    state <= SM_LOADPOINTLO;
                end

                SM_LOADPOINTLO:
                begin
                    loadPoint[7:0] <= 'h4c ; //ioctl_dout;
                    state <= SM_LOADPOINTHI;
                end

                SM_LOADPOINTHI:
                begin
                    loadPoint[15:8] <= 'h69; // ioctl_dout;
                    state <= SM_EXECPOINTLO;                    
                end

                SM_EXECPOINTLO:
                begin
                    execPoint[7:0] <= ioctl_dout;                       
                    state <= SM_EXECPOINTHI;      
                end

                SM_EXECPOINTHI:
                begin
                    execPoint[15:8] <= ioctl_dout;   
                    programLength <= programLength - 2;                 
                    state <= SM_PROGRAMCODE;    
                end

                SM_PROGRAMCODE:
                begin
                    // Load into ram ....
                    tape_wr <= 'b1;
					tape_addr <= loadPoint; 						  
                    tape_dout <= ioctl_dout;

                    programLength <= programLength - 1;			  
                    loadPoint <= loadPoint + 1;

                    if(programLength == 'h2)
					begin
                        state <= SM_CHECKDIGIT;  
                        
                        // Bankswitch to read 1
					    tape_addr <= 'hFFFF; 						  
                        tape_dout <= 'b100000;
                    end
                end

                SM_CHECKDIGIT:
                begin
                    checkDigit <= ioctl_dout;                    
                    state <= SM_MYSTERYBYTE;      
                end

                SM_MYSTERYBYTE:
                begin
                    mysteryByte <= ioctl_dout;  
					tape_wr <= 'b0;                     
                end
            endcase
/*
            $display( "(state %x) (pl %x) (ft %x) (lp %x) (ep %x) (cd %x) (mb %x) %x: %x", 
                        state, programLength, 
                        fileType, loadPoint, execPoint, checkDigit, mysteryByte,
                        ioctl_addr, ioctl_dout);
*/
        end
	end

endmodule

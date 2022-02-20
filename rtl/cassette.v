
module cassette(
  input              clk,

  input              ioctl_download,
  input              ioctl_wr,
  input      [24:0]  ioctl_addr,
  input      [7:0]   ioctl_dout,

  output reg [15:0]  tape_addr,
  output reg         tape_wr,
  output reg [7:0]   tape_dout,
  output reg         tape_complete
);

// State machine constants
localparam SM_INIT	         =  0;
localparam SM_SECONDQUOTE	 =  1;
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
localparam SM_COMPLETED      = 12;
localparam SM_WAITCYCLE      = 13;

// TAP
reg	[7:0]	fileType;           // 'h42 == "B", 'h4D == "M", 'h44 == "D"
reg	[15:0]	programLength;
reg	[15:0]	loadPoint = 'h694d;
reg	[15:0]	execPoint;
reg	[7:0]	checkDigit;
reg	[7:0]	mysteryByte;

reg         waitcycle       = 1;
reg [15:0]  previous_state  = 0;

reg [15:0]  state = SM_INIT;

always @(posedge clk) 
    begin
        if (ioctl_download && ioctl_wr)
        begin

            case (state)
                SM_WAITCYCLE:
                begin
                    $display( "(state %x) waitcycle: %c",state,waitcycle);
                    waitcycle <= waitcycle - 1;
                    if(waitcycle=='h0)
                        state <= previous_state;
                end

                SM_INIT:
                if(ioctl_dout=='h22)
                begin
                    tape_complete <= 1'b0;                    
		            loadPoint <= 'h694d;
                    previous_state <= state;
                    state <= SM_SECONDQUOTE;

                    // Switch to write bank1
                    //tape_wr <= 'b1;
		            //tape_addr <= 'hFFFF; 						  
                    //tape_dout <= 'b00000;
                end

                SM_SECONDQUOTE:
		        begin
                    if(ioctl_dout=='h22)
                    begin
                        previous_state <= state;
                        state <= SM_FILETYPE;
                    end

                    $display( "(state %x) quote: %c",state,ioctl_dout);
		        end

                SM_FILETYPE:
                begin
                    $display( "(state %x) filetype: %c",state,ioctl_dout);
                    fileType <= ioctl_dout;

		            if (ioctl_dout!='hA5)   // A5 is to be ignored
                        state <= SM_PROGRAMLO;
                        /*
                        begin
                            waitcycle <= 'h1;
                            previous_state <= state;
                            state <= SM_WAITCYCLE;
                        end
                    else
                        begin
                            previous_state <= state;
                            state <= SM_PROGRAMLO;
                        end*/
                end

                SM_PROGRAMLO:
                begin
                    programLength[7:0] <= ioctl_dout;
                    previous_state <= state;
                    state <= SM_PROGRAMHI;
                end

                SM_PROGRAMHI:
                begin
                    programLength[15:8] <= ioctl_dout;
                    previous_state <= state;
                    state <= SM_LOADPOINTLO;

		            if (fileType=='h42)             // Basic
                    begin
                        previous_state <= state;
                    	state <= SM_PROGRAMCODE;  
                    end
		            else if (fileType=='h4D)        // Machine Code
                    begin
                        previous_state <= state;
                    	state <= SM_LOADPOINTLO; 
                    end
		            else if (fileType=='h44)        // Data
                    begin
                        // LoadPoint and ExecPoint must be read in, and switched with one another
                        previous_state <= state;
                    	state <= SM_PROGRAMCODE;   
                    end
		            else if (fileType=='h41)        // Level 9 Computing
                    begin
                        previous_state <= state;
                    	state <= SM_PROGRAMCODE;   
                    end
                end

                SM_LOADPOINTLO:
                begin
                    loadPoint[7:0] <= 'h4d ; //ioctl_dout;
                    previous_state <= state;
                    state <= SM_LOADPOINTHI;
                end

                SM_LOADPOINTHI:
                begin
                    loadPoint[15:8] <= 'h69; // ioctl_dout;
                    previous_state <= state;
                    state <= SM_EXECPOINTLO; 

		            if (fileType=='h4D || fileType=='h44)  // Machine Code, Data
                    begin
                        previous_state <= state;
                    	state <= SM_PROGRAMCODE; 
                    end
                end

                SM_EXECPOINTLO:
                begin
                    execPoint[7:0] <= ioctl_dout;    
                    previous_state <= state;                   
                    state <= SM_EXECPOINTHI;      
                end

                SM_EXECPOINTHI:
                begin
                    execPoint[15:8] <= ioctl_dout;   
                    programLength <= programLength - 2;  
                    previous_state <= state;               
                    state <= SM_PROGRAMCODE;    
                end

                SM_PROGRAMCODE:
                begin
                    // Load into bram ....
                    tape_wr <= 'b1;
		            tape_addr <= loadPoint; 						  
                    tape_dout <= ioctl_dout;

                    programLength <= programLength - 1;			  
                    loadPoint <= loadPoint + 1;

                    if(programLength=='h1 && fileType!='h42) // 'h2
					begin
                        previous_state <= state;
                        state <= SM_CHECKDIGIT;  
		    	        tape_wr <= 'b0;                     
                        
                        // Switch to read bank1
			            //tape_addr <= 'hFFFF; 						  
                        //tape_dout <= 'b100000;
                    end
                    else if (programLength=='h0 && fileType=='h42)
                    begin
                        previous_state <= state;               
                        state <= SM_COMPLETED; 
                    end

                end

                SM_CHECKDIGIT:
                begin
                    checkDigit <= ioctl_dout;     
                    previous_state <= state;               
                    state <= SM_MYSTERYBYTE;      
                end

                SM_MYSTERYBYTE:
                begin
                    mysteryByte <= ioctl_dout;  
                    previous_state <= state;     
                    state <= SM_COMPLETED; 
                end

                SM_COMPLETED:
                begin
                    tape_complete <= 1'b1;
		            tape_wr <= 'b0;  
                end

            endcase

            $display( "(state %x) (pl %x) (ft %x) (lp %x) (ep %x) (cd %x) (mb %x) (tc %x) %x: %x", 
                        state, programLength, 
                        fileType, loadPoint, execPoint, checkDigit, mysteryByte, tape_complete,
                        ioctl_addr, ioctl_dout);

        end
	end

endmodule
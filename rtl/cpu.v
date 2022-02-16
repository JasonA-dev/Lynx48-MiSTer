//-------------------------------------------------------------------------------------------------
module cpu
//-------------------------------------------------------------------------------------------------
(
	input  wire       reset,
	input  wire       clock,
	input  wire       cep,
	input  wire       cen,
	input  wire       int_n,
	output wire       halt_n,
	output wire       mreq,
	output wire       iorq,
	output wire       wr,
	input  wire[ 7:0] di,
	output wire[ 7:0] do,
	output wire[15:0] a    
);

T80pa Cpu
(
	.CLK    (clock),
	.CEN_p  (cep  ),
	.CEN_n  (cen  ),
	.RESET_n(reset),
	.BUSRQ_n(1'b1 ),
	.WAIT_n (1'b1 ),
	.BUSAK_n(     ),
	.HALT_n (     ),
	.RFSH_n (     ),
	.MREQ_n (mreq ),
	.IORQ_n (iorq ),
	.NMI_n  (1'b1 ),
	.INT_n  (int_n),
	.M1_n   (     ),
	.RD_n   (     ),
	.WR_n   (wr   ),
	.A      (a    ),
	.DI     (di   ),
	.DO     (do   ),
	.OUT0   (1'b0 ),
	.REG    (     ),
	.DIRSet (1'b0 ),
	.DIR    (212'd0)
);

//-------------------------------------------------------------------------------------------------
endmodule
//-------------------------------------------------------------------------------------------------

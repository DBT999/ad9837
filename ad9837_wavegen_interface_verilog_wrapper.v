`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 01/14/2025 10:28:01 AM
// Design Name: 
// Module Name: ad9837_wavegen_interface_verilog_wrapper
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module ad9837_wavegen_interface_verilog_wrapper #(
    parameter   SYS_CLK_FREQ = 50_000_000,	  // DBT: Can be w/e
    parameter   SPI_CLK_FREQ = 40_000_000,    //max frequency for this chip is 40 MHz. DBT: Should be 10
    parameter   MCLK_FREQ    = 5_000_000    
    ) (
    input                   clk_i,
    input                   rst_i,
    
    input                   init_i,    

    output                  ready_o,        //signify if waveform generator is ready to go and sending out signal
    
    output                  fsync_o,    
    output                  sclk_o,
    output                  sdata_o

    );
    
    
    
    
    ad9837_wavegen_interface #(.SYS_CLK_FREQ(SYS_CLK_FREQ), .SPI_CLK_FREQ(SPI_CLK_FREQ), .MCLK_FREQ(MCLK_FREQ) ) wavegen_interface(
        .clk_i          (   clk_i           ),
        .rst_i          (   rst_i           ),
        .init_i         (   init_i          ),
        .ready_o        (   ready_o         ),
        .fsync_o        (   fsync_o         ),
        .sclk_o         (   sclk_o          ),
        .sdata_o        (   sdata_o         )
    );  
    
    
    
endmodule

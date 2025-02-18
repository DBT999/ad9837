`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 09/13/2024 01:09:03 PM
// Design Name: 
// Module Name: ad9837_wavegen_interface
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


module ad9837_wavegen_interface #(
    parameter   SYS_CLK_FREQ = 50_000_000,
    parameter   SPI_CLK_FREQ = 40_000_000,    //max frequency for this chip is 40 MHz
    parameter   MCLK_FREQ    = 5_000_000    )
    (
    
    input               clk_i,
    input               rst_i,
    
    input               init_i,    

    output              ready_o,        //signify if waveform generator is ready to go and sending out signal
    
    output              fsync_o,    
    output              sclk_o,
    output              sdata_o

    );
    
    localparam                                  WAVEFREQ    = 250_000;
    localparam enum {Sine, Triange, Square}     WAVETYPE    = Sine; //default wave type
    localparam                                  WAVEPHASE   = 0;
    localparam logic [27:0]                     FREQREG     = $rtoi( $itor(WAVEFREQ) / $itor(MCLK_FREQ) * 2**28); //value to be loaded in the the frequency register to generate the final frequency
    localparam logic [11:0]                     PHASEREG    = $rtoi( $itor(WAVEPHASE * 4096) / (2.0 * 3.1415926) ); //value to be loaded into phase register
    
    
    /////////SPI Clock Generation//////////////////
    
    localparam                                  CLK_DIV     = $rtoi($ceil($itor(SYS_CLK_FREQ / SPI_CLK_FREQ) / 2));//set clock divider with requested SPI frequency, rounding up to integer clock division
    localparam                                  ACTUAL_F    = SYS_CLK_FREQ / (CLK_DIV*2);  //the actual frequency output after the division
    localparam                                  HALF_PERIOD = 1e9 / ACTUAL_F / 2; //number of nanoseconds for half period of SPI_CLK
    localparam                                  SYS_PERIOD  = 1e9 / SYS_CLK_FREQ; //number of nanoseconds for SYS_CLK period
    localparam                                  WAIT_TIME   = HALF_PERIOD >= 10 ? 0 : 10 / SYS_PERIOD; //how many system cycles after the negedge of SCLK to wait before raising latch to comply with the t_8 requirement from page 4, 10ns  
    localparam                                  CLK_CNT_SIZE = WAIT_TIME > CLK_DIV ? WAIT_TIME : CLK_DIV;
    
    logic [$clog2(CLK_CNT_SIZE)-1:0]            clk_div_cnt;

    logic clk_div;
    logic latch;
     
    always_ff @(posedge clk_i)
        if(latch)                                                               clk_div_cnt <= '0;
        else if(bit_cnt < NUM_CMDS*16 && clk_div_cnt == CLK_DIV - 1'b1)         clk_div_cnt <= '0;
        else                                                                    clk_div_cnt <= clk_div_cnt + 1'b1;
    always_ff @(posedge clk_i)
        if(latch)                                                               clk_div <= 1;   //clock must idle high 
        else if(bit_cnt < NUM_CMDS*16 && clk_div_cnt == CLK_DIV - 1'b1)         clk_div <= !clk_div;
    
    assign sclk_o = latch || clk_div;  //must idle high
    assign fsync_o = latch;   
    logic sclk_pos, sclk_neg; //edges of sclk
    
    always_ff @(posedge clk_i)
        if(clk_div_cnt == CLK_DIV - 1'b1) begin
            if(clk_div)                     sclk_neg <= 1'b1;  //when clock is about to change, if the current clock is high, that means a negative edge
            else                            sclk_pos <= 1'b1;  //same for positive edge
        end
        else begin
                                            sclk_neg <= 1'b0;
                                            sclk_pos <= 1'b0;
        end

    /////////////////Register values/commands ///////////////////////////
    
    localparam          CTRL_REG_RESET      = 16'b0010_0001_0000_0000;  //packet to send to reset the control register and put the device in reset state, leading 00 indicates its a control register write, this is governed 
                                                                                    //by bit 8 of the register, other values are chosen based on desired initialization state
                                                                                    //these need to be updated if waveform other than SINE is desired
    localparam          CTRL_REG_ENABLE     = 16'b0010_0000_0000_0000;  //packet to send to remove device from reset state and have output active
    localparam          FREQ0_REG_UPPER     = {2'b01, FREQREG[27:14]};  //upper bits of frequency zero register
    localparam          FREQ0_REG_LOWER     = {2'b01, FREQREG[13:0]};  // lower bits of frequency zero register
    localparam          PHAS0_REG           = {4'b1100, PHASEREG};
    
    localparam                      NUM_CMDS = 5;
    localparam logic [16*NUM_CMDS-1:0]   INIT_CMDS = {  CTRL_REG_RESET,
                                                        FREQ0_REG_LOWER,
                                                        FREQ0_REG_UPPER,
                                                        PHAS0_REG,
                                                        CTRL_REG_ENABLE };   //full length of bits to send during initialization 
    logic [$clog2(NUM_CMDS*16):0]   bit_cnt;
    logic [16*NUM_CMDS-1:0]         cmd_list;           
    
    assign sdata_o = cmd_list[16*NUM_CMDS-1];                                      
                                                             
    typedef enum
        {   Idle,
            Shift,
            Done   }   state_e;
    (* fsm_encoding ="auto" *)  state_e state, next; //options are one_hot, sequential, johnson, gray, none and auto
    
    //////// state transitions /////////////
    always_comb
        case(state)
            Idle:       if(init_i)                                                  next = Shift;
                        else                                                        next = Idle;
            Shift:      if(bit_cnt >= NUM_CMDS*16 &&  clk_div)                      next = Done;
                        else                                                        next = Shift;
            Done:                                                                   next = Done;        
            default:                                                                next = Idle;
        endcase 
    
    assign latch = !(state == Shift);
    assign ready_o = state == Done; //once the chip is initialized, its ready to go and other systems can consider it valid and sending out the waveform 
    
    always_ff @(posedge clk_i)
        if(init_i && state == Idle) begin
            cmd_list    <= INIT_CMDS;
            bit_cnt     <= '0;
        end
        else if(sclk_pos && state == Shift && bit_cnt != NUM_CMDS*16) begin
            cmd_list    <= cmd_list << 1;
            bit_cnt     <= bit_cnt + 1'b1;
        end
         
    
    
    always_ff @(posedge clk_i)
        if(rst_i)   state <= Idle;
        else        state <= next;      
    
endmodule

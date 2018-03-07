`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 07.03.2018 11:47:33
// Design Name: 
// Module Name: AXI_APB_Bridge
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


module AXI_APB_Bridge(
    
    //AXI interface signals
     ACLK,
     ARESET,
    
     ARADDR,
     ARVALID,
     ARREADY,
     ARSIZE,
     ARBURST,
     ARLEN,
     
     AWADDR,
     AWVALID,
     AWREADY,
     AWSIZE,
     AWBURST,
     AWLEN,
     
     RDATA,
     RVALID,
     RRESP,
     RREADY,
     
     WDATA,
     WVALID,
     WSTRB,
     WREADY,
     
     BRESP,
     BVALID,
     BREADY,
     
     //APB interface signals
     
     PCLK,
     PRESET,
     PADDR,
     PSEL,
     
     PENABLE,
     PWRITE,
     PWDATA,
     PWSTRB,
     PREADY,
     PRDATA,
     PSLVERR

    );
    
    parameter MAX_TRANSFER_WIDTH=2;
        
    //AXI interface signals
     
     input ACLK;
     input ARESET;
        
     input[31:0] ARADDR;
     input ARVALID;
     input[1:0] ARSIZE;
     input[1:0] ARBURST;
     input[MAX_TRANSFER_WIDTH-1:0] ARLEN;
     output reg ARREADY;
     
     input[31:0] AWADDR;
     input AWVALID;
     input[1:0] AWSIZE;
     input[1:0] AWBURST;
     input[1:0] AWLEN;
     output reg AWREADY;
     
     output reg[31:0] RDATA;
     output reg RVALID;
     output reg[1:0] RRESP;
     input RREADY;
     
     input[31:0] WDATA;
     input WVALID;
     input[3:0] WSTRB;
     output reg WREADY;
     
     output reg[1:0] BRESP;
     output reg BVALID;
     input BREADY;
     
     //APB interface signals
     
     output reg PCLK;
     output reg PRESET;
     output reg[31:0] PADDR;
     output reg PSEL;
     
     output reg PENABLE;
     output reg PWRITE;
     output reg[31:0] PWDATA;
     output reg[3:0] PWSTRB;
     input PREADY;
     input[31:0] PRDATA;
     input PSLVERR;
     
     
     //state registers
     reg[3:0] present_state;
     reg[3:0] next_state;
     
     //sampled address and datas
     reg[31:0] sampled_address;
     reg[1:0] sampled_wlen;
     reg[1:0] sampled_rlen;
     
     reg[1:0] sampled_rsize;
     reg[1:0] sampled_wsize;
     
     reg[1:0] sampled_rburst;
     reg[1:0] sampled_wburst;
     
     reg[3:0] sampled_wstrb;
     
     reg[31:0] sampled_wdata;
     
     
     
     
     //initially handle writes
     
     parameter IDLE_STATE=4'b0000;//ARREADY=1 and AWREADY=1
     parameter WRITE_ADDRESS_RECEIVED_STATE=4'b0001;//ARREADY=0 and AWREADY=0, WREADY=1 if it's a write
     parameter WRITE_DATA_RECEIVED_STATE=4'b0010;//WREADY=0,PSEL=1,PWRITE=1
     parameter PENABLE_SIGNAL=4'b0011;//PENABLE=1,WREADY=0
     parameter DATA_TRANSFERRED_STATE=4'b0100;//PENABLE=0 and WREADY=1
     parameter TRANSFER_COMPLETE_STATE=4'b0101;//BVALID=1, once BREADY=1 go to idle
     parameter READ_ADDRESS_RECEIVED_STATE=4'B0110;//ARREADY=0 and AWREADY=0
     parameter PENABLE_READ_SIGNAL=4'b0111;//PENABLE=1'b1
     parameter READ_DATA_TRANSFERRED_STATE=4'b1000;//PENABLE=1'b0
    
    //if you want to reset the device it's the same for AXI and APB
    always@(*)
    begin
        PRESET=ARESET;
    end
    
    always@(*)
    begin
        PWSTRB=WSTRB;
    end
    
    
    /*
        state transition on a clock edge
    */
    
    always@(posedge ACLK or posedge ARESET)
    begin
        if(!ARESET)
        begin
            present_state<=IDLE_STATE;
        end
        else
        begin
            present_state<=next_state;
        end
    end
    
    /*
        next state logic
    */
    always@(*)//ideally it shouldn't be (*) but it should be (present_state and inputs)
    begin
        next_state=IDLE_STATE;
        case(present_state)
            IDLE_STATE:
            begin
                next_state=IDLE_STATE;
                if(ARVALID==1'b1 && AWVALID==1'b0)
                begin
                    next_state=READ_ADDRESS_RECEIVED_STATE;
                end
                else if(ARVALID==1'b0 && AWVALID==1'b1)
                begin
                    next_state=WRITE_ADDRESS_RECEIVED_STATE;
                end
                else if(ARVALID==1'b1 && AWVALID==1'b1)
                begin
                    next_state=READ_ADDRESS_RECEIVED_STATE;
                end
                else
                begin
                    next_state=IDLE_STATE;
                end
            end
            WRITE_ADDRESS_RECEIVED_STATE://In this state WREADY=1
            begin
                next_state=WRITE_ADDRESS_RECEIVED_STATE;
                if(WVALID==0)
                begin
                    next_state=WRITE_ADDRESS_RECEIVED_STATE;
                end
                else
                begin
                    next_state=WRITE_DATA_RECEIVED_STATE;
                end
            end
            WRITE_DATA_RECEIVED_STATE:
            begin
                next_state=PENABLE_SIGNAL;
            end
            PENABLE_SIGNAL:
            begin
                next_state=PENABLE_SIGNAL;
                if(PREADY)
                begin
                    next_state=DATA_TRANSFERRED_STATE;
                end
                else
                begin
                    next_state=PENABLE_SIGNAL;
                end
            end
            DATA_TRANSFERRED_STATE:
            begin
                next_state=DATA_TRANSFERRED_STATE;
                if(sampled_wlen!=0 && WVALID==0)
                begin
                    next_state=DATA_TRANSFERRED_STATE;
                end
                else if(sampled_wlen!=0 && WVALID==1)
                begin
                    next_state=WRITE_DATA_RECEIVED_STATE;
                end
                else
                begin
                    next_state=TRANSFER_COMPLETE_STATE;
                end
            end
            TRANSFER_COMPLETE_STATE:
            begin
                next_state=TRANSFER_COMPLETE_STATE;
                if(BREADY==1)
                begin
                    next_state=IDLE_STATE;
                end
                else
                begin
                    next_state=TRANSFER_COMPLETE_STATE;
                end
                
            end
            READ_ADDRESS_RECEIVED_STATE://start set up phase here
            begin
                next_state=PENABLE_READ_SIGNAL;  
            end
            PENABLE_READ_SIGNAL:
            begin
                next_state=PENABLE_READ_SIGNAL;
                if(PREADY==1'b1)
                begin
                    next_state=READ_DATA_TRANSFERRED_STATE;
                end
                else
                begin
                    next_state=PENABLE_READ_SIGNAL;
                end
            end
            READ_DATA_TRANSFERRED_STATE:
            begin
                next_state=READ_DATA_TRANSFERRED_STATE;
                if(RREADY==1'b0)
                begin
                    next_state=READ_DATA_TRANSFERRED_STATE;
                end
                else if(RREADY==1'b1 && sampled_wlen!=0)
                begin
                    next_state=READ_ADDRESS_RECEIVED_STATE;
                end
                else
                begin
                    next_state= IDLE_STATE;
                end
            end
           
            
        endcase
        
    end
    /*
    
        state decoding
    */
   
    //state outputs
    always@(*)
    begin
           ARREADY=1'b0;
           AWREADY=1'b0;
           RVALID=1'b0;
           WREADY=1'b0;
           BVALID=1'b0;
           
           //APB outputs
           PSEL=1'b0;
           PENABLE=1'b0;
           PWRITE=1'b0;
        case(present_state)
            IDLE_STATE:
            begin
                ARREADY=1'b1;
                AWREADY=1'b1;
                RVALID=1'b0;
                WREADY=1'b0;
                BVALID=1'b0;
                
                //APB outputs
                PSEL=1'b0;
                PENABLE=1'b0;
                PWRITE=1'b0;
                
            end
            WRITE_ADDRESS_RECEIVED_STATE:
            begin
                ARREADY=1'b0;
                AWREADY=1'b0;
                RVALID=1'b0;
                WREADY=1'b1;
                BVALID=1'b0;
                
                //APB outputs
                PSEL=1'b0;
                PENABLE=1'b0;
                PWRITE=1'b0;
            end
            WRITE_DATA_RECEIVED_STATE:
            begin
                ARREADY=1'b0;
                AWREADY=1'b0;
                RVALID=1'b0;
                WREADY=1'b0;
                BVALID=1'b0;
                
                //APB outputs
                PSEL=1'b1;
                PENABLE=1'b0;
                PWRITE=1'b1;
            end
            PENABLE_SIGNAL:
            begin
                ARREADY=1'b0;
                AWREADY=1'b0;
                RVALID=1'b0;
                WREADY=1'b0;
                BVALID=1'b0;
                
                //APB outputs
                PSEL=1'b1;
                PENABLE=1'b1;
                PWRITE=1'b1;
            end
            DATA_TRANSFERRED_STATE:
            begin
                ARREADY=1'b0;
                AWREADY=1'b0;
                RVALID=1'b0;
                WREADY=1'b1;
                BVALID=1'b0;
                
                //APB outputs
                PSEL=1'b1;
                PENABLE=1'b0;
                PWRITE=1'b1;
            end
            TRANSFER_COMPLETE_STATE:
            begin
                ARREADY=1'b0;
                AWREADY=1'b0;
                RVALID=1'b0;
                WREADY=1'b0;
                BVALID=1'b1;
                
                //APB outputs
                PSEL=1'b0;
                PENABLE=1'b0;
                PWRITE=1'b0;
            end
            READ_ADDRESS_RECEIVED_STATE:
            begin
                ARREADY=1'b0;
                AWREADY=1'b0;
                RVALID=1'b0;
                WREADY=1'b0;
                BVALID=1'b0;
                
                //APB outputs
                PSEL=1'b1;
                PENABLE=1'b0;
                PWRITE=1'b0;
            end
            PENABLE_READ_SIGNAL:
            begin
                ARREADY=1'b0;
                AWREADY=1'b0;
                RVALID=1'b0;
                WREADY=1'b0;
                BVALID=1'b0;
                
                //APB outputs
                PSEL=1'b1;
                PENABLE=1'b1;
                PWRITE=1'b0;
            end
            READ_DATA_TRANSFERRED_STATE:
            begin
                ARREADY=1'b0;
                AWREADY=1'b0;
                RVALID=1'b1;
                WREADY=1'b0;
                BVALID=1'b0;
                
                //APB outputs
                PSEL=1'b0;
                PENABLE=1'b0;
                PWRITE=1'b0;
            end
        endcase
        
    end
    
    always@(*)
    begin
        PCLK=ACLK;
    end
    //address sample LOGIC
    always@(posedge ACLK)
    begin
        if(present_state==IDLE_STATE && ARVALID==1'b1)
        begin
            sampled_address<=ARADDR;
            //sampled_wlen<=ARLEN;
        end
        else if(present_state==IDLE_STATE && AWVALID==1'b1)
        begin
            sampled_address<=AWADDR;
            //sampled_wlen<=AWLEN;
        end
        else if((present_state==PENABLE_SIGNAL && PREADY==1'b1) || (present_state==PENABLE_READ_SIGNAL && PREADY==1'b1))//increment the address
        begin
            //unaligned transfers
            case(sampled_address%4)
                2'b00:
                begin
                    case(sampled_wsize)
                        2'b00://32 bits
                        begin
                            sampled_address<=sampled_address+4;        
                        end
                        2'b01://8 bits
                        begin
                            sampled_address<=sampled_address+1;
                        end
                        2'b10://16 bits
                        begin
                            sampled_address<=sampled_address+2;
                        end
                        2'b11://32 bits
                        begin
                            sampled_address<=sampled_address+4;
                        end
                    endcase
                    
                end
                2'b01:
                begin
                    case(sampled_wsize)
                        2'b00:
                        begin
                           sampled_address<=sampled_address+3;             
                        end
                        2'b01:
                        begin
                            sampled_address<=sampled_address+1;
                        end
                        2'b10:
                        begin
                            sampled_address<=sampled_address+2;
                        end
                        2'b11:
                        begin
                            sampled_address<=sampled_address+3;
                        end
                    endcase
                    
                end
                2'b10:
                begin
                    case(sampled_wsize)
                        2'b00:
                        begin
                            sampled_address<=sampled_address+2;
                        end
                        2'b01:
                        begin
                            sampled_address<=sampled_address+1;
                        end
                        2'b10:
                        begin
                            sampled_address<=sampled_address+2;
                        end
                        2'b11:
                        begin
                            sampled_address<=sampled_address+2;
                        end
                    endcase
                    sampled_address<=sampled_address+2;
                end
                2'b11:
                begin
                    case(sampled_wsize)
                        2'b00:
                        begin
                            sampled_address<=sampled_address+1;
                        end
                        2'b01:
                        begin
                            sampled_address<=sampled_address+1;
                        end
                        2'b10:
                        begin
                            sampled_address<=sampled_address+1;
                        end
                        2'b11:
                        begin
                            sampled_address<=sampled_address+1;
                        end
                    endcase
                    sampled_address<=sampled_address+1;
                end
            endcase
        end
        else
        begin
            sampled_address<=sampled_address;
            //sampled_wlen<=sampled_wlen;
        end
    end
    
    //decrement the sampled length
    always@(posedge ACLK)
    begin
        if((present_state==WRITE_ADDRESS_RECEIVED_STATE && WVALID==1) || (present_state==DATA_TRANSFERRED_STATE && WVALID==1'b1) || (present_state==PENABLE_READ_SIGNAL && PREADY==1'b1))
        begin
            sampled_wlen<=sampled_wlen-1;
        end
        else if(present_state==IDLE_STATE && ARVALID==1'b1)
        begin
            sampled_wlen<=ARLEN;
        end
        else if(present_state==IDLE_STATE && AWVALID==1'b1)
        begin
            sampled_wlen<=AWLEN;
        end
        else
        begin
            sampled_wlen<=sampled_wlen;
        end
            
    end
    //sampling of AWSIZE and ARSIZE
    always@(posedge ACLK)
    begin
        if(present_state==IDLE_STATE && AWVALID==1'b1)
        begin
            if(AWVALID==1'b1)
            begin
                sampled_wsize<=AWSIZE;
            end
            else if(ARVALID==1'b1)
            begin
                sampled_wsize<=ARSIZE;
            end
            else
            begin
                sampled_wsize<=sampled_wsize;
            end
        end
       
    end

    
    
    //write data sample LOGIC
    always@(posedge ACLK)
    begin
        if((present_state==WRITE_ADDRESS_RECEIVED_STATE && WVALID==1'b1) || (present_state==DATA_TRANSFERRED_STATE && WVALID==1'b1))
        begin
            sampled_wdata<=WDATA;
            sampled_wstrb<=WSTRB;
            
        end
        else
        begin
            sampled_wdata<=sampled_wdata;
            sampled_wstrb<=sampled_wstrb;
        end
        
    end
    
    //write data on PWDATA bus and also address sampling
    always@(posedge ACLK)
    begin
        if((present_state==WRITE_ADDRESS_RECEIVED_STATE && WVALID==1'b1) || (present_state==DATA_TRANSFERRED_STATE && WVALID==1'b1))
        begin
            PADDR<=sampled_address;
            case(sampled_address%4)
                2'b00:
                begin
                    if(sampled_wsize==2'd1)//8 bits
                    begin
                        PWDATA<={24'd0,WDATA[7:0]};//data present in first eight bits
                    end
                    else if(sampled_wsize==2'd2)//16 bits
                    begin
                        PWDATA<={16'd0,WDATA[15:0]};//data present in first sixteen bits
                    end
                    else    //32 bits
                    begin
                        PWDATA<=WDATA;//data present in all 32 bits
                    end
                end
                2'b01:
                begin
                    if(sampled_wsize==2'd1)//8 bits
                    begin
                        PWDATA<={24'd0,WDATA[15:8]};//data present in next 8 bits
                    end
                    else if(sampled_wsize==2'd2)//16 bits
                    begin
                        PWDATA<={24'd0,WDATA[15:8]};//data present in next 16 bits
                    end
                    else    //32 bits
                    begin
                        PWDATA<={8'd0,WDATA[31:8]};//unaligned tranfer first 8 bits doesn't contain data
                    end
                    
                end
                2'b10:
                begin
                    if(sampled_wsize==2'd1)//8 bits
                    begin
                        PWDATA<={24'd0,WDATA[24:16]};
                    end
                    else if(sampled_wsize==2'd2)//16 bits
                    begin
                        PWDATA<={16'd0,WDATA[31:16]};
                    end
                    else    //32 bits
                    begin
                        PWDATA<={16'd0,WDATA[31:16]};
                    end
                end
                2'b11:
                begin
                   if(sampled_wsize==2'd1)//8 bits
                    begin
                        PWDATA<={24'd0,WDATA[31:24]};
                    end
                    else if(sampled_wsize==2'd2)//16 bits
                    begin
                        PWDATA<={24'd0,WDATA[31:24]};
                    end
                    else    //32 bits
                    begin
                        PWDATA<={24'd0,WDATA[31:24]};
                    end 
                end
            endcase
            
        end
        else if(present_state==IDLE_STATE && ARVALID==1'b1)
        begin
            PADDR<=ARADDR;
        end
        else if(present_state==READ_DATA_TRANSFERRED_STATE && RREADY==1'b1 && sampled_wlen!=0)
        begin
            PADDR<=sampled_address;
        end
    end
    
    
    //error handling
    always@(posedge ACLK or negedge ARESET)
    begin
        if(ARESET==1'b0)
        begin
            BRESP<=2'd0;
        end
        else
            begin
            if(present_state==PENABLE_SIGNAL && PREADY==1'b1 && BRESP==2'b00)//change the logic since if one thing is error the whole burst should be an error
            begin
                if(PSLVERR==1'b0)
                begin
                    BRESP<=2'b00;
                end
                else
                begin
                    BRESP<=2'b11;//error
                end
            end
            else if(present_state==PENABLE_SIGNAL && PREADY==1'b1 && BRESP==2'b11)//an error that happenned before
            begin
                BRESP<=2'b11;//an error
            end
            else
            begin
                BRESP<=BRESP;
            end
        end
    end
    
    //Read address sampling  
    always@(posedge ACLK)
    begin
        if(present_state==PENABLE_READ_SIGNAL && PREADY==1'b1 && PSLVERR==1'b0)
        begin
            RDATA<=PRDATA;
        end
    end
    
    always@(posedge ACLK or negedge ARESET)
    begin
        if(ARESET==1'b0)
        begin
            RRESP=2'b00;
        end
        else
        begin
            if(present_state==PENABLE_READ_SIGNAL && PREADY==1'b1)
            begin
                if(PSLVERR==1'b1)
                begin
                    RRESP<=2'b11;
                end
                else
                begin
                    RRESP<=2'b00;
                end
                    
            end
            
        end
    end 
    
endmodule

module galaksija_keyboard(
    input        clk,
    input        reset,
    input  [5:0] addr,
    input [10:0] ps2_key,
    output reg   key_out
);

reg [63:0] keys = ~64'd0; // initial all keys released

wire released   = ps2_key[9]; // 0:pressed, 1:not pressed
wire [8:0] code = ps2_key[8:0];
reg  interrupt  = 1'b0;

always @(posedge clk) begin
    if(interrupt != ps2_key[10]) begin
        case (code[8:0])
            8'h1C : keys[8'd01] = released; // A
            8'h32 : keys[8'd02] = released; // B
            8'h21 : keys[8'd03] = released; // C
            8'h23 : keys[8'd04] = released; // D
            8'h24 : keys[8'd05] = released; // E
            8'h2B : keys[8'd06] = released; // F
            8'h34 : keys[8'd07] = released; // G
            8'h33 : keys[8'd08] = released; // H
            8'h43 : keys[8'd09] = released; // I
            8'h3B : keys[8'd10] = released; // J
            8'h42 : keys[8'd11] = released; // K
            8'h4B : keys[8'd12] = released; // L
            8'h3A : keys[8'd13] = released; // M
            8'h31 : keys[8'd14] = released; // N
            8'h44 : keys[8'd15] = released; // O
            8'h4D : keys[8'd16] = released; // P
            8'h15 : keys[8'd17] = released; // Q
            8'h2D : keys[8'd18] = released; // R
            8'h1B : keys[8'd19] = released; // S
            8'h2C : keys[8'd20] = released; // T
            8'h3C : keys[8'd21] = released; // U
            8'h2A : keys[8'd22] = released; // V
            8'h1D : keys[8'd23] = released; // W
            8'h22 : keys[8'd24] = released; // X
            8'h35 : keys[8'd25] = released; // Y
            8'h1A : keys[8'd26] = released; // Z                
                                                    
            8'h29 : keys[8'd31] = released; // SPACE                
            8'h45 : keys[8'd32] = released; // 0
            8'h16 : keys[8'd33] = released; // 1
            8'h1E : keys[8'd34] = released; // 2
            8'h26 : keys[8'd35] = released; // 3
            8'h25 : keys[8'd36] = released; // 4
            8'h2E : keys[8'd37] = released; // 5
            8'h36 : keys[8'd38] = released; // 6
            8'h3D : keys[8'd39] = released; // 7
            8'h3E : keys[8'd40] = released; // 8
            8'h46 : keys[8'd41] = released; // 9
            
            // NUM Block
            8'h70 : keys[8'd32] = released; // 0
            8'h69 : keys[8'd33] = released; // 1
            8'h72 : keys[8'd34] = released; // 2
            8'h7A : keys[8'd35] = released; // 3
            8'h6B : keys[8'd36] = released; // 4
            8'h73 : keys[8'd37] = released; // 5
            8'h74 : keys[8'd38] = released; // 6
            8'h6C : keys[8'd39] = released; // 7
            8'h75 : keys[8'd40] = released; // 8
            8'h7D : keys[8'd41] = released; // 9                
            
            8'h4C : keys[8'd42] = released; // ; 
            8'h7C : keys[8'd43] = released; // : 
            8'h41 : keys[8'd44] = released; // ,
            8'h55 : keys[8'd45] = released; // = 
            8'h49 : keys[8'd46] = released; // .
            8'h4A : keys[8'd47] = released; // /                
            8'h5A : keys[8'd48] = released; // ENTER
            8'h76 : keys[8'd49] = released; // ESC
            
            8'h05 : keys[8'd50] = released; // F1 = Repeat
            8'h71 : keys[8'd51] = released; // DELETE
            8'h06 : keys[8'd52] = released; // F2 = List
            
            8'h12,                         // SHIFT L
            8'h59 : keys[8'd53] = released; // SHIFT R
        endcase

        // These accept extended codes as well
        case (code[7:0])     
            8'h75 : keys[8'd27] = released; // UP
            8'h72 : keys[8'd28] = released; // DOWN                    
            8'h66,                         // BACKSPACE
            8'h6B : keys[8'd29] = released; // LEFT                    
            8'h74 : keys[8'd30] = released; // RIGHT
        endcase
    end
    interrupt <= ps2_key[10];
    key_out <= keys[addr];
end
endmodule  

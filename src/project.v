`default_nettype none

module tt_um_RaphRaphyRofl_VerilogIEEEBounce (
    input  wire [7:0] ui_in,    
    output wire [7:0] uo_out,   
    input  wire [7:0] uio_in,   
    output wire [7:0] uio_out,  
    output wire [7:0] uio_oe,   
    input  wire       ena,      
    input  wire       clk,      
    input  wire       rst_n     
);

    // 1. VGA SYNC
    wire hsync, vsync, display_on;
    wire [9:0] hpos, vpos;
    hvsync_generator hvsync_gen (.clk(clk), .reset(~rst_n), .hsync(hsync), .vsync(vsync), .display_on(display_on), .hpos(hpos), .vpos(vpos));

    // 2. LFSR
    reg [7:0] lfsr;
    always @(posedge clk) begin
        if (~rst_n) lfsr <= 8'hA1; 
        else lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
    end

    // 3. POSITIONS
    reg signed [10:0] x0, x1, x2, x3;
    reg signed [10:0] y0, y1, y2, y3;
    reg signed [3:0]  vx0, vx1, vx2, vx3;
    reg signed [3:0]  vy0, vy1, vy2, vy3;

    wire frame_tick = (vpos == 479 && hpos == 639);

    // 4. MOVEMENT
    always @(posedge clk) begin
        if (~rst_n) begin
            x0 <= 100; y0 <= 240; vx0 <= 2;  vy0 <= 2;
            x1 <= 240; y1 <= 240; vx1 <= -2; vy1 <= 1;
            x2 <= 380; y2 <= 240; vx2 <= 1;  vy2 <= -2;
            x3 <= 520; y3 <= 240; vx3 <= -1; vy3 <= -1;
        end else if (frame_tick) begin
            x0 <= x0 + 11'($signed(vx0)); y0 <= y0 + 11'($signed(vy0));
            x1 <= x1 + 11'($signed(vx1)); y1 <= y1 + 11'($signed(vy1));
            x2 <= x2 + 11'($signed(vx2)); y2 <= y2 + 11'($signed(vy2));
            x3 <= x3 + 11'($signed(vx3)); y3 <= y3 + 11'($signed(vy3));

            if (x0 < 60) vx0 <= 2; else if (x0 > 580) vx0 <= -2;
            if (y0 < 60) vy0 <= 2; else if (y0 > 420) vy0 <= -2;
            if (x1 < 60) vx1 <= 2; else if (x1 > 580) vx1 <= -2;
            if (y1 < 60) vy1 <= 2; else if (y1 > 420) vy1 <= -2;
            if (x2 < 60) vx2 <= 2; else if (x2 > 580) vx2 <= -2;
            if (y2 < 60) vy2 <= 2; else if (y2 > 420) vy2 <= -2;
            if (x3 < 60) vx3 <= 2; else if (x3 > 580) vx3 <= -2;
            if (y3 < 60) vy3 <= 2; else if (y3 > 420) vy3 <= -2;
        end
    end

    // 5. DRAWING ENGINE (Improved E Logic)
    reg [3:0] ball_hits;
    wire signed [10:0] cur_h = {1'b0, hpos};
    wire signed [10:0] cur_v = {1'b0, vpos};

    always @(*) begin
        ball_hits = 4'b0;
        begin : drawing_block
            reg signed [10:0] rx, ry;
            reg [10:0] ax, ay;
            reg in_shape, in_letter;
            integer j;
            
            for (j = 0; j < 4; j = j + 1) begin
                case(j)
                    0: begin rx = cur_h - x0; ry = cur_v - y0; end
                    1: begin rx = cur_h - x1; ry = cur_v - y1; end
                    2: begin rx = cur_h - x2; ry = cur_v - y2; end
                    default: begin rx = cur_h - x3; ry = cur_v - y3; end
                endcase
                
                ax = (rx[10]) ? -rx : rx;
                ay = (ry[10]) ? -ry : ry;
                in_shape = (ax < 60) && (ay < 60) && ((ax + ay) < 85);
                
                if (j == 0) begin
                    in_letter = (ax < 8) && (ay < 35);
                end else begin
                    // Clean 'E' logic
                    if (ax < 25 && ay < 35)
                        in_letter = !((rx > -10) && ((ry > -23 && ry < -6) || (ry > 6 && ry < 23)));
                    else
                        in_letter = 0;
                end
                ball_hits[j] = in_shape && !in_letter;
            end
        end
    end

    // 6. COLOR OUTPUT
    reg [1:0] r_out, g_out, b_out;
    always @(*) begin
        if (!display_on) begin 
            r_out = 0; g_out = 0; b_out = 0; 
        end else if (ball_hits[0]) begin 
            r_out = 3; g_out = 2; b_out = 0; // Orange
        end else if (|ball_hits[3:1]) begin 
            r_out = 3; g_out = 3; b_out = 3; // White
        end else begin 
            r_out = 0; g_out = 0; b_out = 3; // Blue
        end
    end

    assign uo_out = {hsync, b_out[0], g_out[0], r_out[0], vsync, b_out[1], g_out[1], r_out[1]};
    assign uio_out = 8'b0; 
    assign uio_oe = 8'b0;
    wire _unused = &{ena, ui_in, uio_in, lfsr};

endmodule

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

    // (LFSR Removed to save flip-flops/gates, since it was unused)

    // 2. POSITIONS (Maintained as signed 11-bit for stable edge-bouncing)
    reg signed [10:0] x0, x1, x2, x3;
    reg signed [10:0] y0, y1, y2, y3;
    reg signed [3:0]  vx0, vx1, vx2, vx3;
    reg signed [3:0]  vy0, vy1, vy2, vy3;

    wire frame_tick = (vpos == 479 && hpos == 639);

    // 3. MOVEMENT
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

    // 4. DRAWING ENGINE (Flattened to eliminate for-loop & mux overhead)
    wire signed [10:0] cur_h = {1'b0, hpos};
    wire signed [10:0] cur_v = {1'b0, vpos};

    // Ball 0 (Letter I)
    wire signed [10:0] rx0 = cur_h - x0; 
    wire signed [10:0] ry0 = cur_v - y0;
    wire [10:0] ax0 = (rx0[10]) ? -rx0 : rx0; 
    wire [10:0] ay0 = (ry0[10]) ? -ry0 : ry0;
    wire shape0 = (ax0 < 60) && (ay0 < 60) && ((ax0 + ay0) < 85);
    wire b0 = shape0 && !((ax0 < 8) && (ay0 < 35));

    // Ball 1 (Letter E)
    wire signed [10:0] rx1 = cur_h - x1; 
    wire signed [10:0] ry1 = cur_v - y1;
    wire [10:0] ax1 = (rx1[10]) ? -rx1 : rx1; 
    wire [10:0] ay1 = (ry1[10]) ? -ry1 : ry1;
    wire shape1 = (ax1 < 60) && (ay1 < 60) && ((ax1 + ay1) < 85);
    wire b1 = shape1 && !((ax1 < 25 && ay1 < 35) && !((rx1 > -10) && ((ry1 > -23 && ry1 < -6) || (ry1 > 6 && ry1 < 23))));

    // Ball 2 (Letter E)
    wire signed [10:0] rx2 = cur_h - x2; 
    wire signed [10:0] ry2 = cur_v - y2;
    wire [10:0] ax2 = (rx2[10]) ? -rx2 : rx2; 
    wire [10:0] ay2 = (ry2[10]) ? -ry2 : ry2;
    wire shape2 = (ax2 < 60) && (ay2 < 60) && ((ax2 + ay2) < 85);
    wire b2 = shape2 && !((ax2 < 25 && ay2 < 35) && !((rx2 > -10) && ((ry2 > -23 && ry2 < -6) || (ry2 > 6 && ry2 < 23))));

    // Ball 3 (Letter E)
    wire signed [10:0] rx3 = cur_h - x3; 
    wire signed [10:0] ry3 = cur_v - y3;
    wire [10:0] ax3 = (rx3[10]) ? -rx3 : rx3; 
    wire [10:0] ay3 = (ry3[10]) ? -ry3 : ry3;
    wire shape3 = (ax3 < 60) && (ay3 < 60) && ((ax3 + ay3) < 85);
    wire b3 = shape3 && !((ax3 < 25 && ay3 < 35) && !((rx3 > -10) && ((ry3 > -23 && ry3 < -6) || (ry3 > 6 && ry3 < 23))));


    // 5. COLOR OUTPUT
    reg [1:0] r_out, g_out, b_out;
    always @(*) begin
        if (!display_on) begin 
            r_out = 0; g_out = 0; b_out = 0; 
        end else if (b0) begin 
            r_out = 3; g_out = 2; b_out = 0; // Orange
        end else if (b1 | b2 | b3) begin 
            r_out = 3; g_out = 3; b_out = 3; // White
        end else begin 
            r_out = 0; g_out = 0; b_out = 3; // Blue
        end
    end

    assign uo_out = {hsync, b_out[0], g_out[0], r_out[0], vsync, b_out[1], g_out[1], r_out[1]};
    assign uio_out = 8'b0; 
    assign uio_oe = 8'b0;
    
    wire _unused = &{ena, ui_in, uio_in};

endmodule

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

    // ==========================================
    // 1. VGA SYNC (Unchanged)
    // ==========================================
    wire hsync, vsync, display_on;
    wire [9:0] hpos, vpos;
    hvsync_generator hvsync_gen (.clk(clk), .reset(~rst_n), .hsync(hsync), .vsync(vsync), .display_on(display_on), .hpos(hpos), .vpos(vpos));

    // ==========================================
    // 2. POSITIONS (Virtual Resolution: 320x240)
    // ==========================================
    // X fits in 9 bits (0-319), Y fits in 8 bits (0-239)
    reg [8:0] x0, x1, x2, x3;
    reg [7:0] y0, y1, y2, y3;

    // 1-bit velocities (1 = positive/right/down, 0 = negative/left/up)
    reg dx0, dx1, dx2, dx3;
    reg dy0, dy1, dy2, dy3;

    wire frame_tick = (vpos == 479 && hpos == 639);

    // ==========================================
    // 3. MOVEMENT & BOUNCING
    // ==========================================
    always @(posedge clk) begin
        if (~rst_n) begin
            // Staggered starting positions to break synchronization
            x0 <= 50;  y0 <= 70;  dx0 <= 1; dy0 <= 1;
            x1 <= 110; y1 <= 150; dx1 <= 0; dy1 <= 1;
            x2 <= 180; y2 <= 90;  dx2 <= 1; dy2 <= 0;
            x3 <= 250; y3 <= 180; dx3 <= 0; dy3 <= 0;
        end else if (frame_tick) begin
            // Move 1 internal pixel per frame (2 screen pixels)
            x0 <= dx0 ? x0 + 9'd1 : x0 - 9'd1;
            y0 <= dy0 ? y0 + 8'd1 : y0 - 8'd1;
            x1 <= dx1 ? x1 + 9'd1 : x1 - 9'd1;
            y1 <= dy1 ? y1 + 8'd1 : y1 - 8'd1;
            x2 <= dx2 ? x2 + 9'd1 : x2 - 9'd1;
            y2 <= dy2 ? y2 + 8'd1 : y2 - 8'd1;
            x3 <= dx3 ? x3 + 9'd1 : x3 - 9'd1;
            y3 <= dy3 ? y3 + 8'd1 : y3 - 8'd1;

            // Scaled down bouncing limits (Virtual Radius is 30)
            if (x0 < 30) dx0 <= 1; else if (x0 > 290) dx0 <= 0;
            if (y0 < 30) dy0 <= 1; else if (y0 > 210) dy0 <= 0;
            
            if (x1 < 30) dx1 <= 1; else if (x1 > 290) dx1 <= 0;
            if (y1 < 30) dy1 <= 1; else if (y1 > 210) dy1 <= 0;
            
            if (x2 < 30) dx2 <= 1; else if (x2 > 290) dx2 <= 0;
            if (y2 < 30) dy2 <= 1; else if (y2 > 210) dy2 <= 0;
            
            if (x3 < 30) dx3 <= 1; else if (x3 > 290) dx3 <= 0;
            if (y3 < 30) dy3 <= 1; else if (y3 > 210) dy3 <= 0;
        end
    end

    // ==========================================
    // 4. DRAWING ENGINE (Shared Masking)
    // ==========================================
    
    // Divide screen coordinates by 2 by ignoring the lowest bit ([9:1])
    wire signed [9:0] cur_h = {1'b0, hpos[9:1]};
    wire signed [9:0] cur_v = {1'b0, vpos[9:1]};

    // Calculate Octagon Shapes (Radius=30, Chamfer=42)
    wire signed [9:0] rx0 = cur_h - {1'b0, x0}; wire signed [9:0] ry0 = cur_v - {2'b00, y0};
    wire [8:0] ax0 = (rx0[9]) ? -rx0[8:0] : rx0[8:0]; wire [8:0] ay0 = (ry0[9]) ? -ry0[8:0] : ry0[8:0];
    wire s0 = (ax0 < 30) && (ay0 < 30) && ((ax0 + ay0) < 42);

    wire signed [9:0] rx1 = cur_h - {1'b0, x1}; wire signed [9:0] ry1 = cur_v - {2'b00, y1};
    wire [8:0] ax1 = (rx1[9]) ? -rx1[8:0] : rx1[8:0]; wire [8:0] ay1 = (ry1[9]) ? -ry1[8:0] : ry1[8:0];
    wire s1 = (ax1 < 30) && (ay1 < 30) && ((ax1 + ay1) < 42);

    wire signed [9:0] rx2 = cur_h - {1'b0, x2}; wire signed [9:0] ry2 = cur_v - {2'b00, y2};
    wire [8:0] ax2 = (rx2[9]) ? -rx2[8:0] : rx2[8:0]; wire [8:0] ay2 = (ry2[9]) ? -ry2[8:0] : ry2[8:0];
    wire s2 = (ax2 < 30) && (ay2 < 30) && ((ax2 + ay2) < 42);

    wire signed [9:0] rx3 = cur_h - {1'b0, x3}; wire signed [9:0] ry3 = cur_v - {2'b00, y3};
    wire [8:0] ax3 = (rx3[9]) ? -rx3[8:0] : rx3[8:0]; wire [8:0] ay3 = (ry3[9]) ? -ry3[8:0] : ry3[8:0];
    wire s3 = (ax3 < 30) && (ay3 < 30) && ((ax3 + ay3) < 42);

    // --- Letter I (Ball 0) ---
    wire b0_final = s0 && !((ax0 < 4) && (ay0 < 17));

    // --- Letter E (Balls 1, 2, 3 - SHARED MASK) ---
    wire e_hit = s1 | s2 | s3;

    // Multiplex the coordinates of whichever 'E' ball is currently being drawn
    wire signed [9:0] rx_e = s1 ? rx1 : (s2 ? rx2 : rx3);
    wire [8:0] ax_e        = s1 ? ax1 : (s2 ? ax2 : ax3);
    wire [8:0] ay_e        = s1 ? ay1 : (s2 ? ay2 : ay3);

    // Apply the "E" gap logic only ONCE for all three balls
    wire e_ink = (ax_e < 12 && ay_e < 17) && !((rx_e > -5) && (ay_e > 3 && ay_e < 11));
    wire e_final = e_hit && !e_ink;


    // ==========================================
    // 5. COLOR OUTPUT
    // ==========================================
    reg [1:0] r_out, g_out, b_out;
    always @(*) begin
        if (!display_on) begin 
            r_out = 0; g_out = 0; b_out = 0; 
        end else if (b0_final) begin 
            r_out = 3; g_out = 2; b_out = 0; // Orange
        end else if (e_final) begin 
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

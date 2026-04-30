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
    // 1. VGA SYNC GENERATION
    // ==========================================
    wire hsync, vsync, display_on;
    wire [9:0] hpos, vpos;

    hvsync_generator hvsync_gen (
        .clk(clk), .reset(~rst_n), .hsync(hsync), .vsync(vsync),
        .display_on(display_on), .hpos(hpos), .vpos(vpos)
    );

    // ==========================================
    // 2. RANDOM SEED GENERATOR (LFSR)
    // ==========================================
    reg [15:0] lfsr;
    always @(posedge clk) begin
        if (~rst_n) lfsr <= 16'hACE1; 
        else lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end

    // ==========================================
    // 3. ANIMATION PARAMETERS
    // ==========================================
    localparam HALF_SIZE = 60;   
    localparam BOX_SIZE  = 120;  
    localparam R_SQ      = 3600; 

    reg signed [10:0] x [0:3];
    reg signed [10:0] y [0:3];
    reg signed [3:0]  vx [0:3]; 
    reg signed [3:0]  vy [0:3];
    
    // Timer for 3-second delay (60fps * 3 = 180 frames)
    reg [7:0] start_timer;
    wire moving = (start_timer == 50);

    wire frame_tick = (vpos == 479 && hpos == 639);

    // ==========================================
    // 4. MOVEMENT & COLLISION
    // ==========================================
    integer i;
    always @(posedge clk) begin
        if (~rst_n) begin
            start_timer <= 0;
            // Spaced further apart in a line (Center of screen is 320, 240)
            x[0] <= 100; y[0] <= 240; vx[0] <= 2;  vy[0] <= 2;
            x[1] <= 240; y[1] <= 240; vx[1] <= -2; vy[1] <= 1;
            x[2] <= 380; y[2] <= 240; vx[2] <= 1;  vy[2] <= -2;
            x[3] <= 520; y[3] <= 240; vx[3] <= -1; vy[3] <= -1;
        end else if (frame_tick) begin
            if (!moving) begin
                start_timer <= start_timer + 1;
            end else begin
                for (i = 0; i < 4; i = i + 1) begin
                    x[i] <= x[i] + $signed(vx[i]); 
                    y[i] <= y[i] + $signed(vy[i]);

                    if (x[i] < HALF_SIZE) vx[i] <= 2; 
                    else if (x[i] > 640 - HALF_SIZE) vx[i] <= -2;
                    
                    if (y[i] < HALF_SIZE) vy[i] <= 2; 
                    else if (y[i] > 480 - HALF_SIZE) vy[i] <= -2;
                end
                check_collision(0, 1); check_collision(0, 2); check_collision(0, 3);
                check_collision(1, 2); check_collision(1, 3); check_collision(2, 3);
            end
        end
    end

    task check_collision(input integer a, input integer b);
        reg [10:0] dx, dy;
        begin
            dx = (x[a] > x[b]) ? (x[a] - x[b]) : (x[b] - x[a]);
            dy = (y[a] > y[b]) ? (y[a] - y[b]) : (y[b] - y[a]);
            if (dx < BOX_SIZE && dy < BOX_SIZE) begin
                vx[a] <= (x[a] < x[b]) ? -2 : 2; 
                vx[b] <= (x[a] < x[b]) ? 2 : -2;
                vy[a] <= (y[a] < y[b]) ? -2 : 2; 
                vy[b] <= (y[a] < y[b]) ? 2 : -2;
            end
        end
    endtask

    // ==========================================
    // 5. SHAPE MATH
    // ==========================================
    wire [3:0] ball_final;
    genvar g;
    generate
        for (g = 0; g < 4; g = g + 1) begin : logo_draw
            wire signed [10:0] rel_x = {1'b0, hpos} - x[g];
            wire signed [10:0] rel_y = {1'b0, vpos} - y[g];
            wire in_circle = (rel_x*rel_x + rel_y*rel_y) < R_SQ;
            wire in_letter;
            if (g == 0) begin : draw_I
                assign in_letter = (rel_x >= -8 && rel_x <= 8) && (rel_y >= -35 && rel_y <= 35);
            end else begin : draw_E
                wire spine = (rel_x >= -25 && rel_x <= -10) && (rel_y >= -35 && rel_y <= 35);
                wire bars  = (rel_x >= -25 && rel_x <= 25) && (
                    (rel_y >= -35 && rel_y <= -23) || 
                    (rel_y >= -6  && rel_y <= 6)   || 
                    (rel_y >= 23  && rel_y <= 35)     
                );
                assign in_letter = spine | bars;
            end
            assign ball_final[g] = in_circle ^ in_letter;
        end
    endgenerate

    // ==========================================
    // 6. COLOR OUTPUT (Blue Background)
    // ==========================================
    reg [1:0] R, G, B;
    always @(*) begin
        if (!display_on) begin 
            R = 0; G = 0; B = 0; 
        end else if (ball_final[0]) begin 
            R = 2'b11; G = 2'b10; B = 2'b00; // Orange (I)
        end else if (ball_final[1] | ball_final[2] | ball_final[3]) begin 
            R = 2'b11; G = 2'b11; B = 2'b11; // White (E)
        end else begin 
            R = 2'b00; G = 2'b00; B = 2'b11; // Blue Background
        end
    end

    assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = 8'b0; assign uio_oe = 8'b0;
    wire _unused = &{ena, ui_in, uio_in, lfsr};
endmodule

// =========================================================
// VGA SYNC GENERATOR
// =========================================================
module hvsync_generator (
    input wire clk, reset,
    output reg hsync, vsync, display_on,
    output reg [9:0] hpos, vpos
);
    always @(posedge clk) begin
        if (reset) begin hpos <= 0; vpos <= 0; end
        else begin
            if (hpos == 799) begin
                hpos <= 0;
                if (vpos == 524) vpos <= 0;
                else vpos <= vpos + 1;
            end else hpos <= hpos + 1;
        end
    end
    always @(*) begin
        hsync = ~(hpos >= 656 && hpos < 752);
        vsync = ~(vpos >= 490 && vpos < 492);
        display_on = (hpos < 640) && (vpos < 480);
    end
endmodule

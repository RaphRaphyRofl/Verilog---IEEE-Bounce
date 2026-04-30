`default_nettype none

module tt_um_vga_example (
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

    // Instance of external hvsync_generator
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
    
    // Timer for 3-second delay (180 frames @ 60fps)
    reg [7:0] start_timer;
    wire moving = (start_timer == 8'd100);

    wire frame_tick = (vpos == 10'd479 && hpos == 10'd639);

    // ==========================================
    // 4. MOVEMENT & COLLISION
    // ==========================================
    integer i;
    always @(posedge clk) begin
        if (~rst_n) begin
            start_timer <= 8'd0;
            x[0] <= 11'd100; y[0] <= 11'd240; vx[0] <= 4'sd2;  vy[0] <= 4'sd2;
            x[1] <= 11'd240; y[1] <= 11'd240; vx[1] <= -4'sd2; vy[1] <= 4'sd1;
            x[2] <= 11'd380; y[2] <= 11'd240; vx[2] <= 4'sd1;  vy[2] <= -4'sd2;
            x[3] <= 11'd520; y[3] <= 11'd240; vx[3] <= -4'sd1; vy[3] <= -4'sd1;
        end else if (frame_tick) begin
            if (!moving) begin
                start_timer <= start_timer + 8'd1;
            end else begin
                for (i = 0; i < 4; i = i + 1) begin
                    // Width expansion fix: explicitly cast signed velocity to 11 bits
                    x[i] <= x[i] + 11'($signed(vx[i])); 
                    y[i] <= y[i] + 11'($signed(vy[i]));

                    if (x[i] < HALF_SIZE) vx[i] <= 4'sd2; 
                    else if (x[i] > 11'd640 - HALF_SIZE) vx[i] <= -4'sd2;
                    
                    if (y[i] < HALF_SIZE) vy[i] <= 4'sd2; 
                    else if (y[i] > 11'd480 - HALF_SIZE) vy[i] <= -4'sd2;
                end
                // Index literal fix for task calls
                check_collision(2'd0, 2'd1); check_collision(2'd0, 2'd2); check_collision(2'd0, 2'd3);
                check_collision(2'd1, 2'd2); check_collision(2'd1, 2'd3); check_collision(2'd2, 2'd3);
            end
        end
    end

    // Input width fix: change integer to [1:0] to silence unused bit warnings
    task check_collision(input [1:0] a, input [1:0] b);
        reg [10:0] dx, dy;
        begin
            dx = (x[a] > x[b]) ? (x[a] - x[b]) : (x[b] - x[a]);
            dy = (y[a] > y[b]) ? (y[a] - y[b]) : (y[b] - y[a]);
            if (dx < BOX_SIZE[10:0] && dy < BOX_SIZE[10:0]) begin
                vx[a] <= (x[a] < x[b]) ? -4'sd2 : 4'sd2; 
                vx[b] <= (x[a] < x[b]) ? 4'sd2 : -4'sd2;
                vy[a] <= (y[a] < y[b]) ? -4'sd2 : 4'sd2; 
                vy[b] <= (y[a] < y[b]) ? 4'sd2 : -4'sd2;
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
                assign in_letter = (rel_x >= -11'sd8 && rel_x <= 11'sd8) && (rel_y >= -11'sd35 && rel_y <= 11'sd35);
            end else begin : draw_E
                wire spine = (rel_x >= -11'sd25 && rel_x <= -11'sd10) && (rel_y >= -11'sd35 && rel_y <= 11'sd35);
                wire bars  = (rel_x >= -11'sd25 && rel_x <= 11'sd25) && (
                    (rel_y >= -11'sd35 && rel_y <= -11'sd23) || 
                    (rel_y >= -11'sd6  && rel_y <= 11'sd6)   || 
                    (rel_y >= 11'sd23  && rel_y <= 11'sd35)     
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
            R = 2'b00; G = 2'b00; B = 2'b00; 
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
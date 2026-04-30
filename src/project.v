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

    // 1. VGA SYNC GENERATION
    wire hsync, vsync, display_on;
    wire [9:0] hpos, vpos;

    hvsync_generator hvsync_gen (
        .clk(clk), .reset(~rst_n), .hsync(hsync), .vsync(vsync),
        .display_on(display_on), .hpos(hpos), .vpos(vpos)
    );

    // 2. RANDOM SEED GENERATOR (LFSR)
    reg [15:0] lfsr;
    always @(posedge clk) begin
        if (~rst_n) lfsr <= 16'hACE1; 
        else lfsr <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ lfsr[12] ^ lfsr[10]};
    end

    // 3. ANIMATION PARAMETERS
    localparam HALF_SIZE = 60;   

    reg signed [10:0] x [0:3];
    reg signed [10:0] y [0:3];
    reg signed [3:0]  vx [0:3]; 
    reg signed [3:0]  vy [0:3];
    
    wire frame_tick = (vpos == 10'd479 && hpos == 10'd639);

    // 4. MOVEMENT (Wall Bounce Only - No Inter-ball Collision)
    integer i;
    always @(posedge clk) begin
        if (~rst_n) begin
            x[0] <= 11'd100; y[0] <= 11'd240; vx[0] <= 4'sd2;  vy[0] <= 4'sd2;
            x[1] <= 11'd240; y[1] <= 11'd240; vx[1] <= -4'sd2; vy[1] <= 4'sd1;
            x[2] <= 11'd380; y[2] <= 11'd240; vx[2] <= 4'sd1;  vy[2] <= -4'sd2;
            x[3] <= 11'd520; y[3] <= 11'd240; vx[3] <= -4'sd1; vy[3] <= -4'sd1;
        end else if (frame_tick) begin
            for (i = 0; i < 4; i = i + 1) begin
                x[i] <= x[i] + 11'($signed(vx[i])); 
                y[i] <= y[i] + 11'($signed(vy[i]));

                // Screen Boundary Bouncing
                if (x[i] < HALF_SIZE) vx[i] <= 4'sd2; 
                else if (x[i] > 11'd640 - HALF_SIZE) vx[i] <= -4'sd2;
                
                if (y[i] < HALF_SIZE) vy[i] <= 4'sd2; 
                else if (y[i] > 11'd480 - HALF_SIZE) vy[i] <= -4'sd2;
            end
        end
    end

    // 5. SHAPE DRAWING (Octagons + Letters)
    reg [3:0] ball_pixel;
    integer j;
    always @(*) begin
        ball_pixel = 4'b0000;
        for (j = 0; j < 4; j = j + 1) begin
            begin : draw_logic
                reg signed [10:0] rel_x, rel_y;
                reg [10:0] ax, ay;
                reg in_octagon, in_letter;
                
                rel_x = {1'b0, hpos} - x[j];
                rel_y = {1'b0, vpos} - y[j];
                ax = (rel_x[10]) ? -rel_x : rel_x;
                ay = (rel_y[10]) ? -rel_y : rel_y;

                // Octagon Shape (Approximated circle)
                in_octagon = (ax < 11'd60) && (ay < 11'd60) && ((ax + ay) < 11'd85);

                // Letter Logic
                if (j == 0) begin
                    in_letter = (ax < 11'd8) && (ay < 11'd35);
                end else begin
                    in_letter = ((rel_x >= -11'sd25 && rel_x <= -11'sd10) && (ay < 11'd35)) || // Spine
                                ((ax < 11'd25) && ((rel_y >= -11'sd35 && rel_y <= -11'sd23) || (ay < 11'd6) || (rel_y >= 11'sd23 && rel_y <= 11'sd35))); // Bars
                end
                
                ball_pixel[j] = in_octagon ^ in_letter;
            end
        end
    end

    // 6. COLOR OUTPUT
    reg [1:0] R, G, B;
    always @(*) begin
        if (!display_on) begin 
            {R, G, B} = 6'b000000; 
        end else if (ball_pixel[0]) begin 
            R = 2'b11; G = 2'b10; B = 2'b00; // Orange (I)
        end else if (|ball_pixel[3:1]) begin 
            R = 2'b11; G = 2'b11; B = 2'b11; // White (E)
        end else begin 
            R = 2'b00; G = 2'b00; B = 2'b11; // Blue Background
        end
    end

    assign uo_out  = {hsync, B[0], G[0], R[0], vsync, B[1], G[1], R[1]};
    assign uio_out = 8'b0; assign uio_oe = 8'b0;
    wire _unused = &{ena, ui_in, uio_in, lfsr};

endmodule

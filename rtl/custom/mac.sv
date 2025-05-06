module mac #(
    parameter WIDTH = 32
) (
    input  logic              clk,
    input  logic              rst_n,
    input  logic              en,         // enable accumulate
    input  logic              clr,        // clear accumulator
    input  logic [WIDTH-1:0]  a,
    input  logic [WIDTH-1:0]  b,
    output logic [2*WIDTH-1:0] acc_out
);

    logic [2*WIDTH-1:0] acc_reg;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            acc_reg <= '0;
        else if (clr)
            acc_reg <= '0;
        else if (en)
            acc_reg <= acc_reg + a * b;
    end

    assign acc_out = acc_reg;

endmodule

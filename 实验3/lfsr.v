`timescale 1ns / 1ps

module lfsr #(
    parameter WIDTH = 4            // LFSR 位宽
)(
    input  wire             clk,   // 时钟
    input  wire             rst,   // 异步复位，高电平有效
    input  wire             en,    // 使能信号，高电平时移位更新
    output reg  [WIDTH-1:0] out    // LFSR 当前状态/输出
);

    // 反馈位：取最高两位做异或
    // 对于 WIDTH=4，相当于反馈 = out[3] ^ out[2]
    wire feedback = out[WIDTH-1] ^ out[WIDTH-2];

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            // 复位时写入非零初始状态（全 1）
            out <= {WIDTH{1'b1}};
        end else if (en) begin
            // 右移一位，MSB := feedback
            out <= {out[WIDTH-2:0], feedback};
        end
        // 未使能(en=0)时保持原状态
    end

endmodule


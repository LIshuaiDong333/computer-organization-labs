`timescale 1ns / 1ps

module fpu(
    input  wire         rst,      // 高电平复位
    input  wire         clk,
    input  wire         start,    // 当start为1时触发计算
    input  wire         op,       // 0 表示加法，1表示减法
    input  wire [31:0]  A,        // 操作数 A
    input  wire [31:0]  B,        // 操作数 B
    output reg          ready,    // 运算完成或复位时为1
    output reg [31:0]   C         // 计算结果
);

    // 状态定义
    localparam IDLE          = 3'd0;
    localparam EXTRACT_EXP   = 3'd1;   
    localparam EXTRACT_MANT  = 3'd2;
    localparam ALIGN         = 3'd3;
    localparam CALC          = 3'd4;
    localparam NORMALIZE     = 3'd5;
    localparam PACK          = 3'd6;

    // 状态寄存器
    reg [2:0] cur_state, next_state;

    // 内部寄存器定义
    reg op_sel;                 // 保存运算类型
    reg [31:0] a_reg, b_reg;    // 保存输入操作数

    // 拆分后的各域  
    reg        a_sign, b_sign;
    reg [7:0]  a_exponent, b_exponent;
    reg [23:0] a_mantissa, b_mantissa; // 24位：隐含1+23位小数

    // 对齐操作相关信号 
    reg [23:0] a_aligned, b_aligned;
    reg [7:0]  result_exponent; // 对齐后阶码

    // 运算结果信号   
    reg [24:0] result_mant;   // 25位用于捕捉溢出或借位
    reg        result_sign;

    // 状态更新（同步复位）
    always @(posedge clk or posedge rst) begin
        cur_state <= rst ? IDLE : next_state;
    end

    // 状态转移逻辑
    always @(*) begin
        next_state = cur_state;
        case (cur_state)
            IDLE:          if(start) next_state = EXTRACT_EXP;
            EXTRACT_EXP:   next_state = EXTRACT_MANT;
            EXTRACT_MANT:  next_state = ALIGN;
            ALIGN:         next_state = CALC;
            CALC:          next_state = NORMALIZE;
            NORMALIZE:     begin
                               if(result_mant == 0)
                                   next_state = PACK;
                               else if(result_mant[24])
                                   next_state = PACK; // 右规后完成规格化
                               else if(~result_mant[23])
                                   next_state = NORMALIZE; // 继续左规
                               else 
                                   next_state = PACK;
                           end
            PACK:          next_state = IDLE;
            default:       next_state = IDLE;
        endcase
    end

    // 状态机主要操作
    always @(posedge clk or posedge rst) begin
        if (rst) begin    //初始化
            ready           <= 1'b1;
            C               <= 32'b0;
            op_sel          <= 1'b0;
            a_reg           <= 32'b0;
            b_reg           <= 32'b0;
            a_sign          <= 1'b0;
            a_exponent      <= 8'b0;
            a_mantissa      <= 24'b0;
            b_sign          <= 1'b0;
            b_exponent      <= 8'b0;
            b_mantissa      <= 24'b0;
            a_aligned       <= 24'b0;
            b_aligned       <= 24'b0;
            result_exponent <= 8'b0;
            result_mant     <= 25'b0;
            result_sign     <= 1'b0;
        end else begin
            case (cur_state)
                IDLE: begin
                    ready <= 1'b1;
                    if(start) begin
                        a_reg  <= A;
                        b_reg  <= B;
                        op_sel <= op;
                        ready  <= 1'b0;
                    end
                end

                EXTRACT_EXP: begin
                    // 提取符号与阶码
                    a_sign     <= a_reg[31];
                    a_exponent <= a_reg[30:23];
                    b_exponent <= b_reg[30:23];
                    // 若为减法则对B的符号取反，实现统一加法运算
                    b_sign <= op_sel ? ~b_reg[31] : b_reg[31];
                end

                EXTRACT_MANT: begin
                    // 判断是否规格化数，并添加隐含1
                    a_mantissa <= (a_exponent == 0) ? {1'b0, a_reg[22:0]} : {1'b1, a_reg[22:0]};
                    b_mantissa <= (b_exponent == 0) ? {1'b0, b_reg[22:0]} : {1'b1, b_reg[22:0]};
                end

                ALIGN: begin
                    // 以较大指数为准，对齐尾数
                    if(a_exponent >= b_exponent) begin
                        result_exponent <= a_exponent;
                        a_aligned <= a_mantissa;
                        if ((a_exponent - b_exponent) >= 24)
                            b_aligned <= 24'b0;
                        else
                            b_aligned <= b_mantissa >> (a_exponent - b_exponent);
                    end else begin
                        result_exponent <= b_exponent;
                        b_aligned <= b_mantissa;
                        if ((b_exponent - a_exponent) >= 24)
                            a_aligned <= 24'b0;
                        else
                            a_aligned <= a_mantissa >> (b_exponent - a_exponent);
                    end
                end

                CALC: begin
                    // 同符号直接加，否则按较大尾数减较小尾数
                    if(a_sign == b_sign) begin
                        result_mant <= {1'b0, a_aligned} + {1'b0, b_aligned};
                        result_sign <= a_sign;
                    end else begin
                        if(a_aligned >= b_aligned) begin
                            result_mant <= {1'b0, a_aligned} - {1'b0, b_aligned};
                            result_sign <= a_sign;
                        end else begin
                            result_mant <= {1'b0, b_aligned} - {1'b0, a_aligned};
                            result_sign <= b_sign;
                        end
                    end
                end

                NORMALIZE: begin
                    // 规格化处理：右规调整溢出，左规补齐
                    if(result_mant == 0) begin
                        result_exponent <= 8'b0;
                    end else if(result_mant[24]) begin // 最高位为1，右移一位
                        result_mant <= result_mant >> 1;
                        result_exponent <= result_exponent + 1;
                    end else if(~result_mant[23]) begin // 左移至规格化
                        result_mant <= result_mant << 1;
                        result_exponent <= result_exponent - 1;
                    end
                end

                PACK: begin
                    // 打包为 IEEE-754 格式输出
                    if(result_mant == 0)
                        C <= 32'b0;
                    else
                        C <= {result_sign, result_exponent, result_mant[22:0]};
                    ready <= 1'b1;
                end

                default: ; // 默认不做操作
            endcase
        end
    end

endmodule



`timescale 1ns / 1ps

`include "defines.vh"

module ICache(
    input  wire         cpu_clk,        // 时钟信号
    input  wire         cpu_rst,        // 异步复位，高电平有效

    // CPU 接口
    input  wire         inst_rreq,      // 取指令请求
    input  wire [31:0]  inst_addr,      // 指令地址
    output reg          inst_valid,     // 指令有效标志
    output reg  [31:0]  inst_out,       // 输出的指令

    // 主存接口
    input  wire         dev_rrdy,       // 主存读准备就绪
    output reg  [ 3:0]  cpu_ren,        // 主存读使能（字节级）
    output reg  [31:0]  cpu_raddr,      // 主存读地址
    input  wire         dev_rvalid,     // 主存数据有效
    input  wire [255:0] dev_rdata       // 主存返回的256位数据（8条指令）
);

`ifdef ENABLE_ICACHE

    // 缓存结构（4路组相联）
    reg [3:0] valid;                    // 有效位数组
    reg [9:0] tag [3:0];                // 标签数组
    reg [255:0] data [3:0];             // 数据数组

    // 状态定义
    localparam IDLE      = 2'b00;
    localparam TAG_CHECK = 2'b01;
    localparam REFILL    = 2'b10;

    reg [1:0] state, next_state;        //状态寄存器

    // 地址分解
    wire [9:0] tag_from_cpu = inst_addr[14:5]; //地址中的标签字段
    wire [4:0] offset       = inst_addr[4:0];  //地址中的块内偏移

    // 命中逻辑
    reg        hit;
    reg        tag_match;
    reg [1:0]  hit_index;

    //标签匹配逻辑
    always @(*) begin
        if (valid[0] && (tag[0] == tag_from_cpu)) begin
            tag_match = 1'b1; hit_index = 2'b00;
        end else if (valid[1] && (tag[1] == tag_from_cpu)) begin
            tag_match = 1'b1; hit_index = 2'b01;
        end else if (valid[2] && (tag[2] == tag_from_cpu)) begin
            tag_match = 1'b1; hit_index = 2'b10;
        end else if (valid[3] && (tag[3] == tag_from_cpu)) begin
            tag_match = 1'b1; hit_index = 2'b11;
        end else begin
            tag_match = 1'b0; hit_index = 2'b00;
        end
    end

    //命中寄存器更新
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst)
            hit <= 1'b0;
        else
            hit <= (state == TAG_CHECK) && tag_match;
    end

    //指令输出选择
    always @(*) begin
        inst_valid = 1'b0;
        inst_out   = 32'b0;
        if (state == TAG_CHECK && tag_match) begin
            inst_valid = 1'b1;
            case (offset[4:2])
                3'b000: inst_out = data[hit_index][ 31:  0];
                3'b001: inst_out = data[hit_index][ 63: 32];
                3'b010: inst_out = data[hit_index][ 95: 64];
                3'b011: inst_out = data[hit_index][127: 96];
                3'b100: inst_out = data[hit_index][159:128];
                3'b101: inst_out = data[hit_index][191:160];
                3'b110: inst_out = data[hit_index][223:192];
                3'b111: inst_out = data[hit_index][255:224];
            endcase
        end
    end

    //状态寄存器和缓存初始化
    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            state <= IDLE;
            valid <= 4'b0000;
            tag[0] <= 10'b0; data[0] <= 256'b0;
            tag[1] <= 10'b0; data[1] <= 256'b0;
            tag[2] <= 10'b0; data[2] <= 256'b0;
            tag[3] <= 10'b0; data[3] <= 256'b0;
        end else begin
            state <= next_state;
        end
    end

    //状态转移逻辑
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (inst_rreq) next_state = TAG_CHECK;
            TAG_CHECK: begin
                if (tag_match) next_state = IDLE;
                else if (dev_rrdy) next_state = REFILL;
            end
            REFILL: if (dev_rvalid) next_state = TAG_CHECK;
        endcase
    end

    //替换策略（随机+优先空块）
    reg [1:0] replace_index;
    wire [1:0] random_index;

    lfsr #(.WIDTH(4)) u_lfsr (
        .clk(cpu_clk),
        .rst(cpu_rst),
        .en(state == REFILL && dev_rvalid),
        .out(random_index)
    );

    //缓存写入逻辑
    always @(posedge cpu_clk) begin
        if (state == REFILL && dev_rvalid) begin
            if (!valid[0])       replace_index <= 2'b00;
            else if (!valid[1])  replace_index <= 2'b01;
            else if (!valid[2])  replace_index <= 2'b10;
            else if (!valid[3])  replace_index <= 2'b11;
            else                 replace_index <= random_index[1:0];

            valid[replace_index] <= 1'b1;
            tag[replace_index]   <= tag_from_cpu;
            data[replace_index]  <= dev_rdata;
        end
    end

    //主存读请求控制
    always @(*) begin
        cpu_ren   = 4'h0;
        cpu_raddr = 32'h0;
        if (state == TAG_CHECK && !tag_match && dev_rrdy) begin
            cpu_ren   = 4'hF;
            cpu_raddr = {inst_addr[31:5], 5'b00000}; // 块对齐
        end
    end

`else

    //无缓存模式：直通主存状态机
    localparam IDLE  = 2'b00;
    localparam STAT0 = 2'b01;
    localparam STAT1 = 2'b11;

    reg [1:0] state, nstat;

    always @(posedge cpu_clk or posedge cpu_rst) begin
        state <= cpu_rst ? IDLE : nstat;
    end

    always @(*) begin
        case (state)
            IDLE:    nstat = inst_rreq ? (dev_rrdy ? STAT1 : STAT0) : IDLE;
            STAT0:   nstat = dev_rrdy ? STAT1 : STAT0;
            STAT1:   nstat = dev_rvalid ? IDLE : STAT1;
            default: nstat = IDLE;
        endcase
    end

    always @(posedge cpu_clk or posedge cpu_rst) begin
        if (cpu_rst) begin
            inst_valid <= 1'b0;
            cpu_ren    <= 4'h0;
        end else begin
            case (state)
                IDLE: begin
                    inst_valid <= 1'b0;
                    cpu_ren    <= (inst_rreq & dev_rrdy) ? 4'hF : 4'h0;
                    cpu_raddr  <= inst_rreq ? inst_addr : 32'h0;
                end
                STAT0: begin
                    cpu_ren    <= dev_rrdy ? 4'hF : 4'h0;
                end
                STAT1: begin
                    cpu_ren    <= 4'h0;
                    inst_valid <= dev_rvalid;
                    inst_out   <= dev_rvalid ? dev_rdata[31:0] : 32'h0;
                end
                default: begin
                    inst_valid <= 1'b0;
                    cpu_ren    <= 4'h0;
                end
            endcase
        end
    end

`endif

endmodule

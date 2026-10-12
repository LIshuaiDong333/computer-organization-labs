`timescale 1ns / 1ps

module axi_master(
    input  wire         aclk,         // AXI 总线时钟信号
    input  wire         areset,       // 异步复位信号，高电平有效

    // === ICache 接口 ===
    output reg          ic_dev_rrdy,   // ICache 上层设备可接收读请求标志
    input  wire         ic_cpu_ren,    // ICache 模块发起的读请求
    input  wire [31:0]  ic_cpu_raddr,  // ICache 模块的读地址（32位）
    output reg          ic_dev_rvalid, // ICache 读数据有效标志
    output reg  [255:0] ic_dev_rdata,  // ICache 读数据（256位）

    // === DCache 读数据接口 ===
    output reg          dc_dev_rrdy,   // DCache 上层设备可接收读请求标志
    input  wire         dc_cpu_ren,    // DCache 模块发起的读请求
    input  wire [31:0]  dc_cpu_raddr,  // DCache 模块的读地址（32位）
    output reg          dc_dev_rvalid, // DCache 读数据有效标志
    output reg  [255:0] dc_dev_rdata,  // DCache 读数据（256位）

    // === DCache 写数据接口 ===
    output reg          dc_dev_wrdy,   // DCache 上层设备可接收写请求标志
    input  wire [ 3:0]  dc_cpu_wen,    // DCache 写入字节掩码（4位，每位对应一个字节）
    input  wire [31:0]  dc_cpu_waddr,  // DCache 模块的写地址（32位）
    input  wire [31:0]  dc_cpu_wdata,  // DCache 写入的数据（32位）

    // === AXI4 主接口 ===
    // 读地址
    output reg  [31:0]  m_axi_araddr,  // 读地址
    output reg  [ 7:0]  m_axi_arlen,   // 突发长度（读时 beats 数 -1）控制猝发传输时连续传输arlen+1个数据包
    output reg  [ 2:0]  m_axi_arsize,  // 传输大小（2: 32-bit）控制猝发传输数据包的大小为2的arsize次幂
    output reg  [ 1:0]  m_axi_arburst, // 突发类型（1: INCR）
    output reg          m_axi_arvalid, // 读地址有效
    input  wire         m_axi_arready, // 从设备就绪信号
    // 读数据
    output wire         m_axi_rready,  // 主设备准备好接收读数据
    input  wire [31:0]  m_axi_rdata,   // 从设备返回的读数据
    input  wire [ 1:0]  m_axi_rresp,   // 读响应类型
    input  wire         m_axi_rlast,   // 突发最后一个数据标志
    input  wire         m_axi_rvalid,  // 读数据有效
    // Write Address Channel
    output reg  [31:0]  m_axi_awaddr,  // 写地址
    output reg  [ 7:0]  m_axi_awlen,   // 突发长度（写时 beats 数 -1）
    output reg  [ 2:0]  m_axi_awsize,  // 传输大小（2: 32-bit）
    output reg  [ 1:0]  m_axi_awburst, // 突发类型（1: INCR）
    output reg          m_axi_awvalid, // 写地址有效
    input  wire         m_axi_awready, // 从设备就绪信号
    // 写数据
    output reg  [31:0]  m_axi_wdata,   // 写数据
    output reg  [ 3:0]  m_axi_wstrb,   // 写数据字节掩码
    output wire         m_axi_wlast,   // 写通道最后一个数据标志
    output reg          m_axi_wvalid,  // 写数据有效
    input  wire         m_axi_wready,  // 从设备就绪信号
    // 写响应
    output reg          m_axi_bready,  // 主设备准备好接收写响应
    input  wire [ 1:0]  m_axi_bresp,   // 写响应类型
    input  wire         m_axi_bvalid   // 写响应有效
);

    // ==== 请求检测信号 ====
    // 检测 DCache 写请求：上层发起且总线空闲
    wire has_dc_wr_req = dc_dev_wrdy & (dc_cpu_wen != 4'h0);
    // 检测 DCache 读请求：上层发起且总线空闲
    wire has_dc_rd_req = dc_cpu_ren & dc_dev_rrdy;
    // 检测 ICache 读请求：上层发起且总线空闲
    wire has_ic_rd_req = ic_cpu_ren & ic_dev_rrdy;
    // 任意读请求
    wire has_rd_req = has_dc_rd_req | has_ic_rd_req;

    // ==== 读控制状态机 ====
    reg [1:0] state;
    localparam IDLE      = 2'b00;       // 空闲状态，等待请求
    localparam AR_SEND   = 2'b01;       // 发出读地址阶段
    localparam DATA_RECV = 2'b10;       // 接收读数据阶段

    // 标记当前处理请求类型：1=DCache，0=ICache
    reg is_dcache_req;

    // 读数据缓冲，用于累积突发数据
    reg [255:0] rdata_buffer;
    // 已接收data beat计数
    reg [2:0] data_count;

    // ICache 地址对齐后的缓存
    reg [31:0] ic_last_addr;

    // === 读地址通道 & 状态机实现 ===
    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            // 复位所有寄存器到初始值
            state           <= IDLE;
            is_dcache_req   <= 1'b0;
            dc_dev_rrdy     <= 1'b1;    
            ic_dev_rrdy     <= 1'b1;
            dc_dev_rvalid   <= 1'b0;
            ic_dev_rvalid   <= 1'b0;
            dc_dev_rdata    <= 256'h0;
            ic_dev_rdata    <= 256'h0;
            m_axi_arvalid   <= 1'b0;
            m_axi_araddr    <= 32'h0;
            m_axi_arlen     <= 8'h0;
            m_axi_arsize    <= 3'h0;
            m_axi_arburst   <= 2'h0;
            ic_last_addr    <= 32'h0;
            rdata_buffer    <= 256'h0;
            data_count      <= 3'h0;
        end else begin
            // 默认清除上层有效信号
            ic_dev_rvalid <= 1'b0;
            dc_dev_rvalid <= 1'b0;

            case (state)
                IDLE: begin
                    // 优先处理 DCache 读请求
                    if (has_dc_rd_req) begin
                        is_dcache_req <= 1'b1;
                        dc_dev_rrdy   <= 1'b0;          // 不再接收新请求
                        // 配置 AXI 读地址通道
                        m_axi_araddr  <= dc_cpu_raddr;     // 设置要读取的起始地址
                        m_axi_arlen   <= 8'h7;             // 突发长度为 7 (共 8 beats)
                        m_axi_arsize  <= 3'h2;             // 每个 beat 传输 4 字节 (32-bit)
                        m_axi_arburst <= 2'h1;             // 突发类型：INCR 模式，地址逐次递增
                        m_axi_arvalid <= 1'b1;             // 发起 AR 通道握手，通知从设备地址有效
                        state         <= AR_SEND;          // 进入发送地址阶段，等待 m_axi_arready
                    end
                    // 如果没有 DCache 读，再检查 ICache
                    else if (has_ic_rd_req) begin
                        is_dcache_req <= 1'b0;
                        ic_dev_rrdy   <= 1'b0;
                        // 对 ICache 读请求进行处理（地址对齐 + AXI 配置）
                        // 将 ICache 请求地址按 4 字节边界对齐
                        m_axi_araddr  <= ic_cpu_raddr & 32'hFFFFFFFC;
                        ic_last_addr  <= ic_cpu_raddr & 32'hFFFFFFFC;  // 对齐后地址供后续偏移计算                      
                        m_axi_arlen   <= 8'h7;  //突发长度：ARLEN=7 → 8 个 beats，满行读取 256 位
                        m_axi_arsize  <= 3'h2;  //传输大小：ARSIZE=2 → 每 beat 传输 4 字节（32 位）
                        m_axi_arburst <= 2'h1;   //突发类型：INCR（地址递增模式），便于连续读取缓存行
                        m_axi_arvalid <= 1'b1;   //发起 AR 通道有效请求，通知从设备地址和控制信息已就绪
                        state         <= AR_SEND;   //状态切换：进入 AR_SEND，等待 m_axi_arready 与之握手  

                    end
                end

                AR_SEND: begin
                    // AXI 地址握手完成，开始接收数据
                    if (m_axi_arvalid && m_axi_arready) begin
                        m_axi_arvalid <= 1'b0;
                        data_count    <= 3'h0;
                        state         <= DATA_RECV;
                    end
                end

                DATA_RECV: begin
                    // 恒定准备接收 AXI 读数据
                    if (m_axi_rvalid && m_axi_rready) begin
                        // 累积当前 beat 的 32 位数据
                        rdata_buffer[data_count*32 +: 32] <= m_axi_rdata;
                        // 判断是否为最后一 beat
                        if (m_axi_rlast) begin
                            // 突发传输结束，输出给上层
                            if (is_dcache_req) begin
                                dc_dev_rdata  <= rdata_buffer;
                                dc_dev_rvalid <= 1'b1;   // 数据有效
                                dc_dev_rrdy   <= 1'b1;   // 接收下次请求
                            end else begin
                                ic_dev_rdata  <= rdata_buffer;
                                ic_dev_rvalid <= 1'b1;
                                ic_dev_rrdy   <= 1'b1;
                            end
                            state <= IDLE;
                        end else begin
                            // 非最后 beat，计数加 1
                            data_count <= data_count + 1;
                        end
                    end
                end

            endcase
        end
    end

    // 始终准备好接收 Read Data
    assign m_axi_rready = areset ? 1'b0 : 1'b1;

    // ******** 以下为写通道逻辑，不做修改 ********
    ///////////////////////////////////////////////////////////////////////////
    // Write Address Channel
    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            m_axi_awaddr  <= 32'h0;
            m_axi_awvalid <= 1'b0;
        end else begin
            if (m_axi_awvalid & m_axi_awready) begin
                m_axi_awvalid <= 1'b0;
                m_axi_awlen   <= 8'h0;
                m_axi_awsize  <= 3'h0;
                m_axi_awburst <= 2'h0;
            end else if (has_dc_wr_req) begin
                m_axi_awaddr  <= dc_cpu_waddr;
                m_axi_awlen   <= 8'h1 - 1;    // 单 beat 写
                m_axi_awsize  <= 3'h2;        // 32-bit
                m_axi_awburst <= 2'h1;        // INCR
                m_axi_awvalid <= 1'b1;
            end
        end
    end

    ///////////////////////////////////////////////////////////////////////////
    // Write Data Channel
    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            m_axi_wdata  <= 32'h0;
            m_axi_wstrb  <= 4'h0;
            m_axi_wvalid <= 1'b0;
        end else begin
            if (m_axi_wvalid & m_axi_wready) begin
                m_axi_wvalid <= 1'b0;
            end else if (has_dc_wr_req) begin
                m_axi_wdata  <= dc_cpu_wdata;
                m_axi_wstrb  <= dc_cpu_wen;
                m_axi_wvalid <= 1'b1;
            end
        end
    end

    assign m_axi_wlast = m_axi_wvalid;  // 单 beat 写，wlast 与 wvalid 相同

    ///////////////////////////////////////////////////////////////////////////
    // Write Response Channel
    always @(posedge aclk or posedge areset) begin
        if (areset) begin
            dc_dev_wrdy <= 1'b1;  // 默认可接收写请求
        end else begin
            if (m_axi_bvalid) begin
                dc_dev_wrdy <= 1'b1;  // 收到写响应后，释放写请求
            end else if (has_dc_wr_req) begin
                dc_dev_wrdy <= 1'b0;  // 正在写，暂不接收新请求
            end
        end
    end

    always @(posedge aclk or posedge areset) begin
        m_axi_bready <= areset ? 1'b0 : 1'b1;  // 恒定准备接收写响应
    end

endmodule
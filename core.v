module regfile (clk, we, raddr1, raddr2, waddr, wdata,
                rdata1, rdata2);

    input  wire clk, we;
    input  wire [4:0] raddr1, raddr2, waddr;
    input  wire [31:0] wdata;
    output wire [31:0] rdata1, rdata2;

    reg [31:0] regs [31:0];

    assign rdata1 = raddr1 == 'b0 ? 32'b0 :
                    raddr1 == waddr && we ? wdata : regs[raddr1];

    assign rdata2 = raddr2 == 'b0 ? 32'b0 :
                    raddr2 == waddr && we ? wdata : regs[raddr2];

    always @ (posedge clk) begin
        if (we) regs[waddr] <= wdata;
    end
endmodule

module alunit (enable, op, a, b, result, resout);
    input wire enable;
    input wire [3:0] op;
    input wire [31:0] a, b;

    output reg [31:0] result;
    output reg resout;

    always @ (enable) begin
        if (!enable) begin
            resout = 'b0;
        end else begin
            case (op)
                4'b0000: begin // ADD
                    result = a + b;
                    resout = 'b1;
                end
                4'b1000: begin // SUB
                    result = a - b;
                    resout = 'b1;
                end
                4'b0001: begin // SLL
                    result = a << b;
                    resout = 'b1;
                end
                4'b0010: begin // SLT
                    result = {31'b0, $signed(a) < $signed(b)};
                    resout = 'b1;
                end
                4'b0011: begin // SLTU
                    result = a < b;
                    resout = 'b1;
                end
                4'b0100: begin // XOR
                    result = a ^ b;
                    resout = 'b1;
                end
                4'b0101: begin // SRL
                    result = a >> b;
                    resout = 'b1;
                end
                4'b1101: begin // SRA
                    result = a >>> b;
                    resout = 'b1;
                end
                4'b0110: begin // OR
                    result = a | b;
                    resout = 'b1;
                end
                4'b0111: begin // AND
                    result = a & b;
                    resout = 'b1;
                end
                default: resout = 'b0;
            endcase
        end
    end
endmodule

module BranchUnit (enable, op, a, b, resout);
    input wire enable;
    input wire [3:0] op;
    input wire [31:0] a, b;

    output reg resout;

    always @ (enable) begin
        if (!enable) begin
            resout = 'b0;
        end else begin
            case (op)
                4'b0000: begin // BEQ
                    resout = a == b;
                end
                4'b0001: begin // BNE
                    resout = a != b;
                end
                4'b0100: begin // BLT
                    resout = $signed(a) < $signed(b);
                end
                4'b0101: begin // BGE
                    resout = $signed(a) >= $signed(b);
                end
                4'b0110: begin // BLTU
                    resout = a < b;
                end
                4'b0111: begin // BGEU
                    resout = a >= b;
                end
                default: resout = 'b0;
            endcase
        end
    end
endmodule

module cpu (clk, reset);
    input wire clk;
    input wire reset;

    reg [31:0] memory [4096:0];
    reg [31:0] pc;
    reg [31:0] ins;
    reg writeenable;

    wire [4:0] readaddr1, readaddr2;
    reg  [4:0] writeaddr;
    reg  [31:0] writedata;
    wire [31:0] readdata1, readdata2;

    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [4:0] rs1;
    wire [4:0] rs2;
    wire [4:0] rd;
    wire [11:0] i_imm;
    wire [19:0] u_imm;

    reg [3:0] op;
    reg [31:0] l_operand, r_operand;

    reg aluenable;
    wire aluout;
    wire [31:0] res;

    reg [11:0] bimm;
    reg branchenable;
    wire branchout;

    reg [1:0] writeback;
    reg [31:0] wbval;

    regfile iregs (
        .clk (clk),
        .we  (writeenable),
        .raddr1 (readaddr1),
        .raddr2 (readaddr2),
        .waddr (writeaddr),
        .wdata (writedata),
        .rdata1 (readdata1),
        .rdata2 (readdata2)
    );

    alunit alu (
        .enable (aluenable),
        .a (l_operand),
        .b (r_operand),
        .result (res),
        .op (op),
        .resout (aluout)
    );

    BranchUnit bu (
        .enable (branchenable),
        .a (l_operand),
        .b (r_operand),
        .op (op),
        .resout (branchout)
    );

    assign opcode = ins[6:0];
    assign rd     = ins[11:7];
    assign funct3 = ins[14:12];
    assign rs1    = ins[19:15];
    assign rs2    = ins[24:20];
    assign funct7 = ins[31:25];
    assign i_imm  = ins[31:20];
    assign u_imm  = ins[31:12];

    assign readaddr1 = rs1;
    assign readaddr2 = rs2;

    integer i;
    always @ (posedge clk) begin

        // -- FETCH --

        if (reset) begin
            pc <= 32'b0;
            writeenable <= 'b0;
            aluenable <= 'b0;
            for (i = 0; i < 32; i = i + 1) begin
                iregs.regs[i] = 32'b0;
            end
        end else begin
            writeenable <= 0;
            ins <= memory[pc];
            pc  <= pc + 1;
        end

        // -- DECODE --

        case (opcode)
            7'b0110011: begin // R
                l_operand = readdata1;
                r_operand = readdata2;
                op = (funct7 >> 2) + funct3;
                aluenable = 'b1;
                writeback = 2'b1;
            end
            7'b0010011: begin // I
                l_operand = readdata1;
                r_operand = i_imm;
                op = funct3;
                aluenable = 'b1;
                writeback = 2'b1;
            end
            7'b0000011: begin // LOAD
                l_operand = readdata1;
                r_operand = i_imm;
                op = 4'b0;
                aluenable = 'b1;
                writeback  = 2'b11;
            end
            7'b0100011: begin // S
                l_operand = readdata1;
                r_operand = { {20{funct7[6]}}, funct7[6:0], rd};
                op = 4'b0;
                aluenable = 'b1;
                writeback = 2'b0;
            end
            7'b0110111: begin // LUI
                l_operand = u_imm << 12;
                r_operand = 32'b0;
                op = 4'b0;
                aluenable = 'b1;
                writeback = 2'b1;
            end
            7'b0010111: begin // AUIPC
                l_operand =  u_imm << 12;
                r_operand = pc-1;
                op = 4'b0;
                aluenable = 'b1;
                writeback = 2'b1;
            end
            7'b1100011: begin // B
                l_operand = readdata1;
                r_operand = readdata2;
                op = {1'b0, funct3};
                bimm = {ins[31], ins[7], ins[30:25], ins[11:8]};
                branchenable = 'b1;
                writeback = 2'b0;
            end
            7'b1101111: begin // JAL
                l_operand = {ins[31], ins[19:12], ins[21:20], ins[30:21], 12'b0};
                r_operand = pc-1;
                op = 4'b0;
                wbval = pc;
                writeback = 2'b10;
                aluenable = 'b1;
            end
            7'b1100111: begin // JALR
                l_operand = readdata1;
                r_operand = i_imm + (pc-1);
                op = 4'b0;
                wbval = pc;
                writeback = 2'b10;
                aluenable = 'b1;
            end
        endcase
    end

    // -- EXECUTE --

    // Integer computations and branch operations happen in ALU/BU

    always @ (branchout) begin
        if (branchout) begin
            pc <= pc + bimm;
        end

        branchenable <= 'b0;
    end

    // -- WRITEBACK --

    always @ (aluout) begin
        if (writeback == 2'b1) begin
            if (aluout) begin
                writeaddr <= rd;
                writedata <= res;
                writeenable <= 'b1;
            end
        end else if (writeback == 2'b10) begin
            writeaddr <= rd;
            writedata <= wbval;
            writeenable <= 'b1;

            if (aluout) begin
                pc <= res;
            end
        end else if (writeback == 2'b11) begin
            if (aluout) begin
                writeaddr <= rd;

                case (funct3)
                    3'b000: writedata <= {{24{memory[res][7]}}, memory[res][7:0]};   // LB
                    3'b001: writedata <= {{16{memory[res][15]}}, memory[res][15:0]}; // LH
                    3'b010: writedata <= memory[res];                                // LW
                    3'b100: writedata <= {24'b0, memory[res][7:0]};                  // LBU
                    3'b101: writedata <= {16'b0, memory[res][15:0]};                 // LHU
                endcase

                writeenable <= 'b1;
            end
        end else begin
            if (aluout) begin
                case (funct3)
                    3'b000: memory[res] <= readdata2[7:0];  // SB
                    3'b001: memory[res] <= readdata2[15:0]; // SH
                    3'b010: memory[res] <= readdata2;       // SW
                endcase
            end
        end

        aluenable <= 'b0;
    end
endmodule
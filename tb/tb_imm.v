`timescale 1ns/1ps

module tb_imm;
  // DUT I/O
  logic [31:0] instr;
  logic [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

  // DUT
  imm_gen dut(
    .instr(instr),
    .imm_i(imm_i), .imm_s(imm_s), .imm_b(imm_b), .imm_u(imm_u), .imm_j(imm_j)
  );

  // -------- Helpers to pack immediates into instruction fields --------
  // Note: We only care about immediate bit placement; other fields are dummies.

  // I-type: imm[11:0] -> instr[31:20]
  function automatic [31:0] pack_I(input integer simm12);
    automatic logic [31:0] ins;
    ins = 32'b0;
    ins[31:20] = simm12[11:0];
    return ins;
  endfunction

  // S-type: imm[11:5] -> [31:25], imm[4:0] -> [11:7]
  function automatic [31:0] pack_S(input integer simm12);
    automatic logic [31:0] ins;
    ins = 32'b0;
    ins[31:25] = simm12[11:5];
    ins[11:7]  = simm12[4:0];
    return ins;
  endfunction

  // B-type: imm[12|10:5|4:1|11] -> [31|30:25|11:8|7], LSB zero implied
  function automatic [31:0] pack_B(input integer simm13);
    // simm13 must be even (bit0 = 0), range [-4096, 4094]
    automatic logic [31:0] ins;
    ins = 32'b0;
    ins[31]    = simm13[12];
    ins[7]     = simm13[11];
    ins[30:25] = simm13[10:5];
    ins[11:8]  = simm13[4:1];
    // bit0 is not stored in instruction (always 0)
    return ins;
  endfunction

  // U-type: imm[31:12] -> [31:12] (low 12 bits zero)
  function automatic [31:0] pack_U(input logic [31:0] uimm32);
    automatic logic [31:0] ins;
    ins = 32'b0;
    ins[31:12] = uimm32[31:12];
    return ins;
  endfunction

  // J-type: imm[20|10:1|11|19:12] -> [31|30:21|20|19:12], LSB zero implied
  function automatic [31:0] pack_J(input integer simm21);
    // simm21 must be even (bit0 = 0), range about ±1 MiB
    automatic logic [31:0] ins;
    ins = 32'b0;
    ins[31]    = simm21[20];
    ins[19:12] = simm21[19:12];
    ins[20]    = simm21[11];
    ins[30:21] = simm21[10:1];
    return ins;
  endfunction

  // Checker
  task automatic check(string name, logic [31:0] got, logic [31:0] exp);
    #1;
    if (got !== exp) begin
      $display("FAIL %s: got=0x%08x exp=0x%08x (instr=0x%08x)", name, got, exp, instr);
      $fatal(1);
    end
  endtask

  initial begin
    $dumpfile("tb_imm.vcd"); $dumpvars(0, tb_imm);

    // -------- I-type tests --------
    // ADDI imm = -1  => 0xFFFF_FFFF
    instr = pack_I(-1);
    check("I imm -1", imm_i, 32'hFFFF_FFFF);

    // ADDI imm = 0x7FF (max positive 12b) => 0x00000FFF? actually 0x000007FF
    instr = pack_I( 2047); // 0x7FF
    check("I imm +2047", imm_i, 32'h000007FF);

    // -------- S-type tests --------
    instr = pack_S(-8);
    check("S imm -8", imm_s, 32'hFFFFFFF8);
    instr = pack_S( 28);
    check("S imm +28", imm_s, 32'h0000001C);

    // -------- B-type tests (even offsets) --------
    instr = pack_B(16);      // +16
    check("B imm +16", imm_b, 32'h00000010);
    instr = pack_B(-4);      // -4
    check("B imm -4", imm_b, 32'hFFFFFFFC);
    instr = pack_B(0);       // 0
    check("B imm 0", imm_b, 32'h00000000);

    // -------- U-type tests (upper 20) --------
    instr = pack_U(32'h12345000);
    check("U imm 0x12345000", imm_u, 32'h12345000);
    instr = pack_U(32'hFFFFF000);
    check("U imm 0xFFFFF000", imm_u, 32'hFFFFF000);

    // -------- J-type tests (even offsets) --------
    instr = pack_J( 2048);   // +2048
    check("J imm +2048", imm_j, 32'h00000800);
    instr = pack_J(-2048);   // -2048
    check("J imm -2048", imm_j, 32'hFFFFF800);

    $display("tb_imm: PASS ✅");
    $finish;
  end
endmodule

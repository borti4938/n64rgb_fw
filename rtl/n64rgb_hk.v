//////////////////////////////////////////////////////////////////////////////////
//
// This file is part of the N64 RGB/YPbPr DAC project.
//
// Copyright (C) 2016-2018 by Peter Bartmann <borti4938@gmail.com>
//
// N64 RGB/YPbPr DAC is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//////////////////////////////////////////////////////////////////////////////////
//
// Company: Circuit-Board.de
// Engineer: borti4938
//
// Module Name:    n64rgb_ctrl
// Project Name:   N64 RGB DAC Mod
// Target Devices: several MaxII & MaxV devices
// Tool versions:  Altera Quartus Prime
// Description:
//   housekeeping for N64RGB mods
//
//////////////////////////////////////////////////////////////////////////////////


module n64rgb_hk (
  input      VCLK,
  input      nRST,
  output reg DRV_RST,

  input CTRL_i,

  input n64_480i,
  input n16bit_mode_t,
  input nVIDeBlur_t,
  input en_IGR_Rst_Func,
  input en_IGR_DeBl_16b_Func,

  output reg n16bit_o,
  output reg nDeBlur_o
);

`include "../vh/igr_params.vh"


// VCLK frequency (NTSC and PAL related to console type; not to video type)
//   - NTSC: ~48.68MHz
//   -  PAL: ~49.66MHz
// CLK_4M is VCLK divided by 2*6
//   - NTSC: ~4.06MHz (~0.247us period)
//   -  PAL: ~4.14MHz (~0.242us period)

reg       CLK_4M      = 1'b0;   // clock with period as described
reg [2:0] div_clk_cnt = 3'b000; // counter to generate a clock devider 2*6

always @(posedge VCLK) begin
  if (div_clk_cnt == 3'b101) begin
    CLK_4M      <= ~CLK_4M;
    div_clk_cnt <= 3'b000;
  end else
    div_clk_cnt <= div_clk_cnt + 1'b1;
end


reg [1:0] rd_state  = 2'b0; // state machine

localparam ST_WAIT4N64 = 2'b00; // wait for N64 sending request to controller
localparam ST_N64_RD   = 2'b01; // N64 request sniffing
localparam ST_CTRL_RD  = 2'b10; // controller response

reg [7:0] wait_cnt     = 8'h0;  // counter for wait state (needs appr. 64us at CLK_4M clock to fill up from 0 to 255)
reg [2:0] ctrl_hist    = 3'h7;
wire      ctrl_negedge =  ctrl_hist[2] & !ctrl_hist[1];
wire      ctrl_posedge = !ctrl_hist[2] &  ctrl_hist[1];

reg [7:0] ctrl_low_cnt = 8'h0;
wire      ctrl_bit     = ctrl_low_cnt < wait_cnt;

reg [15:0] serial_data = 16'h0;
reg  [3:0] data_cnt    =  4'h0;

reg [1:0] n16bit_mode_hist = 2'b11;
reg [1:0] nVIDeBlur_hist = 2'b11;

reg initiate_nrst = 1'b0;

reg nfirstboot = 1'b0;


// controller data bits:
//  0: 7 - A, B, Z, St, Du, Dd, Dl, Dr
//  8:15 - 'Joystick reset', (0), L, R, Cu, Cd, Cl, Cr
// 16:23 - X axis
// 24:31 - Y axis
// 32    - Stop bit
// (bits[0:15] used here)

always @(posedge CLK_4M) begin
  case (rd_state)
    ST_WAIT4N64:
      if (&wait_cnt) begin // waiting duration ends (exit wait state only if CTRL was high for a certain duration)
        rd_state <= ST_N64_RD;
        data_cnt <= 4'h0;
      end
    ST_N64_RD: begin
      if (ctrl_posedge)       // sample data part 1
        ctrl_low_cnt <= wait_cnt;
      if (ctrl_negedge) begin // sample data part 2
        if (!data_cnt[3]) begin  // eight bits read
          serial_data[13:6] <= {ctrl_bit,serial_data[13:7]};
          data_cnt          <= data_cnt + 1'b1;
        end else if (serial_data[13:6] == 8'b10000000) begin // check command
          rd_state <= ST_CTRL_RD;
          data_cnt <=  4'h0;
        end else begin
          rd_state <= ST_WAIT4N64;
        end
      end
    end
    ST_CTRL_RD: begin
      if (ctrl_posedge)       // sample data part 1
        ctrl_low_cnt <= wait_cnt;
      if (ctrl_negedge) begin // sample data part 2
        if (~&data_cnt) begin  // still reading
          data_cnt    <= data_cnt + 1'b1;
          serial_data <= {ctrl_bit,serial_data[15:1]};
        end else begin        // sixteen bits read (analog values of stick not point of interest)
          rd_state <= ST_WAIT4N64;
          if (en_IGR_DeBl_16b_Func)
            case ({ctrl_bit,serial_data[15:1]})
              `IGR_16BITMODE_OFF: n16bit_o <= 1'b1;
              `IGR_16BITMODE_ON: n16bit_o <= 1'b0;
              `IGR_DEBLUR_OFF: nDeBlur_o <= 1'b1;
              `IGR_DEBLUR_ON: nDeBlur_o <= 1'b0;
            endcase
          if (en_IGR_Rst_Func & ({ctrl_bit,serial_data[15:1]} == `IGR_RESET))
              initiate_nrst <= 1'b1;
        end
      end
    end
    default: begin
      rd_state <= ST_WAIT4N64;
    end
  endcase

  if (ctrl_negedge | ctrl_posedge) begin // counter reset
    wait_cnt <= 8'h0;
  end else begin
    if (~&wait_cnt) // saturate counter if needed
      wait_cnt <= wait_cnt + 1'b1;
    else            // counter saturated
      rd_state <= ST_WAIT4N64;
  end

  if (^n16bit_mode_hist)
    n16bit_o  <= n16bit_mode_t;
  
  if (^nVIDeBlur_hist)
    nDeBlur_o <= nVIDeBlur_t;

  ctrl_hist <= {ctrl_hist[1:0],CTRL_i};
  n16bit_mode_hist <= {n16bit_mode_hist[0],n16bit_mode_t};
  nVIDeBlur_hist <= {nVIDeBlur_hist[0],nVIDeBlur_t};

  if (!nRST) begin
    rd_state      <= ST_WAIT4N64;
    wait_cnt      <= 8'h0;
    ctrl_hist     <= 3'h7;
    initiate_nrst <= 1'b0;
  end

  if (!nfirstboot) begin
    nfirstboot <= 1'b1;
    nDeBlur_o <= nVIDeBlur_t;
    n16bit_o <=  n16bit_mode_t;
    n16bit_mode_hist <= {2{n16bit_mode_t}};
    nVIDeBlur_hist <= {2{nVIDeBlur_t}};
  end
end


reg [17:0] rst_cnt = 18'b0; // ~65ms are needed to count from max downto 0 with CLK_4M.

always @(posedge CLK_4M) begin
  if (initiate_nrst == 1'b1) begin
    DRV_RST <= 1'b1;      // reset system
    rst_cnt <= 18'h3ffff;
  end else if (|rst_cnt) // decrement as long as rst_cnt is not zero
    rst_cnt <= rst_cnt - 1'b1;
  else
    DRV_RST <= 1'b0; // end of reset
end

endmodule

//////////////////////////////////////////////////////////////////////////////////
//
// This file is part of the N64 RGB/YPbPr DAC project.
//
// Copyright (C) 2015-2022 by Peter Bartmann <borti4938@gmail.com>
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
// Company:  Circuit-Board.de
// Engineer: borti4938
//
// Module Name:    n64_vinfo_ext
// Project Name:   N64 RGB DAC Mod
// Target Devices: universial
// Tool versions:  Altera Quartus Prime
// Description:    extracts video info from input
//
//////////////////////////////////////////////////////////////////////////////////


module n64_vinfo_ext(
  VCLK,
  nRST,
  nDSYNC,

  Sync_pre,
  Sync_cur,

  vinfo_o
);

`include "../lib/n64rgb_params.vh"

input VCLK;
input nRST;
input nDSYNC;

input  [3:0] Sync_pre;
input  [3:0] Sync_cur;

output [1:0] vinfo_o;   // order: palmode,n64_480i


// some pre-assignments

wire negedge_nVSYNC =  Sync_pre[3] & !Sync_cur[3];
wire negedge_nHSYNC =  Sync_pre[1] & !Sync_cur[1];



// estimation of 240p/288p
// =======================

reg field_id  = 1'b1; // 0 = even frame, 1 = odd frame; 240p: only even or only odd frames; 480i: even and odd frames
reg n64_480i  = 1'b1; // 0 = 240p/288p , 1= 480i/576i

always @(posedge VCLK or negedge nRST)
  if (!nRST) begin
    field_id  <= 1'b1;
    n64_480i <= 1'b1;
  end else if (!nDSYNC) begin
    if (negedge_nVSYNC) begin 
      field_id <= negedge_nHSYNC;
      n64_480i <= field_id ^ negedge_nHSYNC;
    end
  end


// determine vmode and blurry pixel position
// =========================================

reg [1:0] line_cnt = 2'b00; // PAL: line_cnt[1:0] == 0x ; NTSC: line_cnt[1:0] = 1x
reg        palmode = 1'b0;  // PAL: palmode == 1        ; NTSC: palmode == 0

always @(posedge VCLK or negedge nRST)
  if (!nRST) begin
    line_cnt <= 2'b00;
    palmode  <= 1'b0;
  end else if (!nDSYNC) begin
    if(negedge_nVSYNC) begin // reset line_cnt and set palmode
      line_cnt <= 2'b00;
      palmode  <= ~line_cnt[1];
    end else if(negedge_nHSYNC) // new line -> increase line_cnt
      line_cnt <= line_cnt + 1'b1;
  end


// pack vinfo_o vector
// ===================

assign vinfo_o = {palmode,n64_480i};

endmodule 
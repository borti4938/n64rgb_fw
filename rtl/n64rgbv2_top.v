//////////////////////////////////////////////////////////////////////////////////
//
// This file is part of the N64 RGB/YPbPr DAC project.
//
// Copyright (C) 2016-2022 by Peter Bartmann <borti4938@gmail.com>
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
// (initial design file by Ikari_01)
//
// Module Name:    n64rgbv2_top
// Project Name:   N64 RGB DAC Mod
// Target Devices: several MaxII & MaxV devices
// Tool versions:  Altera Quartus Prime
//
// Description:
//
// short description of N64s RGB and sync data demux
// -------------------------------------------------
//
// pulse shapes and their realtion to each other:
// VCLK (~50MHz, Numbers representing posedge count)
// ---. 3 .---. 0 .---. 1 .---. 2 .---. 3 .---
//    |___|   |___|   |___|   |___|   |___|
// nDSYNC (~12.5MHz)                           .....
// -------.       .-------------------.
//        |_______|                   |_______
//
// more info: http://members.optusnet.com.au/eviltim/n64rgb/n64rgb.html
//
//
//////////////////////////////////////////////////////////////////////////////////


module n64rgbv2_top (
  // N64 Video Input
  VCLK,
  nDSYNC,
  D_i,

  // Controller and Reset
  nRST_io,
  CTRL_i,
  

  // Jumper
  nSYNC_ON_GREEN,
  n16bit_mode_t,
  nVIDeBlur_t,
  en_IGR_Rst_Func,
  en_IGR_DeBl_16b_Func,

  // Video output
  nHSYNC,
  nVSYNC,
  nCSYNC,
  nCLAMP,

  R_o,     // red data vector
  G_o,     // green data vector
  B_o,     // blue data vector

  CLK_ADV712x,
  nCSYNC_ADV712x,
  nBLANK_ADV712x,
  
  dummy_i
);


`include "../lib/n64rgb_params.vh"

input                   VCLK;
input                   nDSYNC;
input [color_width-1:0] D_i;

inout nRST_io;
input CTRL_i;

input  nSYNC_ON_GREEN;

input n16bit_mode_t;
input nVIDeBlur_t;
input en_IGR_Rst_Func;
input en_IGR_DeBl_16b_Func;

output reg nHSYNC;
output reg nVSYNC;
output reg nCSYNC;
output reg nCLAMP;

output reg [color_width:0] R_o;
output reg [color_width:0] G_o;
output reg [color_width:0] B_o;

output reg CLK_ADV712x;
output reg nCSYNC_ADV712x;
output reg nBLANK_ADV712x;

input [4:0] dummy_i;

// start of rtl

wire DRV_RST, n16bit_mode_o, nDeBlur_o;
wire nRST_int = nRST_io;
wire [3:0] vinfo_pass;
wire [`VDATA_FU_SLICE] vdata_r[0:1];


// housekeeping
// ============

n64rgb_hk hk_u(
  .VCLK(VCLK),
  .nRST(nRST_int),
  .DRV_RST(DRV_RST),
  .CTRL_i(CTRL_i),
  .n64_480i(vinfo_pass[0]),
  .n16bit_mode_t(n16bit_mode_t),
  .nVIDeBlur_t(nVIDeBlur_t),
  .en_IGR_Rst_Func(en_IGR_Rst_Func),
  .en_IGR_DeBl_16b_Func(en_IGR_DeBl_16b_Func),
  .n16bit_o(n16bit_mode_o),
  .nDeBlur_o(nDeBlur_o)
);


// acquire vinfo
// =============

n64_vinfo_ext get_vinfo(
  .VCLK(VCLK),
  .nDSYNC(nDSYNC),
  .Sync_pre(vdata_r[0][`VDATA_SY_SLICE]),
  .Sync_cur(D_i[3:0]),
  .vinfo_o(vinfo_pass)
);


// video data demux
// ================

n64_vdemux video_demux(
  .VCLK(VCLK),
  .nDSYNC(nDSYNC),
  .D_i(D_i),
  .demuxparams_i({vinfo_pass[3:1],nDeBlur_o,n16bit_mode_o}),
  .vdata_r_0(vdata_r[0]),
  .vdata_r_1(vdata_r[1])
);


// assign final outputs
// ====================

assign nRST_io = DRV_RST ? 1'b0 : 1'bz;

always @(*) begin
  {nVSYNC,nCLAMP,nHSYNC,nCSYNC} <=  vdata_r[1][`VDATA_SY_SLICE];
   R_o                          <= {vdata_r[1][`VDATA_RE_SLICE],vdata_r[1][3*color_width-1]};
   G_o                          <= {vdata_r[1][`VDATA_GR_SLICE],vdata_r[1][2*color_width-1]};
   B_o                          <= {vdata_r[1][`VDATA_BL_SLICE],vdata_r[1][  color_width-1]};

  CLK_ADV712x    <= VCLK;
  nCSYNC_ADV712x <= nSYNC_ON_GREEN ? 1'b0 : vdata_r[1][vdata_width-4];
  nBLANK_ADV712x <= 1'b1;
end

endmodule

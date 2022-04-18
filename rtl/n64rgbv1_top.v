//////////////////////////////////////////////////////////////////////////////////
//
// This file is part of the N64 RGB/YPbPr DAC project.
//
// Copyright (C) 2016-2020 by Peter Bartmann <borti4938@gmail.com>
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
// Module Name:    n64rgbv1_top
// Project Name:   N64 RGB DAC Mod
// Target Devices: several MaxII & MaxV devices
// Tool versions:  Altera Quartus Prime
//
// Revision: 3.0
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

`define N0_VIDEO_PIPELINE_RESET

module n64rgbv1_top (
  // N64 Video Input
  VCLK,
  nDSYNC,
  D_i,

  // Controller and Reset
  nRST_io,
  CTRL_i,
  

  // Jumper
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

  // Filter control of THS7374
  nTHS7374_LPF_Bypass_p85_i,   // my first prototypes have FIL pad input at pin 85 (MaxV only)
  nTHS7374_LPF_Bypass_p98_i,   // the GitHub final version at pin 98
  THS7374_LPF_Bypass_o         // so simply combine both for same firmware file
);


`include "../lib/n64rgb_params.vh"

input                   VCLK;
input                   nDSYNC;
input [color_width-1:0] D_i;

inout nRST_io;
input CTRL_i;

input n16bit_mode_t;
input nVIDeBlur_t;
input en_IGR_Rst_Func;
input en_IGR_DeBl_16b_Func;

output nHSYNC;
output nVSYNC;
output nCSYNC;
output nCLAMP;

output [color_width-1:0] R_o;
output [color_width-1:0] G_o;
output [color_width-1:0] B_o;

input  nTHS7374_LPF_Bypass_p85_i;   // my first prototypes have FIL pad input at pin 85 (MaxV only)
input  nTHS7374_LPF_Bypass_p98_i;   // the GitHub final version at pin 98
output  THS7374_LPF_Bypass_o;       // so simply combine both for same firmware file


// start of rtl

wire DRV_RST, n16bit_mode_o, nDeBlur_o;
wire nRST_hk, nRST_video;
wire palmode, n64_480i;
wire [`VDATA_SY_SLICE] vdata_sy;

assign nRST_hk = nRST_io;
`ifdef N0_VIDEO_PIPELINE_RESET
  assign nRST_video = 1'b1;
`else
  assign nRST_video = nRST_io;
`endif

// housekeeping
// ============

n64rgb_hk hk_u(
  .VCLK(VCLK),
  .nRST(nRST_hk),
  .DRV_RST(DRV_RST),
  .CTRL_i(CTRL_i),
  .n64_480i(n64_480i),
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
  .nRST(nRST_video),
  .nDSYNC(nDSYNC),
  .Sync_pre(vdata_sy),
  .Sync_cur(D_i[3:0]),
  .vinfo_o({palmode,n64_480i})
);


// video data demux
// ================

n64_vdemux video_demux(
  .VCLK(VCLK),
  .nRST(nRST_video),
  .nDSYNC(nDSYNC),
  .D_i(D_i),
  .demuxparams_i({palmode,nDeBlur_o,n16bit_mode_o}),
  .vdata_sy_0_o(vdata_sy),
  .vdata_1_o({nVSYNC,nCLAMP,nHSYNC,nCSYNC,R_o,G_o,B_o})
);


// assign final outputs
// ====================

assign nRST_io = DRV_RST ? 1'b0 : 1'bz;
assign THS7374_LPF_Bypass_o = ~(nTHS7374_LPF_Bypass_p85_i & nTHS7374_LPF_Bypass_p98_i);

endmodule

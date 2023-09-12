// SPDX-License-Identifier: BSD-3-Clause
/*
 * Asynchronous Reset with metastability compensation
 *
 * Copyright (C) 2023 Luís Mendes
 */
module AsyncMetaReset (input clk, input rstIn, output rstOut);

reg a = 1'b1, b = 1'b0;

always @(posedge clk)
begin
   if (rstIn)
   begin
      a <= 1'b0;
      b <= 1'b0;
   end
   else   
   begin
      b <= a;
      a <= 1'b1;
   end   
end

assign rstOut = b;

endmodule

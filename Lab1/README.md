1. Show the code that you use to program configuration address [‘h3000_5000]

* soc side (refer to soc_up_cfg_write)
```verilog=
begin
  @ (posedge soc_coreclk);
  wbs_adr <= 32'h3000_5000;

  wbs_wdata <= 32'b1;
  wbs_sel <= 4'b1;
  wbs_cyc <= 1'b1;
  wbs_stb <= 1'b1;
  wbs_we <= 1'b1;

  @(posedge soc_coreclk);
  while(wbs_ack==0) begin
    @(posedge soc_coreclk);
end
```
* fpga side (refer to test006_fpga_to_soc_cfg_read)
```verilog=
begin
@ (posedge fpga_coreclk);
    fpga_axilite_write_req(28'h5000, 4'b1, 32'b1);
repeat(100)@(posedge soc_coreclk);
end
```
2. Briefly describe how you do FIR initialization (tap parameter, length) from SOC side (Test#1).

    For programming data length and tape parameter, use **soc_up_cfg_write(addr[11:0], write_enable, data).**
3. Briefly describe how you do FIR initialization (tap parameter, length) from FPGA side (Test#2).

    1. Same as change user project form fpga side, use **fpga_axilite_write_req(addr[27:0], write_enable, data)**;
    
    2. To ensure fpga write to soc is completed, use **repeat(100)@(posedge soc_coreclk)**.

4. Briefly describe how you feed in X data from FPGA side.
    1.	When fpga_coreclk at posedge, set **fpga_as_is_tready = 1**.
    2.	Use **fpga_axis_req(i, TID_DN_UP, 0)** in for loop from **i = 0 ~ 63**.

5. Briefly describe how you get output Y data in testbench, and how to do comparison with golden values.

    In **task fpga_axis_req**, change tdata to golden output to store correct answer in:
    ```verilog
    soc_to_fpga_axis_expect_value[] <= {tupsb, tstrb, tkeep, tlast, tdata};
    ```

    Through the **initial block** at line 1100 in the testbench, the result calculated by fir can be sent to the **soc_to_fpga_axis_captured[]**.

    After the last data of y is received, the event **soc_to_fpga_axis_event** is triggered, and then **soc_to_fpga_axis_captured[]** is compared with **soc_to_fpga_axis_expect_value[]**.
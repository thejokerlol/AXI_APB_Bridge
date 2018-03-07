@echo off
set xv_path=C:\\Xilinx\\Vivado\\2015.2\\bin
call %xv_path%/xsim AXI2APB_TestBench_behav -key {Behavioral:sim_1:Functional:AXI2APB_TestBench} -tclbatch AXI2APB_TestBench.tcl -view C:/Users/vamsi/Desktop/2nd_presentation_code/AXI_APB_Bridge/AXI2APB_TestBench_behav.wcfg -log simulate.log
if "%errorlevel%"=="0" goto SUCCESS
if "%errorlevel%"=="1" goto END
:END
exit 1
:SUCCESS
exit 0

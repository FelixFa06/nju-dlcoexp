# 非工程（batch）仿真：编译 lab 源码 + sim/ 下 testbench → 跑仿真 → 导出 build/top.vcd
# 用法：在某个 lab 目录下执行  vivado -mode batch -source <本文件绝对路径>
set BUILD_DIR ./build
file mkdir $BUILD_DIR

set vfiles [concat [glob ./*.v] [glob ./sim/*.v]]

exec xvlog {*}$vfiles
exec xelab -debug typical -timescale 1ns/1ps -s sim_snapshot tb_top
exec xsim sim_snapshot -R >@stdout

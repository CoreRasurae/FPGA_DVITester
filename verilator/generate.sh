verilator -cc ../common/RGBSigGen.v
verilator -Wall --trace -cc ../common/RGBSigGen.v --exe tb_RGBSigGen.cpp --timescale-override 1ns/1ns
make -C obj_dir -f VRGBSigGen.mk VRGBSigGen
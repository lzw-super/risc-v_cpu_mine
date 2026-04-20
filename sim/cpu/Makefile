# ==============================
# CPU模块 VCS + Verdi 联合仿真 Makefile
# ==============================

# 工具路径（如已加入环境变量 PATH，可省略）
VCS     = vcs
VERDI   = verdi

# 文件列表
SRC_FILES = filelist.f

# 编译选项
VCS_COMPILE_OPTS = \
	-full64 \
	-sverilog \
	-timescale=1ns/1ps \
	-LDFLAGS -Wl,--no-as-needed \
	+define+FSDB \
	-debug_acc+all \
	-kdb \
	-fsdb \
	-l compile.log

# 仿真选项
VCS_RUN_OPTS = \
	-l sim.log

# 默认目标
.PHONY: all compile simulate view clean

all: compile simulate

# 编译设计
compile:
	$(VCS) $(VCS_COMPILE_OPTS) -f $(SRC_FILES)

# 运行仿真（启用 FSDB）
simulate: compile
	./simv $(VCS_RUN_OPTS)

# 启动 Verdi 查看波形
view:
	$(VERDI) -ssf wave.fsdb &

# 清理生成文件
clean:
	rm -rf simv* csrc/ vc_hdrs.h ucli.key urgReport/ *.log *.fsdb *.daidir *.vpd DVEfiles/
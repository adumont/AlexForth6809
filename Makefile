# AlexForth for 6809
# Copyright (C) 2023 Alexandre Dumont <adumont@gmail.com>
# SPDX-License-Identifier: GPL-3.0-only

.DEFAULT_GOAL := run

%.bin: %.s
	python helpers/macros.py < $< > $<.tmp && \
	asm6809 $<.tmp -8 -P 10 --bin -o $@ -l $(basename $@).lst -s $(basename $@).lbl

run: forth.bin
	cp forth.bin ../emu6809/ && make -C ../emu6809/

clean:
	-rm *.bin *.lbl *.lst

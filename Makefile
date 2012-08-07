SRC=ASMBot.s
EXE=a.out

all:
	as $(SRC) -g3 -o $(SRC:.s=.o) --32 && ld $(SRC:.s=.o) -o $(EXE) -melf_i386

.PHONY: all

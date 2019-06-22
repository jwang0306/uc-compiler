CC=gcc
FNAME=uc_compiler
EXE=myscanner

compile: scanner
	@${CC} lex.yy.c -o ${EXE}

scanner: 
	@lex ${FNAME}.l

basic_test: compile
	@./${EXE} < ./example_input/input/basic_function.c

clean:
	@rm ${EXE} lex.*

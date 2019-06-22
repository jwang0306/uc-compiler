CC=gcc
YFLAG=-d -v
FNAME=uc_compiler
EXE=myparser

compile: scanner parser
	${CC} lex.yy.c y.tab.c -o ${EXE}

scanner:
	lex ${FNAME}.l

parser: 
	yacc ${YFLAG} ${FNAME}.y

test: compile
	./${EXE} < input/zero_error.c

clean:
	rm ${EXE} y.tab* lex.* y.output
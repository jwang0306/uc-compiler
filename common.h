#ifndef _COMMON_H_
#define _COMMON_H_

#define CODE_BUF_SIZE 256
#define MAX_STACK_SIZE 256
#define MAX_PARAM_SIZE 10
#define SYMBOL_BUF_SIZE 30
#define FNAME "uc_compiler"

typedef enum {
	VOID_t, INT_t, FLOAT_t, STRING_t, BOOL_t
} CTYPE;

typedef enum {
    ASGN_t, ADDASGN_t, SUBASGN_t, MULASGN_t, DIVASGN_t, MODASGN_t,
    INC_t, DEC_t
} ASSGN_TYPE;

typedef enum {
    EQ_t, NE_t, LTE_t, MTE_t, LT_t, MT_t
} CONDITION_TYPE;

#endif
/*	Definition section */
%{

/* include header */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "common.h"

/* stack (to maintain label) */
int stack[MAX_STACK_SIZE];
int TOS = -1; // top of stack
bool stackIsEmpty();
void pushStack(int); 
int popStack();

/* externed functions or flags */
extern char* yytext; // Get current token from lex
extern char buf[CODE_BUF_SIZE]; // Get current code line from lex
extern int yylineno;
extern int yylex();
extern int dump_scope;
extern int global_scope;
extern int global_register_num;
extern bool dump_that_shit;
extern bool has_syntax_error;
extern bool is_divide;
extern void printErrorMsg();

/* To generate .j file for Jasmin */
FILE *file; 

/* To raise error */
void yyerror(char *s);

/* Symbol Table */
typedef struct symbol_table *table_ptr_t;
struct symbol_table {
	int index;
	int register_num;
	char name[SYMBOL_BUF_SIZE];
	char kind[SYMBOL_BUF_SIZE]; // function, variable, parameter
	CTYPE type;
	int scope;
	bool declared;
	bool declared_and_defined;
	CTYPE param_list[MAX_PARAM_SIZE];
	int param_count;
	table_ptr_t next;
	table_ptr_t prev;
};

/* flag for parsing */
table_ptr_t table_head;
int global_index = 0;
int global_total_symbol = 0;
int global_num_params = 0;
bool is_function = false;
bool is_func_declaration = false;
char data_type[SYMBOL_BUF_SIZE];
char function_type[SYMBOL_BUF_SIZE];
CTYPE global_param_list[MAX_PARAM_SIZE];
CTYPE global_argument_list[MAX_PARAM_SIZE];
char errormsg[CODE_BUF_SIZE];
char errormsg2[CODE_BUF_SIZE];
bool has_other_error = false;
bool has_func_param_error = false;

/* flag for code deneration */
char jasm_buf[CODE_BUF_SIZE];
bool stop_gencode = false;
bool declared_with_val = false;
bool is_func_call = false;
bool is_print = false;
bool is_while = false;
bool is_condition = false;
bool is_return = false;
bool meet_assign_symbol = false;
bool has_unary_op = false;
int RHS_var_count = 0;
int if_while_label = -1;
CTYPE func_type;
int global_argument_count = 0;
table_ptr_t function_call_symbol;

/* Symbol table functions */
int lookupSymbol(char* name, int scope);
void createSymbol(char* name, char* kind, CTYPE type, int scope);
void insertSymbol(char* name, char* kind, CTYPE type, int scope);
void dumpSymbol(int scope);
int searchDumpable(int scope);
void deleteParams(int num);
void replaceSymbol(char* name, char* kind, CTYPE type, int scope);
bool checkIfDeclared(char* name, char* kind, int scope);
void printSymbolTable();
char* type2String(CTYPE type);
char* type2Jasmin(CTYPE type);
table_ptr_t getSymbol(char* name, int scope);
CTYPE getSymbolType(char* name, int scope);
void cleanGlobalParamList();
void cleanArgumentList();
table_ptr_t initSymbol(table_ptr_t symbol);
void raiseSemanticError(char* msg);
void raiseFunctionParamSE(char* msg);

/* code generation functions */
void gencode(char* s);
void gencodeStore(table_ptr_t symbol);
void gencodeLoad(table_ptr_t symbol);
void gencodeGlobalVar(CTYPE type, char* name);
void gencodeLocalVar(CTYPE typeLHS, CTYPE typeRHS, char* name);
CTYPE gencodeArithmetic(CTYPE typeLHS, CTYPE typeRHS, ASSGN_TYPE asgn_type);
void gencodePostfixExpression(ASSGN_TYPE postfix_type, table_ptr_t symbol);
void gencodeAssignExpression(ASSGN_TYPE asgn_type, table_ptr_t symbol, CTYPE typeRHS);
void gencodePrintStatement(CTYPE type);
void gencodeReturnStatement(CTYPE function_type, CTYPE return_type);
void gencodeFunctionCalling(table_ptr_t symbol, int num_args);
void gencodeArgumentCasting(CTYPE param_type, CTYPE arg_type);
void gencodeRelationalExpression(CTYPE typeLHS, CTYPE typeRHS, CONDITION_TYPE cond_type);

%}

%union {
	struct {
		int i_val;
		float f_val;
		char* id;
		CTYPE type;
		ASSGN_TYPE asgn_type;
		CONDITION_TYPE cond_type;
	} yytype;
}

/* Token without return */
%token PRINT
%token IF ELSE FOR WHILE
%token SEMICOLON
%token NEWLINE

/* Arithmetic */
%token ADD SUB MUL DIV MOD INC DEC

/* Relational */
%token MT LT MTE LTE EQ NE

/* Assignment */
%token ASGN ADDASGN SUBASGN MULASGN DIVASGN MODASGN

/* Logical */
%token AND OR NOT

/* Delimiters */
%token LB RB LCB RCB LSB RSB COMMA

 /* return Keywords */
%token RETURN CONT BREAK

/* main function keword */
%token MAIN

/* Token with return, which need to sepcify type */
%token <yytype> ID
%token <yytype> I_CONST
%token <yytype> F_CONST
%token <yytype> STR_CONST
%token <yytype> STRING
%token <yytype> BOOL
%token <yytype> VOID
%token <yytype> INT
%token <yytype> FLOAT
%token <yytype> TRUE
%token <yytype> FALSE

/* Nonterminal with return, which need to sepcify type */
%type <yytype> constant string function_definition direct_declarator init_declarator init_declarator_list declarator type_specifier external_declaration declaration
%type <yytype> declaration_specifiers parameter_type_list parameter_declaration
%type <yytype> primary_expression postfix_expression unary_expression cast_expression assignment_expression expression mul_expression
%type <yytype> add_expression relational_expression equality_expression and_expression exclusive_or_expression initializer
%type <yytype> inclusive_or_expression logical_and_expression logical_or_expression conditional_expression declaration_assignment_operator
%type <yytype> assignment_operator argument_expression_list constant_expression jump_statement iteration_statement print_func unary_operator
%right then ELSE // Same precedence, but "shift" wins.

/* Yacc will start at this nonterminal */
%start program

/* Grammar section */
%%

program
	: external_declaration 
	| program external_declaration
	| error
	;

primary_expression
	: ID {
		if (lookupSymbol($1.id, global_scope) == -1) {
			sprintf(errormsg, "%s %s %s", "Undeclared", "variable", $1.id);
			raiseSemanticError(errormsg);
		}

		// sprintf($$.id, "%s", $1.id);
		$1.type = getSymbolType($1.id, global_scope); // find type from symbol table
		$$ = $1;

		if (meet_assign_symbol || is_func_call || is_while || is_print || is_condition || is_return) {
			gencodeLoad(getSymbol($$.id, global_scope));
		}
	}
	| constant { $$ = $1; }
	| string { $$ = $1; }
	| LB expression RB { $$ = $2; }
	;

constant
	: I_CONST {
		if (has_unary_op) {
			yylval.yytype.i_val *= -1;
			has_unary_op = false;
		}
		$1.type = INT_t;
		$$ = $1;

		if (global_scope > 0 && meet_assign_symbol || is_func_call || is_while || is_print || is_condition || is_return) {
			sprintf(jasm_buf, "\tldc %d\n", yylval.yytype.i_val); 
			gencode(jasm_buf);
		}

		if (is_divide)
			RHS_var_count++;
	}
	| F_CONST {
		if (has_unary_op) {
			yylval.yytype.f_val *= -1;
			has_unary_op = false;
		}

		$1.type = FLOAT_t;
		$$ = $1;

		if (global_scope > 0 && meet_assign_symbol || is_func_call || is_while || is_print || is_condition || is_return) {
			sprintf(jasm_buf, "\tldc %f\n", yylval.yytype.f_val); 
			gencode(jasm_buf);
		}

		if (is_divide)
			RHS_var_count++;
	}
	| TRUE {
		if (has_unary_op) {
			yylval.yytype.i_val *= -1;
			has_unary_op = false;
		}

		$1.type = BOOL_t;
		$$ = $1;

		if (global_scope > 0 && meet_assign_symbol || is_func_call || is_while || is_condition || is_return) {
			sprintf(jasm_buf, "\tldc 1\n");
			gencode(jasm_buf);
		}
	}
	| FALSE {
		if (has_unary_op) {
			yylval.yytype.i_val *= -1;
			has_unary_op = false;
		}

		$1.type = BOOL_t;
		$$ = $1;

		if (global_scope > 0 && meet_assign_symbol || is_func_call || is_while || is_condition || is_return) {
			sprintf(jasm_buf, "\tldc 0\n");
			gencode(jasm_buf);
		}
	}
	;

string
	: STR_CONST {
		$1.type = STRING_t;
		$$ = $1;
		
		if (global_scope > 0 && meet_assign_symbol || is_func_call || is_print || is_return) {
			sprintf(jasm_buf, "\tldc \"%s\"\n", yylval.yytype.id);
			gencode(jasm_buf);
		}
	}
	;

expression
	: assignment_expression  { 
		$$ = $1;
	}
	| expression COMMA assignment_expression
	;

postfix_expression
	: primary_expression { $$ = $1; }
	| postfix_expression LSB expression RSB
	| postfix_expression LB { is_func_call = true; } RB {
		/*************** FUNCTION CALL (without args) ******************/
		if (lookupSymbol($1.id, global_scope) == -1) {
			sprintf(errormsg, "%s %s", "Undeclared function", $1.id);
			raiseSemanticError(errormsg);
		}

		gencodeFunctionCalling(getSymbol($1.id, global_scope), 0);

		is_func_call = false;
	}
	| postfix_expression LB { is_func_call = true; function_call_symbol = getSymbol($1.id, global_scope); } argument_expression_list RB {
		/*************** FUNCTION CALL (with args) ******************/
		if (lookupSymbol($1.id, global_scope) == -1) {
			sprintf(errormsg, "%s %s", "Undeclared function", $1.id);
			raiseSemanticError(errormsg);
		}

		gencodeFunctionCalling(getSymbol($1.id, global_scope), global_argument_count);

		is_func_call = false;
	}
	| postfix_expression INC {
		gencodePostfixExpression(INC_t, getSymbol($1.id, global_scope));
	}
	| postfix_expression DEC {
		gencodePostfixExpression(DEC_t, getSymbol($1.id, global_scope));
	}
	| LB type_name RB LCB initializer_list RCB { }
	| LB type_name RB LCB initializer_list COMMA RCB { }
	;

argument_expression_list
	: assignment_expression {
		$$ = $1;

		// count #argument and record its type
		global_argument_list[global_argument_count] = $1.type;
		global_argument_count++;

		/*************** CAST ARGUMENT *****************/
		gencodeArgumentCasting(function_call_symbol->param_list[global_argument_count-1], $1.type);
		
	}
	| argument_expression_list COMMA assignment_expression {
		// count #argument and record its type
		global_argument_list[global_argument_count] = $3.type;
		global_argument_count++;

		/*************** CAST ARGUMENT *****************/
		gencodeArgumentCasting(function_call_symbol->param_list[global_argument_count-1], $3.type);
	}
	;

assignment_expression
	: conditional_expression { $$ = $1; }
	| unary_expression  assignment_operator assignment_expression {
		if (is_divide && RHS_var_count == 1 && ($3.i_val == 0 || $3.f_val == 0))
			raiseSemanticError("Divide by zero");
		// printf("[ /= ] RHS_var_count=%d, value=%d\n", RHS_var_count, $3.i_val);
		is_divide = false;
		RHS_var_count = 0;

		gencodeAssignExpression($2.asgn_type, getSymbol($1.id, global_scope), $3.type);

		// close meet_assign_symbol, to indicate an assign is over
		meet_assign_symbol = false; 
	}
	;

conditional_expression
	: logical_or_expression  { $$ = $1; }
	;

unary_expression
	: postfix_expression { $$ = $1; }
	| INC unary_expression { 
		gencodePostfixExpression(INC_t, getSymbol($2.id, global_scope));
	}
	| DEC unary_expression {
		gencodePostfixExpression(DEC_t, getSymbol($2.id, global_scope));
	}
	| unary_operator cast_expression { }
	;

unary_operator
	: ADD { }
	| SUB { has_unary_op = true; }
	| NOT { has_unary_op = true; }
	;

cast_expression
	: unary_expression { $$ = $1; }
	| LB type_name RB cast_expression { }
	;

mul_expression
	: cast_expression { 
		$$ = $1;
	}
	| mul_expression MUL cast_expression {
		$$.type = gencodeArithmetic($1.type, $3.type, MULASGN_t);
	}
	| mul_expression DIV cast_expression {
		if (is_divide && RHS_var_count == 1 && ($3.i_val == 0 || $3.f_val == 0))
			raiseSemanticError("Divide by zero");
		is_divide = false;
		RHS_var_count = 0;
		$$.type = gencodeArithmetic($1.type, $3.type, DIVASGN_t);
	}
	| mul_expression MOD cast_expression {
		$$.type = gencodeArithmetic($1.type, $3.type, MODASGN_t);
	}
	;

add_expression
	: mul_expression { $$ = $1; }
	| add_expression ADD mul_expression {
		$$.type = gencodeArithmetic($1.type, $3.type, ADDASGN_t);
	}
	| add_expression SUB mul_expression {
		$$.type = gencodeArithmetic($1.type, $3.type, SUBASGN_t);
	}
	;

relational_expression
	: add_expression {
		$$ = $1;
	}
	| relational_expression LT add_expression {
		gencodeRelationalExpression($1.type, $3.type, LT_t);
		$$.cond_type = LT_t; 
	}
	| relational_expression MT add_expression {
		gencodeRelationalExpression($1.type, $3.type, MT_t);
		$$.cond_type = MT_t;
	}
	| relational_expression LTE add_expression {
		gencodeRelationalExpression($1.type, $3.type, LTE_t);
		$$.cond_type = LTE_t;
	}
	| relational_expression MTE add_expression {
		gencodeRelationalExpression($1.type, $3.type, MTE_t);
		$$.cond_type = MTE_t;
	}
	;

equality_expression
	: relational_expression { $$ = $1; }
	| equality_expression EQ relational_expression {
		gencodeRelationalExpression($1.type, $3.type, EQ_t);
		$$.cond_type = EQ_t; 
	}
	| equality_expression NE relational_expression { 
		gencodeRelationalExpression($1.type, $3.type, NE_t);
		$$.cond_type = NE_t; 
	}
	;

and_expression
	: equality_expression {
		$$ = $1; 
	}
	| and_expression '&' equality_expression
	;

exclusive_or_expression
	: and_expression { $$ = $1; }
	| exclusive_or_expression '^' and_expression
	;

inclusive_or_expression
	: exclusive_or_expression { $$ = $1; }
	| inclusive_or_expression '|' exclusive_or_expression
	;

logical_and_expression
	: inclusive_or_expression { $$ = $1; }
	| logical_and_expression AND inclusive_or_expression
	;

logical_or_expression
	: logical_and_expression { $$ = $1; }
	| logical_or_expression OR logical_and_expression
	;

assignment_operator
	: ASGN { $$.asgn_type = ASGN_t; meet_assign_symbol = true; }
	| MULASGN { $$.asgn_type = MULASGN_t; meet_assign_symbol = true; }
	| DIVASGN { $$.asgn_type = DIVASGN_t; meet_assign_symbol = true; }
	| MODASGN { $$.asgn_type = MODASGN_t; meet_assign_symbol = true; }
	| ADDASGN { $$.asgn_type = ADDASGN_t; meet_assign_symbol = true; }
	| SUBASGN { $$.asgn_type = SUBASGN_t; meet_assign_symbol = true; }
	;

constant_expression
	: conditional_expression
	;

declaration
	: declaration_specifiers SEMICOLON { }
	| declaration_specifiers init_declarator_list SEMICOLON {
		// insert symbol (variable)
		if (! is_function) {
			if (lookupSymbol($2.id, global_scope) != 0) {
				if (! has_other_error)
					insertSymbol($2.id, "variable", $1.type, global_scope);
				/**************** VARIABLE DECLARATION ******************/
				if (global_scope == 0) {
					// global variable
					gencodeGlobalVar($1.type, $2.id);
				} else {
					// local variable
					// assign 0 as initial value
					gencodeLocalVar($1.type, $2.type, $2.id);
				}

				// close meet_assign_symbol
				meet_assign_symbol = false;
				
			} else {
				sprintf(errormsg, "%s %s %s", "Redeclared", data_type, $2.id);
				raiseSemanticError(errormsg);
				bzero(data_type, strlen(data_type));
			}
		} else {
			is_func_declaration = true;
			if (lookupSymbol($2.id, global_scope) != 0) {
				if (! has_other_error)
					insertSymbol($2.id, "function", $1.type, global_scope);
			} else {
				if ((! getSymbol($2.id, global_scope)->declared) && (! getSymbol($2.id, global_scope)->declared_and_defined)) {
					/************************ FUNCTION DECLARATION AFTER DEFINITION *********************/
					getSymbol($2.id, global_scope)->declared_and_defined = true;

					// check whether return type match
					if (getSymbolType($2.id, global_scope) != $1.type) {
						raiseSemanticError("Function return type is not the same");
					}
					// check if parameter has same numbers
					table_ptr_t temp = getSymbol($2.id, global_scope);
					if (temp->param_count != global_num_params) {
						raiseFunctionParamSE("Function formal parameter is not the same");
					} else {
					// check if parameter has same type
						for (int i = 0; i < temp->param_count; ++i) {
							// printf("[function_definition] param type : %s\n", type2String(global_param_list[i]));
							if (global_param_list[i] != temp->param_list[i]) {
								raiseFunctionParamSE("Function formal parameter is not the same");
							}
						}
					}

					deleteParams(global_num_params);
				} else {
					sprintf(errormsg, "%s %s %s", "Redeclared", data_type, $2.id);
					raiseSemanticError(errormsg);
					bzero(data_type, strlen(data_type));
					deleteParams(global_num_params);
				}
				is_func_declaration = false;
			}
			is_function = false;

			// set global_register_num to 0
			global_register_num = 0;
		}
	}
	;

declaration_specifiers
	: type_specifier declaration_specifiers 
	| type_specifier 
	;

init_declarator_list
	: init_declarator { $$.type = $1.type; }
	| init_declarator_list COMMA init_declarator
	;

init_declarator
	: declarator declaration_assignment_operator initializer {
		declared_with_val = true;
		// $$.type = $3.type;
		$$.type = $3.type;
	}
	| declarator {
		declared_with_val = false;
	}
	;

declaration_assignment_operator
	: ASGN { $$.asgn_type = ASGN_t; meet_assign_symbol = true; }
	;

type_specifier
	: INT { $$.type = INT_t; }
    | FLOAT { $$.type = FLOAT_t; }
    | BOOL  { $$.type = BOOL_t; }
    | STRING { $$.type = STRING_t; }
    | VOID { $$.type = VOID_t; }
	;

specifier_qualifier_list
	: type_specifier specifier_qualifier_list 
	| type_specifier 
	;

declarator
	: direct_declarator { }
	;

direct_declarator
	: ID { $$ = $1; }
	| LB declarator RB { }
	| direct_declarator LSB RSB
	| direct_declarator LSB '*' RSB
	| direct_declarator LSB assignment_expression RSB
	| direct_declarator for_func_lb parameter_type_list for_func_rb { is_function = true; }
	| direct_declarator LB RB { is_function = true; }
	| direct_declarator LB identifier_list RB { }
	;

parameter_type_list
	: parameter_list { }
	;

parameter_list
	: parameter_declaration
	| parameter_list COMMA parameter_declaration
	;

parameter_declaration
	: declaration_specifiers declarator {
		if (lookupSymbol($2.id, global_scope) != 0) {
			global_num_params++;
			insertSymbol($2.id, "parameter", $1.type, global_scope);
			global_param_list[global_num_params-1] = $1.type;
		} else {
			// printSymbolTable();
			sprintf(errormsg, "%s %s %s", "Redeclared", "variable", $2.id);
			raiseSemanticError(errormsg);
			// bzero(data_type, strlen(data_type));
		}
	}
	| declaration_specifiers abstract_declarator 
	| declaration_specifiers
	;

identifier_list
	: ID
	| identifier_list COMMA ID
	;

type_name
	: specifier_qualifier_list abstract_declarator
	| specifier_qualifier_list
	;

abstract_declarator
	: direct_abstract_declarator
	;

direct_abstract_declarator
	: LB abstract_declarator RB 
	| LSB RSB
	| LSB '*' RSB
	| LSB assignment_expression RSB 
	| direct_abstract_declarator LSB RSB
	| direct_abstract_declarator LSB '*' RSB
	| direct_abstract_declarator LSB assignment_expression RSB 
	| LB RB
	| LB parameter_type_list RB 
	| direct_abstract_declarator LB RB
	| direct_abstract_declarator LB parameter_type_list RB 
	;

initializer
	: LCB initializer_list RCB { }
	| LCB initializer_list COMMA RCB { }
	| assignment_expression
	;

initializer_list
	: designation initializer
	| initializer
	| initializer_list COMMA designation initializer
	| initializer_list COMMA initializer
	;

designation
	: designator_list ASGN
	;

designator_list
	: designator
	| designator_list designator
	;

designator
	: LSB constant_expression RSB
	;

statement
	: labeled_statement 
	| compound_statement
	| expression_statement 
	| selection_statement
	| iteration_statement
	| jump_statement
	| print_func
	;

print_func
	: print_keyword LB primary_expression RB SEMICOLON {
		// gencodeLoad(getSymbol($3.id, global_scope));
		gencodePrintStatement($3.type);
		is_print = false;
	}
	;
print_keyword
	: PRINT { is_print = true; }
	;

labeled_statement
	: ID ':' statement
	;

compound_statement
	: LCB RCB 
	| LCB block_item_list RCB
	;

block_item_list
	: block_item 
	| block_item_list block_item
	;

block_item
	: declaration 
	| statement 
	;

expression_statement
	: SEMICOLON
	| expression SEMICOLON 
	;

selection_statement
	: IF if_else_lb expression if_else_rb %prec then statement {
		int temp = popStack();
		sprintf(jasm_buf, "\tgoto EXIT_%d\n", temp);
		gencode(jasm_buf);
		sprintf(jasm_buf, "ELSE_%d%s\n", temp, ":");
		gencode(jasm_buf);

		sprintf(jasm_buf, "EXIT_%d%s\n", temp, ":");
		gencode(jasm_buf);
	}
	| IF if_else_lb expression if_else_rb statement ELSE {
		// pop when if/else block over
		int temp = popStack();
		sprintf(jasm_buf, "\tgoto EXIT_%d\n", temp);
		gencode(jasm_buf);
		sprintf(jasm_buf, "ELSE_%d%s\n", temp, ":");
		gencode(jasm_buf);

		// push when see ELSE
		pushStack(temp);
	} statement {
		int temp = popStack();
		sprintf(jasm_buf, "EXIT_%d%s\n", temp, ":");
		gencode(jasm_buf);
	}
	;

if_else_lb
	: LB {
		// set is_condition to true
		is_condition = true;
	}
	;

if_else_rb
	: RB {
		// push++ when see if(...)
		if_while_label++;
		pushStack(if_while_label);

		sprintf(jasm_buf, "IF_%d\n", if_while_label);
		gencode(jasm_buf);

		sprintf(jasm_buf, "\tgoto ELSE_%d\n", if_while_label);
		gencode(jasm_buf);
		sprintf(jasm_buf, "IF_%d%s\n", if_while_label, ":");
		gencode(jasm_buf);

		// close is_condition
		is_condition = false;
	}
	;

iteration_statement
	: WHILE for_func_lb {
		// meet while loop, set is_while to true
		is_while = true;

		// push++ when see while LB
		if_while_label++;
		pushStack(if_while_label);

		sprintf(jasm_buf, "WHILE_%d%s\n", if_while_label, ":");
		gencode(jasm_buf);
	} expression for_func_rb {
		// close is_while
		is_while = false;

		sprintf(jasm_buf, "WHILE_BODY_%d\n", if_while_label);
		gencode(jasm_buf);

		sprintf(jasm_buf, "\tgoto BREAK_%d\n", if_while_label);
		gencode(jasm_buf);

		sprintf(jasm_buf, "WHILE_BODY_%d%s\n", if_while_label, ":");
		gencode(jasm_buf);

	} statement {
		int temp = popStack();
		sprintf(jasm_buf, "\tgoto WHILE_%d\n", temp);
		gencode(jasm_buf);
		sprintf(jasm_buf, "BREAK_%d%s\n", temp, ":");
		gencode(jasm_buf);
	}
	| FOR for_func_lb expression_statement expression_statement for_func_rb statement { }
	| FOR for_func_lb expression_statement expression_statement expression for_func_rb statement { }
	| FOR for_func_lb declaration expression_statement for_func_rb statement { }
	| FOR for_func_lb declaration expression_statement expression for_func_rb statement { }
	;

for_func_lb
	: LB { global_scope++; }
	;

for_func_rb
	: RB { global_scope--; }
	;

jump_statement
	: BREAK SEMICOLON { }
	| return_keyword SEMICOLON {
		if (func_type == VOID_t) {
			gencode("\treturn\n");
		} else {
			// raiseSemanticError("Function return type is not the same");
		}
		is_return = false;
	}
	| return_keyword expression SEMICOLON {
		// close is_return
		is_return = false;
		gencodeReturnStatement(func_type, $2.type);
	}
	;

return_keyword
	: RETURN { is_return = true; } 
	;

external_declaration
	: function_definition
	| declaration
	;

function_definition
	: declaration_specifiers direct_declarator {
		/************************FUNCTION DEFINITION*******************************/
		is_function = false;
		if (lookupSymbol($2.id, global_scope) != 0) {
			if (checkIfDeclared($2.id, "function", global_scope-1)) {
				/*********************FUNCTION DEFINITION AFTER FORWARD DECLARATION**********************/
				// check whether return type match
				if (getSymbolType($2.id, global_scope-1) != $1.type) {
					raiseSemanticError("Function return type is not the same");
				}

				// check if parameter has same numbers
				table_ptr_t temp = getSymbol($2.id, global_scope-1);
				if (temp->param_count != global_num_params) {
					raiseFunctionParamSE("Function formal parameter is not the same");
				} else {
				// check if parameter has same type
					for (int i = 0; i < temp->param_count; ++i) {
						// printf("[function_definition] param type : %s\n", type2String(global_param_list[i]));
						if (global_param_list[i] != temp->param_list[i]) {
							raiseFunctionParamSE("Function formal parameter is not the same");
						}
					}
				}
				// if (! has_func_param_error)
				replaceSymbol($2.id, "function", $1.type, global_scope-1);

			} else {
				insertSymbol($2.id, "function", $1.type, global_scope-1);
			}

			// code generation for function
			sprintf(jasm_buf, "%s %s", ".method public static", $2.id);
			gencode(jasm_buf);
			if (strcmp($2.id, "main") == 0) {
				gencode("([Ljava/lang/String;)");
			} else {
				// code generation for parameters
				gencode("(");
				for(int i = 0; i < global_num_params; ++i) {
					// printf("[function_definition] param type : %s\n", type2String(global_param_list[i]));
					gencode(type2Jasmin(global_param_list[i]));
				}
				gencode(")");
			}

			// code generation for return type
			sprintf(jasm_buf, "%s\n", type2Jasmin($1.type));
			gencode(jasm_buf);
			func_type = $1.type; // specify return type for jump statement
			
			// clean parameter array
			cleanGlobalParamList();
			global_num_params = 0;

			// specify stack size
			gencode(".limit stack 50\n");
			gencode(".limit locals 50\n");

		} else {
			sprintf(errormsg, "%s %s %s", "Redeclared", data_type, $2.id);
			raiseSemanticError(errormsg);
			bzero(data_type, strlen(data_type));
		}
	} compound_statement {
		/************************* FUNCTION END *******************************/;
		// end method
		gencode(".end method\n");

		// restart register number from 0
		global_register_num = 0;

		// reset return type
		func_type = 0;
	}
	;

%%

/* C code section */
int main(int argc, char** argv)
{
    yylineno = 0;

	// open file
    file = fopen("uc_compiler.j","w");

	sprintf(jasm_buf, ".class public %s\n.super java/lang/Object\n", FNAME);
	gencode(jasm_buf);
	// start parsing
    yyparse();

    fclose(file);

    if (! has_syntax_error) {
		dumpSymbol(global_scope);
		printf("\nTotal lines: %d \n",yylineno);
	}
    return 0;
}

void yyerror(char *s)
{
	stop_gencode = true;
    if (strstr(s, "syntax") != NULL) {
		has_syntax_error = true;
		return;
	}

	// remove j file if any errors occur
	remove("uc_compiler.j"); 

    printf("\n|-----------------------------------------------|\n");
    printf("| Error found in line %d: %s", yylineno, buf);
    printf("| %s", s);
    printf("\n|-----------------------------------------------|\n\n");
}

/* stmbol table functions */
void createSymbol(char* name, char* kind, CTYPE type, int scope) {
	// printf("[createSymbol] creating symbol...\n");
    table_head = malloc(sizeof(struct symbol_table));
	table_head->next = NULL;
	table_head->prev = NULL;
	table_head->index = global_index++;
	table_head->register_num = 0;
	// table_head->name = malloc(strlen(name)*sizeof(char));
	bzero(table_head->name, SYMBOL_BUF_SIZE);
	sprintf(table_head->name, "%s", name);
	sprintf(table_head->kind, "%s", kind);
	table_head->type = type;
	table_head->scope = scope;

	// init params
	table_head->param_count = global_num_params;
	for (int i = 0; i < MAX_PARAM_SIZE; ++i) {
		table_head->param_list[i] = global_param_list[i];
	}

	if (scope > 0) {
		table_head->register_num = global_register_num;
		global_register_num++;
		// printf("[set gegister number] %s, register num = %d\n", name, table_head->register_num);
	}
}

void insertSymbol(char* name, char* kind, CTYPE type, int scope) {
    if (table_head == NULL) {
        // init the table head
		// printf("[insertSymbol] no table yet. create one.\n");
		// printf("===type=%s, kind=%s, name=%s, scope=%d===\n",type, kind, name, scope);
        createSymbol(name, kind, type, scope);
		// printf("[insertSymbol] symbol inited.\n");
    } else {
        table_ptr_t new_symbol = malloc(sizeof(struct symbol_table));

        // init new symbol
		new_symbol->next = NULL;
		new_symbol->index = global_index++;

		if (scope > 0) {
			new_symbol->register_num = global_register_num;
			global_register_num++;
			// printf("[set gegister number] %s, register num = %d\n", name, new_symbol->register_num);
		}

		bzero(new_symbol->name, SYMBOL_BUF_SIZE);
		sprintf(new_symbol->name, "%s", name);
		sprintf(new_symbol->kind, "%s", kind);
		new_symbol->type = type;
		new_symbol->scope = scope;

		// init params
		new_symbol->param_count = global_num_params;
		for (int i = 0; i < MAX_PARAM_SIZE; ++i) {
			new_symbol->param_list[i] = global_param_list[i];
		}

		// delete params from table if previois declared, AFTER PUTTING PARAMS INTO FUNCTION ATTRIBUTE
		if (is_func_declaration) {
			new_symbol->declared = true;
			// puts("deleting params");
			deleteParams(global_num_params);
			is_func_declaration = false;
		} else {
			new_symbol->declared = false;
		}

		table_ptr_t temp = table_head;
        while (temp != NULL && temp->next != NULL)
            temp = temp->next;
		// insert into linked list
		if (temp != NULL) {
			temp->next = new_symbol;
			new_symbol->prev = temp;
		} else {
			// puts("re-init table head");
			table_head = new_symbol;
			table_head->next = NULL;
			table_head->prev = NULL;
		}
    }
	global_total_symbol++;
}

int lookupSymbol(char* name, int scope) {
    table_ptr_t temp = table_head;
    while (temp != NULL) {
		if(strcmp(temp->name, name) == 0 && temp->scope == scope) {
			// redeclared
			sprintf(data_type, "%s", temp->kind);
			return 0;
		}
		if (strcmp(temp->name, name) == 0 && temp->scope < scope) {
			// this one is good, return 1
			return 1;
		}
		temp = temp ->next;
    }
	// undeclared
	return -1;
}

CTYPE getSymbolType(char* name, int scope) {
	table_ptr_t temp = table_head;
    while (temp != NULL) {
		if(strcmp(temp->name, name) == 0 && temp->scope == scope) {
			return temp->type;
		}
		temp = temp ->next;
    }
	if (scope == 0) {
		return 0;
	}
	return getSymbolType(name, scope-1);
	// puts("[getSymbolType] No such symbol in table...");
	// return 0;
}

void dumpSymbol(int scope) {
	if (searchDumpable(scope) == 0)
		return;
	// printf("there are %d nodes left\n", global_total_symbol);
    printf("\n%-10s%-10s%-12s%-10s%-10s%-10s\n\n",
           "Index", "Name", "Kind", "Type", "Scope", "Attribute");
	table_ptr_t temp = table_head;
	int index = 0;
	while (temp != NULL) {
		if (temp->scope == scope) {
			// print symbol
			if (! strcmp(temp->kind, "function")) {
				char* param_buf = malloc(sizeof(char) * SYMBOL_BUF_SIZE);
				bzero(param_buf, strlen(param_buf));
				for (int i = 0; i < temp->param_count; ++i) {
					if (i == 0) {
						strcat(param_buf, type2String(temp->param_list[i]));
					} else {
						strcat(param_buf, ", ");
						strcat(param_buf, type2String(temp->param_list[i]));
					}
				}
				printf("%-10d%-10s%-12s%-10s%-10d%s\n", index++, temp->name, temp->kind, type2String(temp->type), temp->scope, param_buf);
				free(param_buf);
			}
			else
				printf("%-10d%-10s%-12s%-10s%-10d\n", index++, temp->name, temp->kind, type2String(temp->type), temp->scope);
			// and then delete it from linked list
			global_total_symbol--;
			if (global_total_symbol > 0) {
				if (temp == table_head) {
					table_head = temp->next;
					table_head->prev = NULL;
					temp = table_head;
					// temp = temp->next;
					continue;
				} else {
					temp->prev->next = temp->next;
					if (temp->next != NULL) {
						temp->next->prev = temp->prev;
						temp = temp->next;
						continue;
					}
					
				}
			}
		}
		temp = temp->next;
	}
	printf("\n");
}

int searchDumpable(int scope) {
	table_ptr_t temp = table_head;
	while (temp != NULL) {
		if (temp->scope == scope)
			return 1;
		temp = temp->next;
	}
	return 0;
}

void printErrorMsg() {
	if (has_other_error) {
		yyerror(errormsg);
		bzero(errormsg, strlen(errormsg));
		has_other_error = false;
	}
	if (has_func_param_error) {
		yyerror(errormsg2);
		bzero(errormsg2, strlen(errormsg2));
		has_func_param_error = false;
	}
}

void deleteParams(int num) {
	table_ptr_t temp = table_head;
	while (temp->next != NULL)
		temp = temp->next;
	
	while(global_num_params > 0) {
		// printf("delete params %s\n", temp->name);
		if (temp == table_head) { // at head
			table_head = NULL;
		} else { // at tail
			if (temp->prev != NULL) {
				temp->prev->next = NULL;
				temp = temp->prev;
			} else {
				temp = NULL;
			}
		}
		global_num_params--;
		global_total_symbol--;
	}
}

void replaceSymbol(char* name, char* kind, CTYPE type, int scope) {
	table_ptr_t temp = table_head;
	bool found = false;
	// find symbol by name
	while (temp != NULL) {
		if (strcmp(temp->name, name) == 0) {
			found = true;
			break;
		}
		temp = temp->next;
	}
	if (found) {
		sprintf(temp->name, "%s", name);
		sprintf(temp->kind, "%s", kind);
		temp->type = type;
		temp->scope = scope;
		temp->declared_and_defined = true;
	} else {
		insertSymbol(name, kind, type, scope);
	}
}

bool checkIfDeclared(char* name, char* kind, int scope) {
	table_ptr_t temp = table_head;
    while (temp != NULL) {
		if(strcmp(temp->name, name) == 0 && strcmp(temp->kind, kind) == 0 && temp->scope == scope) {
			// redeclare, return 0
			if (temp->declared) {
				return true;
			} else {
				return false;
			}
		}
		temp = temp ->next;
    }
}

void printSymbolTable() {
	table_ptr_t temp = table_head;
	while (temp != NULL) {
		printf("%s -> ", temp->name);
		temp = temp->next;
	}
	printf("\n");
}

char* type2String(CTYPE type) {
	switch(type) {
		case VOID_t:
			return "void";
		case INT_t:
			return "int";
		case FLOAT_t:
			return "float";
		case STRING_t:
			return "string";
		case BOOL_t:
			return "bool";
		default:
			return "NONE";
	}
}

char* type2Jasmin(CTYPE type) {
	switch(type) {
		case VOID_t:
			return "V";
		case INT_t:
			return "I";
		case FLOAT_t:
			return "F";
		case STRING_t:
			return "Ljava/lang/String;";
		case BOOL_t:
			return "Z";
		default:
			return "NONE";
	}
}

table_ptr_t getSymbol(char* name, int scope) {
	// printf("[getSymbol] %s\n", name);
	table_ptr_t temp = table_head;
	// find symbol by name
	while (temp != NULL) {
		if (strcmp(temp->name, name) == 0 && temp->scope == scope) {
			// printf("@@@ found: %s, scope=%d @@@\n", temp->name, temp->scope);
			return temp;
		}
		temp = temp->next;
	}
	// return a dummy symbol if not found in table
	if (scope == 0) {
		table_ptr_t dummy_symbol;
		return initSymbol(dummy_symbol);
	}

	// else, search recursively
	getSymbol(name, scope-1);
}

void cleanGlobalParamList() {
	for (int i = 0; i < MAX_PARAM_SIZE; ++i) {
		global_param_list[i] = 0;
	}
}

void cleanArgumentList() {
	global_argument_count = 0;
	for (int i = 0; i < MAX_PARAM_SIZE; ++i) {
		global_argument_list[i] = 0;
	}
}

table_ptr_t initSymbol(table_ptr_t symbol) {
	symbol = malloc(sizeof(struct symbol_table));
	symbol->next = NULL;
	symbol->prev = NULL;
	symbol->index = 0;
	symbol->register_num = 0;
	bzero(symbol->name, SYMBOL_BUF_SIZE);
	sprintf(symbol->name, "%s", "");
	sprintf(symbol->kind, "%s", "");
	symbol->type = 0;
	symbol->scope = 0;

	// init params
	symbol->param_count = 0;
	for (int i = 0; i < MAX_PARAM_SIZE; ++i) {
		symbol->param_list[i] = 0;
	}
	return symbol;
}

void raiseSemanticError(char* msg) {
	has_other_error = true;
	sprintf(errormsg, "%s", msg);
}

void raiseFunctionParamSE(char* msg) {
	has_func_param_error = true;
	sprintf(errormsg2, "%s", msg);
}

/* code generation functions */
void gencode(char* s) {
	if (!stop_gencode) {
		fprintf(file, "%s", s);
	}
}

void gencodeGlobalVar(CTYPE type, char* name) {
	switch (type) {
		case VOID_t:
			break;
		case INT_t:
			if (declared_with_val)
				sprintf(jasm_buf, ".field public static %s %s = %d\n", name, "I", yylval.yytype.i_val);
			else
				sprintf(jasm_buf, ".field public static %s %s = %d\n", name, "I",0);
			gencode(jasm_buf);
			break;
		case FLOAT_t:
			if (declared_with_val) {
				if (yylval.yytype.f_val == 0)
					sprintf(jasm_buf, ".field public static %s %s\n", name, "F");
				else
					sprintf(jasm_buf, ".field public static %s %s = %f\n", name, "F", yylval.yytype.f_val);
			} else {
				sprintf(jasm_buf, ".field public static %s %s\n", name, "F");
			}
			gencode(jasm_buf);
			break;
		case STRING_t:
			if (declared_with_val) {
				sprintf(jasm_buf, ".field public static %s %s = \"%s\"\n", name, "Ljava/lang/String;", yylval.yytype.id);
			} else {
				sprintf(jasm_buf, ".field public static %s %s = \"%s\"\n", name, "Ljava/lang/String;", "");
			}
			gencode(jasm_buf);
			break;
		case BOOL_t:
			if (declared_with_val)
				sprintf(jasm_buf, ".field public static %s %s = %d\n", name, "I", yylval.yytype.i_val);
			else
				sprintf(jasm_buf, ".field public static %s %s = %d\n", name, "I", 0);
			gencode(jasm_buf);
			break;
		default:
			raiseSemanticError("Unsupported variable type");
			break;
	}

	declared_with_val = false;
}

void gencodeLocalVar(CTYPE typeLHS, CTYPE typeRHS, char* name) {
	if (declared_with_val) {
		// printf("======== [local var declare] %s = %s ========\n", type2String(typeLHS), type2String(typeRHS));
		if (typeLHS == INT_t && typeRHS == FLOAT_t) {
			// cast
			gencode("\tf2i\n");
		} else if (typeLHS == FLOAT_t && typeRHS == INT_t) {
			// cast
			gencode("\ti2f\n");
		} else if (typeLHS == INT_t && typeRHS == INT_t) {
			
		} else if (typeLHS == FLOAT_t && typeRHS == FLOAT_t) {
			
		} else if (typeLHS == STRING_t && typeRHS == STRING_t) {
			
		} else if (typeLHS == BOOL_t && typeRHS == BOOL_t) {
			
		} else {
			// raiseSemanticError("Type mismatch");
		}
		gencodeStore(getSymbol(name, global_scope));
	} else {
		switch (typeLHS) {
			case VOID_t:
				break;
			case INT_t:
				gencode("\tldc 0\n");
				gencodeStore(getSymbol(name, global_scope));
				break;
			case FLOAT_t:
				gencode("\tldc 0.0\n");
				gencodeStore(getSymbol(name, global_scope));
				break;
			case STRING_t:
				gencode("\tldc \"\"\n");
				gencodeStore(getSymbol(name, global_scope));
				break;
			case BOOL_t:
				gencode("\tldc 0\n");
				gencodeStore(getSymbol(name, global_scope));
				break;
			default:
				// raiseSemanticError("Unsupported type");
				break;
		}
	}

	declared_with_val = false;
}

void gencodeLoad(table_ptr_t symbol) {
	if (symbol == NULL) {
		puts("[gencodeLoad] Symbol not found in table.");
		return;
	}
	if (strcmp(symbol->kind, "function") == 0) {
		// puts("[gencodeLoad] This is a function, don't load it.");
		return;
	}
	int register_num = symbol->register_num;
	CTYPE type = symbol->type;
	char* name = symbol->name;
	// printf("loading %s\n", name);
	switch (type){
		case INT_t:
			if (symbol->scope == 0)
				sprintf(jasm_buf, "\tgetstatic %s/%s %s\n", FNAME, name, type2Jasmin(type));
			else
				sprintf(jasm_buf, "\tiload %d\n", register_num);
			break;
		case FLOAT_t:
			if (symbol->scope == 0)
				sprintf(jasm_buf, "\tgetstatic %s/%s %s\n", FNAME, name, type2Jasmin(type));
			else
				sprintf(jasm_buf, "\tfload %d\n", register_num);
			break;
		case STRING_t:
			if (symbol->scope == 0)
				sprintf(jasm_buf, "\tgetstatic %s/%s %s\n", FNAME, name, type2Jasmin(type));
			else
				sprintf(jasm_buf, "\taload %d\n", register_num);
			break;
		case BOOL_t:
			if (symbol->scope == 0)
				sprintf(jasm_buf, "\tgetstatic %s/%s %s\n", FNAME, name, type2Jasmin(type));
			else
				sprintf(jasm_buf, "\tiload %d\n", register_num);
			break;
		default:
			// raiseSemanticError("Load failed");
			break;
	}
	// puts("done");
	gencode(jasm_buf);

	return;
}

void gencodeStore(table_ptr_t symbol) {
	int register_num = symbol->register_num;
	CTYPE type = symbol->type;
	char* name = symbol->name;

	switch (type) {
		case VOID_t:
			break;
		case INT_t:
			if (symbol->scope == 0)
				sprintf(jasm_buf, "\tputstatic %s/%s %s\n", FNAME, name, type2Jasmin(type));
			else
				sprintf(jasm_buf, "\tistore %d\n", register_num);
			break;
		case FLOAT_t:
			if (symbol->scope == 0)
				sprintf(jasm_buf, "\tputstatic %s/%s %s\n", FNAME,  name, type2Jasmin(type));
			else
				sprintf(jasm_buf, "\tfstore %d\n", register_num);
			break;
		case STRING_t:
			if (symbol->scope == 0)
				sprintf(jasm_buf, "\tputstatic %s/%s %s\n", FNAME,  name, type2Jasmin(type));
			else
				sprintf(jasm_buf, "\tastore %d\n", register_num);
			break;
		case BOOL_t:
			if (symbol->scope == 0)
				sprintf(jasm_buf, "\tputstatic %s/%s %s\n", FNAME,  name, type2Jasmin(type));
			else
				sprintf(jasm_buf, "\tistore %d\n", register_num);
			break;
		default:
			// raiseSemanticError("store failed");
			break;
	}

	gencode(jasm_buf);
}

CTYPE gencodeArithmetic(CTYPE typeLHS, CTYPE typeRHS, ASSGN_TYPE asgn_type) {
	switch (asgn_type) {
		case ADDASGN_t:
			sprintf(jasm_buf, "\t%s\n", (typeLHS==FLOAT_t || typeRHS==FLOAT_t) ? "fadd" : "iadd");
			break;
		case SUBASGN_t:
			sprintf(jasm_buf, "\t%s\n", (typeLHS==FLOAT_t || typeRHS==FLOAT_t) ? "fsub" : "isub");
			break;
		case MULASGN_t:
			sprintf(jasm_buf, "\t%s\n", (typeLHS==FLOAT_t || typeRHS==FLOAT_t) ? "fmul" : "imul");
			break;
		case DIVASGN_t:
			sprintf(jasm_buf, "\t%s\n", (typeLHS==FLOAT_t || typeRHS==FLOAT_t) ? "fdiv" : "idiv");
			break;
		case MODASGN_t:
			if (typeLHS == INT_t && typeRHS == INT_t) {
				gencode("\tirem\n");
				return INT_t;
			} else {
				if (! has_other_error)
					raiseSemanticError("Modulo operator (%) with float operands");
				return VOID_t;
			}
			break;
		default:
			break;
	}

	if (typeLHS == INT_t && typeRHS == FLOAT_t) {
		// cast
		gencode("\tswap\n");
		gencode("\ti2f\n");
		gencode("\tswap\n");
		gencode(jasm_buf);
		return FLOAT_t;
	} else if (typeLHS == FLOAT_t && typeRHS == INT_t) {
		// cast
		gencode("\ti2f\n");
		gencode(jasm_buf);
		return FLOAT_t;
	} else if (typeLHS == INT_t && typeRHS == INT_t) {
		gencode(jasm_buf);
		return INT_t;
	} else if (typeLHS == FLOAT_t && typeRHS == FLOAT_t) {
		gencode(jasm_buf);
		return FLOAT_t;
	} else {
		// raiseSemanticError("Unsupported type");
	}
}

void gencodePostfixExpression(ASSGN_TYPE postfix_type, table_ptr_t symbol) {
	gencodeLoad(symbol);
	CTYPE type = symbol->type;
	switch (postfix_type) {
		case INC_t:
			if (type == INT_t) {
				gencode("\tldc 1\n");
				gencode("\tiadd\n");
				gencodeStore(symbol);
			} else if (type == FLOAT_t) {
				gencode("\tldc 1.0\n");
				gencode("\tfadd\n");
				gencodeStore(symbol);
			} else {
				// raiseSemanticError("No such postfix expression");
			}
			break;
		case DEC_t:
			if (type == INT_t) {
				gencode("\tldc 1\n");
				gencode("\tisub\n");
				gencodeStore(symbol);
			} else if (type == FLOAT_t) {
				gencode("\tldc 1.0\n");
				gencode("\tfsub\n");
				gencodeStore(symbol);
			} else {
				// raiseSemanticError("No such postfix expression");
			}
			break;
		default:
			// raiseSemanticError("No such postfix expression operation type");
			break;
	}
}

void gencodeAssignExpression(ASSGN_TYPE asgn_type, table_ptr_t symbol, CTYPE typeRHS) {
	CTYPE typeLHS = symbol->type;

	switch(asgn_type) {
		case ASGN_t:
			if (typeLHS == INT_t && typeRHS == FLOAT_t) {
				// cast
				gencode("\tf2i\n");
			} else if (typeLHS == FLOAT_t && typeRHS == INT_t) {
				// cast
				gencode("\ti2f\n");
			} else if (typeLHS == INT_t && typeRHS == INT_t) {
				
			} else if (typeLHS == FLOAT_t && typeRHS == FLOAT_t) {
				
			} else if (typeLHS == BOOL_t && typeRHS == BOOL_t) {
				
			} else if (typeLHS == STRING_t && typeRHS == STRING_t) {
				
			} else {
				// raiseSemanticError("Unsupoerted type");
			}
			break;
		case ADDASGN_t:
			gencodeLoad(symbol);
			gencode("\tswap\n");
			gencodeArithmetic(typeLHS, typeRHS, ADDASGN_t);
			break;
		case SUBASGN_t:
			gencodeLoad(symbol);
			gencode("\tswap\n");
			gencodeArithmetic(typeLHS, typeRHS, SUBASGN_t);
			break;
		case MULASGN_t:
			gencodeLoad(symbol);
			gencode("\tswap\n");
			gencodeArithmetic(typeLHS, typeRHS, MULASGN_t);
			break;
		case DIVASGN_t:
			gencodeLoad(symbol);
			gencode("\tswap\n");
			gencodeArithmetic(typeLHS, typeRHS, DIVASGN_t);
			break;
		case MODASGN_t:
			gencodeLoad(symbol);
			gencode("\tswap\n");
			gencodeArithmetic(typeLHS, typeRHS, MODASGN_t);
			break;
		default:
			// raiseSemanticError("Unsupported assignment expression");
			break;
	}
	//store symbol
	gencodeStore(symbol);
}

void gencodePrintStatement(CTYPE type) {
	gencode("\tgetstatic java/lang/System/out Ljava/io/PrintStream;\n\tswap\n");
	switch (type) {
		case INT_t:
			gencode("\tinvokevirtual java/io/PrintStream/println(I)V\n");
			break;
		case FLOAT_t:
			gencode("\tinvokevirtual java/io/PrintStream/println(F)V\n");
			break;
		case STRING_t:
			gencode("\tinvokevirtual java/io/PrintStream/println(Ljava/lang/String;)V\n");
			break;
		case BOOL_t:
			gencode("\tinvokevirtual java/io/PrintStream/println(I)V\n");
			break;
		default:
			// raiseSemanticError("Unsupported type");
			break;
	}
}

void gencodeReturnStatement(CTYPE function_type, CTYPE return_type) {
	if (function_type == INT_t && return_type == FLOAT_t) {
		// cast
		gencode("\tf2i\n");
		gencode("\tireturn\n");
	} else if (function_type == FLOAT_t && return_type == INT_t) {
		// cast
		gencode("\ti2f\n");
		gencode("\tfreturn\n");
	} else if (function_type == INT_t && return_type == INT_t) {
		gencode("\tireturn\n");
	} else if (function_type == FLOAT_t && return_type == FLOAT_t) {
		gencode("\tfreturn\n");
	} else if (function_type == BOOL_t && return_type == BOOL_t) {
		gencode("\tireturn\n");
	} else {
		// raiseSemanticError("Function return type is not the same");
	}
}

void gencodeFunctionCalling(table_ptr_t symbol, int num_args) {
	// check whether num of params match
	if (symbol->param_count != num_args) {
		raiseFunctionParamSE("Function formal parameter is not the same");
	}

	sprintf(jasm_buf, "\tinvokestatic %s/%s", FNAME,  symbol->name);
	gencode(jasm_buf);
	// code generation for parameters
	gencode("(");
	for(int i = 0; i < symbol->param_count; ++i) {
		// printf("[function_definition] param type : %s\n", type2String(global_param_list[i]));
		gencode(type2Jasmin(symbol->param_list[i]));
	}
	gencode(")");

	// code generation for return type
	sprintf(jasm_buf, "%s\n", type2Jasmin(symbol->type));
	gencode(jasm_buf);

	// clean global argument list
	cleanArgumentList();
}

void gencodeArgumentCasting(CTYPE param_type, CTYPE arg_type) {
	if (param_type == INT_t && arg_type == FLOAT_t) {
		// cast explicitly
		gencode("\tf2i\n");
	} else if (param_type == FLOAT_t && arg_type == INT_t) {
		// cast
		gencode("\ti2f\n");
	} else if (param_type == INT_t && arg_type == INT_t) {
		
	} else if (param_type == FLOAT_t && arg_type == FLOAT_t) {
		
	} else if (param_type == BOOL_t && arg_type == BOOL_t) {
		
	} else if (param_type == STRING_t && arg_type  == STRING_t) {
		
	} else {
		raiseFunctionParamSE("Function formal parameter is not the same");
	}
}

void gencodeRelationalExpression(CTYPE typeLHS, CTYPE typeRHS, CONDITION_TYPE cond_type) {
	if (typeLHS != typeRHS) {
		if (typeLHS == INT_t && typeRHS == FLOAT_t) {
			gencode("\tf2i\n");
		} else if (typeLHS == FLOAT_t && typeRHS == INT_t) {
			gencode("\ti2f\n");
		} else {
			// raiseSemanticError("Compared type mismatch");
		}
	}

	if (typeLHS == INT_t || typeLHS == BOOL_t) {
		gencode("\tisub\n");
	} else {
		gencode("\tfsub\n");
		// cast_after_condition = true;
		gencode("\tf2i\n");
	}

	switch (cond_type) {
		case EQ_t:  // ==
			gencode("\tifeq ");
			break;
		case NE_t:  // !=
			gencode("\tifne ");
			break;
		case LT_t:  // <
			gencode("\tiflt ");
			break;
		case MT_t:  // >
			gencode("\tifgt ");
			break;
		case LTE_t: // <=
			gencode("\tifle ");
			break;
		case MTE_t: // >=
			gencode("\tifge ");
			break;
		default:
			raiseSemanticError("No such condition type");
			break;
	}
}

bool stackIsEmpty() {
	if (TOS == -1)
		return true; 
	else
		return false;
} 

void pushStack(int data) {
	if (TOS >= MAX_STACK_SIZE)
		puts("Stack is full...");
	else
		stack[++TOS] = data;
}

int popStack() {
	if (stackIsEmpty())
		puts("Stack is empty...");
	else
		return stack[TOS--];
}
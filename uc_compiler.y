/*	Definition section */
%{

/* include header */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include "common.h"

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
CTYPE global_param_list[MAX_PARAM_SIZE];
char errormsg[CODE_BUF_SIZE];
char errormsg2[CODE_BUF_SIZE];
bool has_other_error = false;
bool has_func_param_error = false;
int RHS_var_count = 0;

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
table_ptr_t getSymbol(char* name, int scope);
CTYPE getSymbolType(char* name, int scope);
void cleanGlobalParamList();
table_ptr_t initSymbol(table_ptr_t symbol);
void raiseSemanticError(char* msg);
void raiseFunctionParamSE(char* msg);

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
	}
	| constant { $$ = $1; }
	| string { $$ = $1; }
	| LB expression RB { $$ = $2; }
	;

constant
	: I_CONST {
		$1.type = INT_t;
		$$ = $1;
		if (is_divide)
			RHS_var_count++;
	}
	| F_CONST {
		$1.type = FLOAT_t;
		$$ = $1;
		if (is_divide)
			RHS_var_count++;
	}
	| TRUE {
		$1.type = BOOL_t;
		$$ = $1;
	}
	| FALSE {
		$1.type = BOOL_t;
		$$ = $1;
	}
	;

string
	: STR_CONST {
		$1.type = STRING_t;
		$$ = $1;
	}
	;

expression
	: assignment_expression  { $$ = $1; }
	| expression COMMA assignment_expression
	;

postfix_expression
	: primary_expression { $$ = $1; }
	| postfix_expression LSB expression RSB
	| postfix_expression LB RB {
		/*************** FUNCTION CALL (without args) ******************/
		if (lookupSymbol($1.id, global_scope) == -1) {
			sprintf(errormsg, "%s %s", "Undeclared function", $1.id);
			raiseSemanticError(errormsg);
		}
	}
	| postfix_expression LB argument_expression_list RB {
		/*************** FUNCTION CALL (with args) ******************/
		if (lookupSymbol($1.id, global_scope) == -1) {
			sprintf(errormsg, "%s %s", "Undeclared function", $1.id);
			raiseSemanticError(errormsg);
		}
	}
	| postfix_expression INC { }
	| postfix_expression DEC { }
	| LB type_name RB LCB initializer_list RCB { }
	| LB type_name RB LCB initializer_list COMMA RCB { }
	;

argument_expression_list
	: assignment_expression { $$ = $1; }
	| argument_expression_list COMMA assignment_expression { }
	;

assignment_expression
	: conditional_expression { $$ = $1; }
	| unary_expression  assignment_operator assignment_expression {
		if (is_divide && RHS_var_count == 1 && ($3.i_val == 0 || $3.f_val == 0))
			raiseSemanticError("Divide by zero");
		is_divide = false;
		RHS_var_count = 0;
	}
	;

conditional_expression
	: logical_or_expression  { $$ = $1; }
	;

unary_expression
	: postfix_expression { $$ = $1; }
	| INC unary_expression { }
	| DEC unary_expression { }
	| unary_operator cast_expression { }
	;

unary_operator
	: ADD { }
	| SUB { }
	| NOT { }
	;

cast_expression
	: unary_expression { $$ = $1; }
	| LB type_name RB cast_expression { }
	;

mul_expression
	: cast_expression { $$ = $1; }
	| mul_expression MUL cast_expression { }
	| mul_expression DIV cast_expression {
		if (is_divide && RHS_var_count == 1 && ($3.i_val == 0 || $3.f_val == 0))
			raiseSemanticError("Divide by zero");
		is_divide = false;
		RHS_var_count = 0;
	}
	| mul_expression MOD cast_expression { }
	;

add_expression
	: mul_expression { $$ = $1; }
	| add_expression ADD mul_expression { }
	| add_expression SUB mul_expression { }
	;

relational_expression
	: add_expression { $$ = $1; }
	| relational_expression LT add_expression { }
	| relational_expression MT add_expression { }
	| relational_expression LTE add_expression { }
	| relational_expression MTE add_expression { }
	;

equality_expression
	: relational_expression { $$ = $1; }
	| equality_expression EQ relational_expression { }
	| equality_expression NE relational_expression { }
	;

and_expression
	: equality_expression { $$ = $1; }
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
	: ASGN { }
	| MULASGN { }
	| DIVASGN { }
	| MODASGN { }
	| ADDASGN { }
	| SUBASGN { }
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
	: init_declarator { }
	| init_declarator_list COMMA init_declarator
	;

init_declarator
	: declarator declaration_assignment_operator initializer { }
	| declarator { }
	;

declaration_assignment_operator
	: ASGN { }
	;

type_specifier
	: INT { }
    | FLOAT { }
    | BOOL  { }
    | STRING { }
    | VOID { }
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
	: PRINT LB primary_expression RB SEMICOLON { }
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
	: IF LB expression RB %prec then statement { }
	| IF LB expression RB statement ELSE statement { }
	;

iteration_statement
	: WHILE for_func_lb expression for_func_rb statement { }
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
	| RETURN SEMICOLON { }
	| RETURN expression SEMICOLON { }
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

			// clean parameter array
			cleanGlobalParamList();
			global_num_params = 0;
		} else {
			sprintf(errormsg, "%s %s %s", "Redeclared", data_type, $2.id);
			raiseSemanticError(errormsg);
			bzero(data_type, strlen(data_type));
		}
	} compound_statement
	;

%%

/* C code section */
int main(int argc, char** argv)
{
    yylineno = 0;

	// start parsing
    yyparse();

    if (! has_syntax_error) {
		dumpSymbol(global_scope);
		printf("\nTotal lines: %d \n",yylineno);
	}
    return 0;
}

void yyerror(char *s)
{
    if (strstr(s, "syntax") != NULL) {
		has_syntax_error = true;
		return;
	}

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

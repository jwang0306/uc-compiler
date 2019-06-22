/* Definition section */
%{
#include <stdio.h>
#include <stdlib.h>
int line_total = 0;
int line_comment = 0;
%}

/* Define regular expression label */
digit		[0-9]
letter		[a-zA-Z]
integer     {digit}+
float       {digit}+"."{digit}+
id			{letter}+({letter}|{digit})*

%x COMMENT STRING_STATE

/* Rules section */
%%

 /* Arithmetic */
"+"     { printf("%s \t ADD\n", yytext); }
"-" 	{ printf("%s \t SUB\n", yytext); }
"*" 	{ printf("%s \t MUL\n", yytext); }
"/" 	{ printf("%s \t DIV\n", yytext); }
"%"     { printf("%s \t MOD\n", yytext); }
"++"    { printf("%s \t INC\n", yytext); }
"--"    { printf("%s \t DEC\n", yytext); }

 /* Relational */
">"		{ printf("%s \t MT\n", yytext); }
"<"		{ printf("%s \t LT\n", yytext); }
">="	{ printf("%s \t MTE\n", yytext); }
"<="	{ printf("%s \t LTE\n", yytext); }
"=="	{ printf("%s \t EQ\n", yytext); }
"!="	{ printf("%s \t NE\n", yytext); }

 /* Assignment */
"="		{ printf("%s \t ASGN\n", yytext); }
"+="	{ printf("%s \t ADDASGN\n", yytext); }
"-="	{ printf("%s \t SUBASGN\n", yytext); }
"*="	{ printf("%s \t MULASGN\n", yytext); }
"/="	{ printf("%s \t DIVASGN\n", yytext); }
"%="	{ printf("%s \t MODASGN\n", yytext); }

 /* Logical */
"&&"	{ printf("%s \t AND\n", yytext); }
"||"	{ printf("%s \t OR\n", yytext); }
"!"		{ printf("%s \t NOT\n", yytext); }

 /* Delimiters */
"("		{ printf("%s \t LB\n", yytext); }
")"		{ printf("%s \t RB\n", yytext); }
"{"		{ printf("%s \t LCB\n", yytext); }
"}"		{ printf("%s \t RCB\n", yytext); }
"["		{ printf("%s \t LSB\n", yytext); }
"]"		{ printf("%s \t RSB\n", yytext); }
","		{ printf("%s \t COMMA\n", yytext); }

 /* Print Keywords */	
"print"		{ printf("%s \t PRINT\n", yytext); }

 /* Condition and Loop Keywords */
"if"		{ printf("%s \t IF\n", yytext); }
"else"		{ printf("%s \t ELSE\n", yytext); }
"for"		{ printf("%s \t ELSE\n", yytext); }
"while"		{ printf("%s \t WHILE\n", yytext); }

 /* Declaration Keywords */
"void"		{ printf("%s \t VOID\n", yytext); }
"int"		{ printf("%s \t INT\n", yytext); }
"float"  	{ printf("%s \t FLOAT\n", yytext); }
"string"  	{ printf("%s \t STRING\n", yytext); }
"bool"  	{ printf("%s \t BOOL\n", yytext); }

 /* boolean Keywords */
"true"      { printf("%s \t TRUE\n", yytext); }
"false"     { printf("%s \t FALSE\n", yytext); }

 /* return Keywords */
"return"    { printf("%s \t RET\n", yytext); }
"continue"  { printf("%s \t CONT\n", yytext); }
"break"     { printf("%s \t BREAK\n", yytext); }

 /* String Constant */
\"				        { printf("%s \t QUOTA\n", yytext); BEGIN STRING_STATE; }
<STRING_STATE>\"		{ printf("%s \t QUOTA\n", yytext); BEGIN INITIAL; }
<STRING_STATE>[^"]*		{ printf("%s \t STR_CONST\n", yytext); }

 /* Number Constant */
{integer}   { printf("%s \t I_CONST\n", yytext); }
{float}     { printf("%s \t F_CONST\n", yytext); }

 /* C type Comment */
"/*"				{ printf("%s", yytext); line_comment++; BEGIN COMMENT; }
<COMMENT>[^*\n]+	{ printf("%s", yytext); }
<COMMENT>\n			{ printf("%s", yytext); line_comment++; line_total++; }
<COMMENT>"*"		{ printf("%s", yytext); }
<COMMENT>"*/"		{ printf("%s \t C Comment\n", yytext); BEGIN INITIAL; }

 /* C++ type Comment */
\/\/.*	{ printf("%s \t C++ Comment\n",yytext); line_comment++; }

 /* Variable ID */
{id}    { printf("%s \t ID\n", yytext); }

 /* others */
";"         { printf("%s \t SEMICOLON\n", yytext); }
[\n]        { line_total++; }
[ \t]		{ ; } /* Ignore */
[^ \t\n] 	{ ; } /* Ignore other charactor sets */

%%

int yywrap() {
    return 1;
}

int main(int argc,char *argv[]) {
	yyin = fopen(argv[1],"r");
	yylex();
	printf("\nParse over, the line number is %d.\n\n", line_total);
	printf("comment: %d lines\n\n", line_comment);

	return 0;
}
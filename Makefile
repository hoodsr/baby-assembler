tokens : lex.yy.c
	gcc lex.yy.c -o ba -lfl

lex.yy.c : tokens.l
	flex tokens.l

clean :
	rm ba lex.yy.c  

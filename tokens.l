%{
//SHANNON HOOD
#include <stdlib.h>
#include <stdbool.h>
//opcodes
  enum {none, ADD, B, BEQ, BGE, BGT, BLE, BLT, BNE, CMP, DIV, LOAD,
        LOADA, MOD, MOVE, MUL, READ, STORE, SUB, WRITE};
  //modes
  enum {REGISTER, DIRECT, INDIRECT, IMMEDIATE};
  //cmp values
  enum{LESSTHAN, EQUALS, GREATERTHAN};
  
  unsigned char last_cmp;

  typedef struct {
    unsigned char op_code;
    unsigned char mode:5;
    unsigned char reg_no:3;

    union {
      unsigned short loc; //branch loc or direct mem (always index into array)
      short imm_const; 
      char reg_no;
    } arg2;
  } INSTR;

  INSTR prgm_text[65536];
  long int main_mem[65536];
  long int *mem_p = main_mem+1;

  typedef struct {
    char *identifier;
    unsigned short index;
    bool resolved;
  } SYM;

  SYM sym_table[65536];
  int sym_i = 0;
  long int r[8];

  int error = 0;
 
  int ln = 1;
  bool two_args = false; 
  bool is_alloc = false;

  const bool isBranch(unsigned char op) {
    return (op == B || op == BEQ || op == BGE || op == BGT || op == BLE || op == BLT || op == BNE);
  }

  void multiple_opcodes() {
    if(prgm_text[ln].op_code) {
      fprintf(stderr, "line %d: multiple_opcodes() cannot have more than one opcode per line\n", ln);
      error++;
    }
  }
%}

int                                             [0-9]+
int_const                                       [+-]?{int}
reg                                             (r[0-7])
identifier                                      [A-Za-z_][A-Za-z0-9_]*
indirect                                        (\({reg}\))
label                                           (${identifier})

mem_alloc                                       (.alloc)
decl                                            ({label}:)

two_id                                           (,{ws}?)
ws                                              [ \t]+

%%

{mem_alloc}             is_alloc = true;

{label}                 {unsigned short ptr = 0;
                          bool found = false;
                          char *new_str = (char *) malloc(yyleng+1);
                          strcpy(new_str, yytext);
                          int n = 0;
                          //look through every identifier in the symbol table
                          //until a match is found
                          while(n < 65536 && !found) { 
                            if(sym_table[n].identifier != NULL) {
                              if(!strcmp(sym_table[n].identifier, new_str)) {                           
                                fprintf(yyout, "found match, yytext = %s,  label = %s\n", new_str, sym_table[n].identifier);
                                ptr = sym_table[n].index;
                                found = true;
                              }
                            }
                            n++;
                          }
                          n = n-1;
                          if(found && sym_table[n].resolved) {
                            //do not set 2nd byte 
                            prgm_text[ln].arg2.loc = ptr;
                            fprintf(yyout, "resolved (line to branch to %d), label = %s\n", ptr, yytext);
                          } else if(!found && !sym_table[n].resolved) {
                              sym_table[sym_i].identifier = new_str;
                              //sym_table[sym_i].resolved = false;
                              sym_table[sym_i].index = ln;
                              prgm_text[ln].arg2.loc = 0;
                              fprintf(yyout, "backpatching #1 (line %d), label = %s\n", sym_table[sym_i].index, sym_table[sym_i].identifier);
                              sym_i++;
                          } else if (found && !sym_table[n].resolved) {
                              prgm_text[ln].arg2.loc = sym_table[n].index;
                             // fprintf(stdout, "backpatching again previous index %d\n)", sym_table[n].index);
                              sym_table[n].index = ln;
                              //sym_table[n].resolved = false;
                              fprintf(yyout, "backpatching again (line %d), label = %s\n", ln, sym_table[n].identifier);
                          }
                        }

(\n{decl}\n)            {ln += 2; two_args = false; is_alloc= false; //because of newlines
                        //insert label into sym_table with line number

                        char *new_str = (char *) malloc(yyleng+1);
                        strcpy(new_str, yytext);
                        new_str++; //remove 1st \n
                        strtok(new_str, "\n"); //remove 2nd \n
                        strtok(new_str, ":"); //remove :

                        bool found = false;
                        int n = 0;
                        //search table, if found
                        while(n < 65536 && !found) { 
                            if(sym_table[n].identifier != NULL) {
                              if(!strcmp(sym_table[n].identifier, new_str)) {
                                found = true;
                              }
                            }
                            n++;
                        }
                        n = n-1;
                        if(found && sym_table[n].resolved) {
                          //fprintf(stderr, "line %d: %s is not an unresolved label\n", ln-1, new_str);
                          error++;
                        } else if(found && !sym_table[n].resolved) {
                          int loop = sym_table[n].index;
                          int prev_value = prgm_text[loop].arg2.loc;
                          //printf("loop = %d, prev_value = %d\n", loop, prev_value);
                          prgm_text[loop].arg2.loc = ln;
                          bool test = true;
                          while (loop > 0 && test) {
                            loop = prev_value;
                            //printf("loop = %d, prev_value = %d\n", loop, prev_value);
                            prev_value = prgm_text[loop].arg2.loc;
                            if(prev_value == 0) test=false;
                            else {prgm_text[prev_value].arg2.loc = ln;}
                          }
                          fprintf(yyout, "backpatching complete (line %d), label = %s\n", ln, new_str);
                          sym_table[n].index = ln;
                          sym_table[n].resolved = true;
                        } else if(!found) {
                          sym_table[sym_i].index = ln;
                          sym_table[sym_i].resolved = true;
                          sym_table[sym_i].identifier =  (char *) malloc(yyleng+1);
                          strcpy(sym_table[sym_i].identifier, new_str);
                          fprintf(yyout, "\nSYMTABLE DECLARE: \"%s\", (ln %d)\n", sym_table[sym_i].identifier, sym_table[sym_i].index);
                          //sym_table[n].resolved = true;
                          sym_i++;
                        }}

({decl})                {fprintf(stderr, "label used as a branch destination must occur on a line by itself(line %d)", ln);}

(add)                   {multiple_opcodes(); prgm_text[ln].op_code = ADD; fprintf(yyout, "opcode %s ", yytext);}
(b)                     {multiple_opcodes(); prgm_text[ln].op_code = B; fprintf(yyout, "opcode %s ", yytext);}
(beq)                   {multiple_opcodes(); prgm_text[ln].op_code = BEQ; fprintf(yyout, "opcode %s ", yytext);}
(bge)                   {multiple_opcodes(); prgm_text[ln].op_code = BGE; fprintf(yyout, "opcode %s ", yytext);}
(bgt)                   {multiple_opcodes(); prgm_text[ln].op_code = BGT; fprintf(yyout, "opcode %s ", yytext);}
(ble)                   {multiple_opcodes(); prgm_text[ln].op_code = BLE; fprintf(yyout, "opcode %s ", yytext);}
(blt)                   {multiple_opcodes(); prgm_text[ln].op_code = BLT; fprintf(yyout, "opcode %s ", yytext);}
(bne)                   {multiple_opcodes(); prgm_text[ln].op_code = BNE; fprintf(yyout, "opcode %s ", yytext);}
(cmp)                   {multiple_opcodes(); prgm_text[ln].op_code = CMP; fprintf(yyout, "opcode %s ", yytext);}
(div)                   {multiple_opcodes(); prgm_text[ln].op_code = DIV; fprintf(yyout, "opcode %s ", yytext);}
(load)                  {multiple_opcodes(); prgm_text[ln].op_code = LOAD; fprintf(yyout, "opcode %s ", yytext);}
(loada)                 {multiple_opcodes(); prgm_text[ln].op_code = LOADA; fprintf(yyout, "opcode %s ", yytext);}
(mod)                   {multiple_opcodes(); prgm_text[ln].op_code = MOD; fprintf(yyout, "opcode %s ", yytext);}
(move)                  {multiple_opcodes(); prgm_text[ln].op_code = MOVE; fprintf(yyout, "opcode %s ", yytext);}
(mul)                   {multiple_opcodes(); prgm_text[ln].op_code = MUL; fprintf(yyout, "opcode %s ", yytext);}
(read)                  {multiple_opcodes(); prgm_text[ln].op_code = READ; fprintf(yyout, "opcode %s ", yytext);}
(store)                 {multiple_opcodes(); prgm_text[ln].op_code = STORE; fprintf(yyout, "opcode %s ", yytext);}
(sub)                   {multiple_opcodes(); prgm_text[ln].op_code = SUB; fprintf(yyout, "opcode %s ", yytext);}
(write)                 {multiple_opcodes(); prgm_text[ln].op_code = WRITE; fprintf(yyout, "opcode %s ", yytext);}

{reg}                   {if(two_args) {
                            char *new_str = (char *) malloc(yyleng+1);
                            strcpy(new_str, yytext);
                            prgm_text[ln].mode = REGISTER;
                            prgm_text[ln].arg2.reg_no = new_str[1];
                            fprintf(yyout, " TWO ARGS REG#: %c", new_str[1]);
                          } else {
                            char *new_str = (char *) malloc(yyleng+1);
                            strcpy(new_str, yytext);
                            prgm_text[ln].reg_no = new_str[1]; 
                            fprintf(yyout, "REG#: %c", new_str[1]);
                          }
                        }

{int_const}             {if(two_args) {
                          char *new_str = (char *) malloc(yyleng+1);
                          strcpy(new_str, yytext);
                          if(!is_alloc) {
                            prgm_text[ln].mode = IMMEDIATE; 
                            prgm_text[ln].arg2.imm_const = atoi(new_str);
                            fprintf(yyout, " two args int %d", atoi(new_str));
                          } else {
                            fprintf(yyout, "ALLOC TWO VAR: %s", new_str);
                            mem_p += atoi(new_str)-1;
                          }
                        }}

{indirect}              {if(two_args) {
                         char *new_str = (char *) malloc(yyleng+1);
                          strcpy(new_str, yytext);
                          prgm_text[ln].mode = INDIRECT; 
                          prgm_text[ln].arg2.reg_no = new_str[2];
                          fprintf(yyout, " two args indirect \"%c\"", new_str[2]);
                        }}

{identifier}           {unsigned short ptr = 0;
                          bool found = false;
                          char *new_str = (char *) malloc(yyleng+1);
                          strcpy(new_str, yytext);
                          int n = 0;
                          while(n < 65536 && !found) { 
                          if(sym_table[n].identifier != NULL) {
                            if(!strcmp(sym_table[n].identifier, new_str)) {
                              ptr = sym_table[n].index;
                              found = true;
                            }
                          }
                          n++;
                        }

                        if(!is_alloc) {  
                          //look through every identifier in the symbol table
                          //until a match is found
                          if(two_args && found) {
                            prgm_text[ln].mode = DIRECT; 
                            prgm_text[ln].arg2.loc = ptr;
                            fprintf(yyout, " %s two args direct (index %d)\n", new_str, ptr);
                          } else {
                            fprintf(stderr, "line %d: %s is not allocated\n", ln, new_str);
                            error++;
                          }
                        } else { 
                          if(!found) {
                            fprintf(yyout, "ALLOC ONE VAR: %s", new_str);
                            //associates the lowest index of available memory with the name, and reserves size 
                            //many entries in the array (so the next allocation is at name+size).
                            sym_table[sym_i].index = (mem_p - main_mem);
                            sym_table[sym_i].identifier =  (char *) malloc(yyleng+1);
                            strcpy(sym_table[sym_i].identifier, new_str);
                            fprintf(yyout, "\nSYMTABLE V IMPORTANT: %s, (index %d)\n", sym_table[sym_i].identifier, sym_table[sym_i].index);
                            sym_i++;
                            mem_p++;
                          } else {
                            fprintf(stderr, "line %d: duplicate allocation of %s\n", ln, new_str);
                            error++;
                          }
                        }}

{two_id}                two_args = true;  
\n                      {ln++; two_args = false; is_alloc = false; fprintf(yyout, "\n");}
{ws}                    /* ignore whitespace */; 
.                       {fprintf(stderr, "token %s not recognized (line %d)\n", yytext, ln); error++;}

%%

//Copy the contents at the memory location given by the 2nd argument 
//(a value of type long) into the register given as the 1st argument. 
//If the 2nd argument is an indirect reference, then the contents of the corresponding 
//register are interpreted as an index into main memory (like a pointer), and the contents of 
//memory at that index are copied
void loadOP(int n) {
  if(prgm_text[n].mode == DIRECT) {
    unsigned short reg_i = prgm_text[n].reg_no;
    unsigned short mem_loc = prgm_text[n].arg2.loc;
    r[reg_i] = main_mem[mem_loc];
   // printf("load direct called, load %ld in %d\n", mem_loc, reg_i);
  } else if(prgm_text[n].mode == INDIRECT) {
    unsigned short reg_i = prgm_text[n].reg_no;
    unsigned short indirect_reg = prgm_text[n].arg2.reg_no - '0';
    long int in_mem = r[indirect_reg];
   // printf("load indirect called, load %ld in %d\n", main_mem[in_mem], reg_i);
    r[reg_i] = main_mem[in_mem];
  }  
}

//Copy the address (i.e., the index in main memory) given by the 2nd argument 
//into the register given by the 1st argument
void loadaOP(int n) {
  if(prgm_text[n].mode == DIRECT) {
    unsigned short index = prgm_text[n].reg_no;
    unsigned short mem_loc = prgm_text[n].arg2.loc;
    r[index] = mem_loc;
    //printf("loada direct called, load %d in %ld\n", mem_loc, r[index]);
  } else if(prgm_text[n].mode == INDIRECT) {
    unsigned short reg_i = prgm_text[n].reg_no;
    unsigned short indirect_reg = prgm_text[n].arg2.reg_no - '0';
    r[reg_i] = r[indirect_reg];
    //printf("loada indirect called, load %d in %ld\n", indirect_reg, r[reg_i]);
  }   
}

//Copy the contents of the 1st argument register into 
//the memory location given by the 2nd argument  
void storeOP(int n) {
  if(prgm_text[n].mode == DIRECT) {
    unsigned short reg_i = prgm_text[n].reg_no;
    unsigned short mem_loc = prgm_text[n].arg2.loc;
    main_mem[mem_loc] = r[reg_i];
   // printf("store direct called, store %ld in %ld\n", r[reg_i], mem_loc);
  } else if(prgm_text[n].mode == INDIRECT) {
    unsigned short reg_i = prgm_text[n].reg_no;
    unsigned short reg2no = prgm_text[n].arg2.reg_no - '0';
    long int mem_loc = r[reg2no];
    main_mem[mem_loc] = r[reg_i];
   // printf("store indirect called, store %ld in %ld\n", r[reg_i], mem_loc);
  }  

}

//Copy the contents of the 2nd argument (immediate constant 
//or register) into the 1st argument (register).
void moveOP(int n) {
  if(prgm_text[n].mode == REGISTER) {
    unsigned short index1 = prgm_text[n].reg_no;
    unsigned short index2 = prgm_text[n].arg2.reg_no  - '0';
    r[index1] = r[index2];
  } else if(prgm_text[n].mode == IMMEDIATE) {
    unsigned short index = prgm_text[n].reg_no;
    r[index] = prgm_text[n].arg2.imm_const;
  }
}

//Reads from stdin a (possibly signed) integer constant,
//ignoring any whitespace or newlines preceding it
void readOP(int n) {
  int input;
  scanf("%d", &input);
  unsigned short index = prgm_text[n].reg_no;
  r[index] = input; 
}

//Outputs the contents of its register argument (as a signed long int 
//in decimal) to stdout, followed by a newline character
void writeOP(int n) {
  unsigned short index = prgm_text[n].reg_no;
  fprintf(stdout, "%ld\n", r[index]);
}

//Add the 2nd argument to the 1st argument
void addOP(int n) {
  if(prgm_text[n].mode == REGISTER) {
    unsigned short index1 = prgm_text[n].reg_no;
    unsigned short index2 = prgm_text[n].arg2.reg_no  - '0';
    r[index1] += r[index2];
  } else if(prgm_text[n].mode == IMMEDIATE) {
    unsigned short index = prgm_text[n].reg_no;
    r[index] += prgm_text[n].arg2.imm_const;
  } 
}

//Subtract the 2nd argument from the 1st argument
void subOP(int n) {
  if(prgm_text[n].mode == REGISTER) {
    unsigned short index1 = prgm_text[n].reg_no;
    unsigned short index2 = prgm_text[n].arg2.reg_no  - '0';
    r[index1] -= r[index2];
  } else if(prgm_text[n].mode == IMMEDIATE) {
    unsigned short index = prgm_text[n].reg_no;
    r[index] -= prgm_text[n].arg2.imm_const;
  }
}

//Multiply the 1st argument by the 2nd argument
void mulOP(int n) {
  if(prgm_text[n].mode == REGISTER) {
    unsigned short index1 = prgm_text[n].reg_no;
    unsigned short index2 = prgm_text[n].arg2.reg_no  - '0';
    r[index1] *= r[index2];
  } else if(prgm_text[n].mode == IMMEDIATE) {
    unsigned short index = prgm_text[n].reg_no;
    r[index] *= prgm_text[n].arg2.imm_const;
  }
}

//Divide (integer quotient) the 1st argument by the 2nd argument
void divOP(int n) {
  if(prgm_text[n].mode == REGISTER) {
    unsigned short index1 = prgm_text[n].reg_no;
    unsigned short index2 = prgm_text[n].arg2.reg_no  - '0';
    r[index1] /= r[index2];
  } else if(prgm_text[n].mode == IMMEDIATE) {
    unsigned short index = prgm_text[n].reg_no;
    r[index] /= prgm_text[n].arg2.imm_const;
  }
}

//The 1st argument gets the remainder upon dividing it by the 2nd argument
void modOP(int n) {
  if(prgm_text[n].mode == REGISTER) {
    unsigned short index1 = prgm_text[n].reg_no;
    unsigned short index2 = prgm_text[n].arg2.reg_no  - '0';
    r[index1] = r[index1] % r[index2];
  } else if(prgm_text[n].mode == IMMEDIATE) {
    unsigned short index = prgm_text[n].reg_no;
    r[index] = r[index] % prgm_text[n].arg2.imm_const;
  }
}

//If branch condition is met, change the line number to the declaration line number
void branchOP(int *n) {
  int line = *n;
  unsigned short op = prgm_text[line].op_code; 
  if((last_cmp == LESSTHAN && (op == B || op == BLT || op == BLE || op == BNE)) 
  || (last_cmp == GREATERTHAN && (op == B || op == BNE || op == BGT || op == BGE))
  || (last_cmp == EQUALS && (op == B || op == BLE || op == BGE || op == BEQ))) {
  unsigned short line_jump = prgm_text[line].arg2.loc;
   // fprintf(stdout, "branch called on line %d, jump to line %d\n", line, line_jump);
    *n = line_jump;
  }
}

//Compares the values of its two arguments and stores the result---either LESSTHAN, 
//EQUAL, or GREATERTHAN---for use by the next branch instruction
void cmpOP(int n) {
  if(prgm_text[n].mode == REGISTER) {
    unsigned short arg1 = prgm_text[n].reg_no;
    unsigned short arg2 = prgm_text[n].arg2.reg_no  - '0';
    if(r[arg1] > r[arg2]) {last_cmp = GREATERTHAN;}
    else if(r[arg1] == r[arg2]) last_cmp = EQUALS;
    else if(r[arg1] < r[arg2]) last_cmp = LESSTHAN;
  } else if(prgm_text[n].mode == IMMEDIATE) {
    int arg1 = prgm_text[n].reg_no;
    int arg2 = prgm_text[n].arg2.imm_const;
    if(r[arg1] > arg2) last_cmp = GREATERTHAN;
    else if(r[arg1] == arg2) last_cmp = EQUALS;
    else if(r[arg1] < arg2) last_cmp = LESSTHAN;
  }
}

void run() {
  for(int i = 1; i < 65536; i++) {
    if(prgm_text[i].op_code == ADD) addOP(i);                                 //tested
    if(isBranch(prgm_text[i].op_code)) branchOP(&i); //PASS BY REFERENCE      //tested
    if(prgm_text[i].op_code == CMP) cmpOP(i);                                 //tested
    if(prgm_text[i].op_code == DIV) divOP(i);                                 //tested
    if(prgm_text[i].op_code == LOAD) loadOP(i);
    if(prgm_text[i].op_code == LOADA) loadaOP(i);
    if(prgm_text[i].op_code == MOD) modOP(i);                                 //tested
    if(prgm_text[i].op_code == MOVE) moveOP(i);                               //tested
    if(prgm_text[i].op_code == MUL) mulOP(i);                                 //tested
    if(prgm_text[i].op_code == READ) readOP(i);                               //tested
    if(prgm_text[i].op_code == STORE) storeOP(i); 
    if(prgm_text[i].op_code == SUB) subOP(i);                                 //tested
    if(prgm_text[i].op_code == WRITE) writeOP(i);                             //tested


  }
}

int main(int argc, char** argv) {
  //change flex input based on args
  if(argc > 1) {
    FILE *infile;
    infile = fopen(argv[1], "r");

    if(!infile) {
      fprintf(stderr, "Could not open file %s for read\n", argv[1]);
      error++;
    }
    yyin = infile;
  }

  //change flex output
  FILE *outfile;
  outfile = fopen("yyout", "w");
  yyout = outfile;

  yylex();
  fprintf(yyout, "%d lines\n", ln-1);

  if(error == 0) {
    run();
  } else {
    fprintf(stderr, "There were %d errors---quitting.\n", error);
  }
}






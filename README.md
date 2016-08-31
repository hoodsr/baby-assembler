# baby-assembler
One-pass assembler written in flex.  This code was written as a school project, described below. 

https://cse.sc.edu/~fenner/csce531


## Usage

        ./ba <RAL code filename>

Here, <RAL code filename> is the name of the file containing a RAL program.

##Basics

Your two tasks---assembling a RAL source program and simulating its execution---are performed sequentially: Phase 1 is assembly; Phase 2 is running the internalized instructions. For Phase 1, the RAL source code will be read from a file given on the command line, and any error messages will be written to standard error (stderr). For phase 2, all input will be from standard input (stdin), and all regular output will be to standard output (stdout).

Phase 1 of your program should do some initializations then call yylex() only once. In other words, the flex pattern-matching engine should be the main driver of your assembly, and you are only allowed to make one pass through the source program (hence the term, "one-pass assembler").

RAL Syntax

Before we start, let's get our terminology straight. For our purposes,

    - by whitespace I mean any nonempty sequence of spaces and/or tabs, but no newline characters;
    - an identifier is an alphabetic character (including underscore) followed by zero or more alphanumeric characters (including underscore);
    - an integer constant is a nonempty string of digits (leading zeros are allowed and have no effect), optionally preceded by either "+" or "-" (if the "+" or "-" is absent, we say that the constant is unsigned). 

The RAL program you will parse is a text file consisting of a number of lines, each ending with a newline character. Each line contains one of three possible things: (1) a label followed by a colon; (2) a memory allocation directive; or (3) an instruction.

A line of type (1) looks like this:

$foo:

Remember that this is on a line by itself. A label is defined to be an identifier (for example, "foo") following a "$". Labels are used to indicate branching destinations.

A line of type (2) may look like

        .alloc  some_var

or like

        .alloc  some_array, 50

The ".alloc" is exactly as written (this is known as an assembler directive); some_var and some_array are any identifiers. There must be whitespace between ".alloc" and the identifier, and there is optional whitespace before ".alloc". The identifier may optionally be followed by a comma, optional whitespace, then a positive, unsigned integer constant.

A line of type (3) (i.e., a RAL instruction) starts with optional whitespace, then an instruction name (described below) followed by one or two arguments (also described below), separated from the instruction name by whitespace. If there are two arguments, they are separated by a comma (followed by optional whitespace).

There are five types of arguments (called addressing modes):

    - a register: a lowercase "r" followed by one of the digits 0-7,
    - a direct memory reference: an identifier,
    - an indirect memory reference: a register surrounded by parentheses,
    - an immediate constant: an integer constant,
    - a label. 

Immediate constants must be in the range -215 = -32768 through 215 = 32767, that is, they must fit into a signed short (two-bytes). It is up to you what you do with values out of this range (e.g., quit with an error message or just truncate them); none of the RAL source code used to test your homework will violate this range limit.

Instructions come in different types according to the arguments they require:

    - Memory access: load, loada, store. These require two arguments: first a register, then either a direct or indirect memory reference.
    - Register: move, add, sub, mul, div, mod, cmp. All these require two arguments, the first a register and the second either a register or an immediate constant.
    - Branch: b, blt, ble, bne, beq, bge, bgt. These require a single label argument (the branch destination).
    Input/output: read, write. These both require a single register argument. 

The RAL syntax guarantees that there is no naming ambiguity between variables and labels. One may use the same name for both a variable and a label in the same program with no conflict. It is entirely up to YOU, however, whether you want to allow a register name or instruction name to be used as a variable name or label. Your homework will not be tested on any RAL code that does this.

It is also up to you whether to allow whitespace at the end of a line or before a label/colon combination. No RAL source programs used for testing will have any such whitespace.

##RAL Semantics

There are eight available registers, r0 through r7, each able to hold one long int. Main memory is modeled as an array of 216 = 65536 long ints (not bytes). The address of a memory location is just its index in the array. There are only two primitive data types during execution: long (memory contents and registers) and unsigned short (used for indices (pointers)). On our lab machines, a long data type takes eight bytes and an unsigned short takes two bytes. All you need to know is that an unsigned short is automatically coerced into a long when needed, with no overflow.

Internalized instructions will also be kept in an array with 65536 entries, where each entry takes four bytes and is formatted as follows:

    - First byte: a opcode describing the name of the instruction (e.g., load, add, bge, etc.)
    - Second byte: two parts:
        bottom three bits: a constant indicating which register is used as the first argument
        upper five bits: the type of the second argument, if any 
    (this byte is not used for branch instructions).
    - Last two bytes: used for the second argument, which can vary depending on the instruction---either a code for a register, an immediate constant, an index to main memory, or a branch destination used for branch instructions. (These bytes are not used for input/output instructions.) 

The sizes of main memory and the instruction array are chosen so that an index into either array can be stored in an unsigned short (two bytes). The instruction array entry at index 0 should not be used; put the first instruction at index 1.

##Memory allocation

Variable and array names are declared using the .alloc directive. Variables and arrays are associated with chunks of main memory in the order that they are allocated. The line

        .alloc  <name>, <size>

associates the lowest index of available memory with the name, and reserves size many entries in the array (so the next allocation is at name+size). If the size argument is missing, then it is assumed to be 1. There is no distinction between variables and arrays; variables are just arrays of size 1.

All the record-keeping for allocation takes place at assembly time, not runtime. There is no runtime ("dynamic") memory allocation; all variable and array names refer to static locations determined at assembly time. When a variable/array is assigned a memory location by an .alloc directive, all future uses of that variable/array name refer to that location. To support this, you must maintain a dictionary (called a symbol table) of name-location associations during assembly. Only the locations of variables are retained after assembly; the names are forgotten.

Instructions

Most instructions, when executed, alter the state of main memory or the registers as follows:

    - load: Copy the contents at the memory location given by the 2nd argument (a value of type long) into the register given as the 1st argument. If the 2nd argument is an indirect reference, then the contents of the corresponding register are interpreted as an index into main memory (like a pointer), and the contents of memory at that index are copied.
    - loada: Copy the address (i.e., the index in main memory) given by the 2nd argument into the register given by the 1st argument.
    store: Copy the contents of the first argument register into the memory location given by the second argument.
    - move: Copy the contents of the 2nd argument (register or immediate constant) into the 1st argument (register).
    - add: Add the 2nd argument to the 1st argument.
    - sub: Subtract the 2nd argument from the 1st argument.
    - mul: Multiply the 1st argument by the 2nd argument.
    - div: Divide (integer quotient) the 1st argument by the 2nd argument.
    mod: The 1st argument gets the remainder upon dividing it by the 2nd argument. 

Note that in all the register instructions, the first argument holds the result and the second argument (if it is a register) is unchanged.

The comparison instruction cmp compares the values of its two arguments and stores the result---either LESSTHAN, EQUAL, or GREATERTHAN---for use by the next branch instruction (see Control Flow, below).

##Control flow

When a RAL program is run, instructions are normally executed in the order they appear in the source, starting with the first instruction. The execution order can only be altered by a branch instruction, whence, if the branch condition is met, the next instruction executed is the one immediately following the type (1) line containing the branch destination label. This altered flow is called a branch or jump.

The branch condition is determined by the branch instruction and the result of the most recently executed cmp instruction. For example, in the code

                move    r0, 17
                move    r1, 18
                cmp     r0, r1
                blt     $hop_over
                add     r0, r1
                cmp     r0, r1
                bge     $byebye
        $hop_over:
                sub     r1, r0
        $byebye:
                ...

the branch to $hop_over is taken by the first blt instruction, because the result of the previous comparison was LESSTHAN. If instead, the first two instructions were

        move    r0, 18
        move    r1, 17

then the first branch would not be taken, and control would continue normally to the add instruction. (The second branch would be taken in this case.)

The branch is taken based on the result of the last comparison as follows:

    - LESSTHAN: take branch with b, blt, ble, bne
    - EQUAL: take branch with b, ble, beq, bge
    - GREATERTHAN: take branch with b, bne, bge, bgt 

Note that b executes an unconditional branch.

The branch instruction need not follow the comparison immediately. There may be several non-comparison instructions in between.

Execution finishes when control falls past the last instruction in the program.

## Input and output

The write instruction outputs the contents of its register argument (as a signed long int in decimal) to stdout, followed by a newline character. No special output formatting is done.

The read instruction reads from stdin a (possibly signed) integer constant, ignoring any whitespace or newlines preceding it. You can call the C library function scanf to accomplish this. A C++ equivalent is

    cin >> some_location_of_type_long

## A sample RAL program

Here is a little program that reads in 20 numbers from input and outputs them in reverse order:

        .alloc  numlist, 10
        loada   r0, numlist
        move    r1, r0
        add     r1, 20
$read_loop:
        cmp     r0, r1
        bge     $write_loop
        read    r2
        store   r2, (r0)
        add     r0, 1
        b       $read_loop
$write_loop:
        loada   r1, numlist
        cmp     r0, r1
        ble     $quit
        sub     r0, 1
        load    r2, (r0)
        write   r2
        b       $write_loop
$quit:

## Backpatching

As you assemble, you maintain a dictionary of label-location pairs, so that you can translate a label used as a branch destination into the actual destination (as an index into the array of instructions). This is fine as long as the label has already appeared followed by a colon on a line by itself. But this may not be the case; a branch may be forward to a destination further down in the code, as in the example above (the first branch to $write_loop and the branch to $quit). In fact, you may have several forward branches to the same label. Because you can only make one pass on the input, you might not know the destination of a branch when it appears. For each such unresolved label, you must keep a list of branch instructions that use that label as a forward branch destination. When (or if) the label is resolved, you then go back and fill in the correct destination into those branch instructions.

A particularly space-efficient way of handling forward branches is by embedding the (linked) list of unresolved forward branch instructions in the branch instructions themselves. This technique is known as backpatching. When you first encounter a forward branch to some label $foo, you enter $foo as a new key into the dictionary of unresolved labels with the index of the current branch instruction, say, x, as its value. You also enter enter 0 for the branch destination of instruction x (recall that 0 is not the index of any instruction). The next time you encounter $foo as a forward branch in some instruction y > x, you place x as the branch destination in instruction y then update the value of $foo in the dictionary from x to y. You continue this process for each subsequent occurrence of $foo as a forward branch: place the location of the previous forward branch to $foo in the current instruction and update the dictionary with the current instruction location. When $foo is resolved, you have a linked list of its forward branches embedded in the instructions themselves, which you can then resolve one by one. I will also discuss this in class.

## Error checking

You need to check for the following semantic errors:

    - A variable or array name must be introduced by an .alloc directive in the source code above where it is used as an argument.
    - The same name cannot be used in more than one .alloc directive.
    - No memory allocation may exceed the bounds of the memory array.
    - Any label used as a branch destination must occur exactly once on a line by itself, followed by a colon. The latter need not occur before the label's first use as a branch destination, however (see Backpatching, above). That is, all labels must have been resolved to unique instruction indices when assembly ends. 

When you encounter one of these errors, you must issue some appropriate error message to stderr and keep assembling, but you do not proceed to Phase 2 (execution). There will be no other types of errors in any RAL sources used to test your code, so what you do upon encountering some other error (e.g., a syntax error) is entirely up to you, including promptly quitting the program.

You need not check for any run-time errors. 

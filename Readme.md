# µC Scanner
A simple scanner for [µC programming language](https://www.it.uu.se/katalog/aleji304/CompilersProject/uc.html).

## Prerequisite
* Environment
    - Linux (Ubuntu 16.04 LTS (or later)
* Lexical analyzer (Flex) and syntax analyzer (Bison):
    ```
    sudo apt-get install flex bison
    ```

## Usage
1. compile
    ```
    make
    ```
2. scan the input µC program
    ```
    ./myscanner < ./example_input/xxx.c
    ```

## Example
- µC program:
    ```C
    int foo(int a) {
        a += 6;
        return a;
    }

    void lol(int a) {
        print(a);
        return;
    }

    void main(){
        int a;
        a = foo(4);
        lol(a);
        return;
    }

    ```

- scanning result
    ```
    int      INT
    foo      ID
    (        LB
    int      INT
    a        ID
    )        RB
    {        LCB
    a        ID
    +=       ADDASGN
    6        I_CONST
    ;        SEMICOLON
    return   RET
    a        ID
    ;        SEMICOLON
    }        RCB
    void     VOID
    lol      ID
    (        LB
    int      INT
    a        ID
    )        RB
    {        LCB
    print    PRINT
    (        LB
    a        ID
    )        RB
    ;        SEMICOLON
    return   RET
    ;        SEMICOLON
    }        RCB
    void     VOID
    main     ID
    (        LB
    )        RB
    {        LCB
    int      INT
    a        ID
    ;        SEMICOLON
    a        ID
    =        ASGN
    foo      ID
    (        LB
    4        I_CONST
    )        RB
    ;        SEMICOLON
    lol      ID
    (        LB
    a        ID
    )        RB
    ;        SEMICOLON
    return   RET
    ;        SEMICOLON
    }        RCB

    Parse over, the line number is 16.

    comment: 0 lines
    ```

### STAR this repo if you like it!
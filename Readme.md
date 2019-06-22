# µC Parser
A simple parser for [µC programming language](https://www.it.uu.se/katalog/aleji304/CompilersProject/uc.html).

The grammar used here is based on [ANSI C Yacc grammar rules](http://www.quut.com/c/ANSI-C-grammar-y.html) basically.

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
2. parser the input µC program
    ```
    ./myparser < ./example_input/xxx.c
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

- parsing result
    ```
    1:
    2: int foo(int a) {
    3:    a += 6;
    4:    return a;
    5: }

    Index     Name      Kind        Type      Scope     Attribute 

    0         a         parameter   int       1         

    6:
    7: void lol(int a) {
    8:     print(a);
    9:      return;
    10: }

    Index     Name      Kind        Type      Scope     Attribute 

    0         a         parameter   int       1         

    11:
    12: void main(){
    13:    int a;
    14:    a = foo(4);
    15:    lol(a);
    16:    return;
    17: }

    Index     Name      Kind        Type      Scope     Attribute 

    0         a         variable    int       1         


    Index     Name      Kind        Type      Scope     Attribute 

    0         foo       function    int       0         int
    1         lol       function    void      0         int
    2         main      function    void      0         


    Total lines: 17

    ```

### STAR this repo if you like it!
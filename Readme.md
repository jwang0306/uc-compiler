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
    1: int foo(int a) {
    2:    a += 6;
    3:    return a;
    4: }

    Index     Name      Kind        Type      Scope     Attribute 

    0         a         parameter   void      1         

    5:
    6: void lol(int a) {
    7:     print(a);
    8:      return;
    9: }

    Index     Name      Kind        Type      Scope     Attribute 

    0         a         parameter   void      1         

    10:
    11: void main(){
    12:    int a;
    13:    a = foo(4);
    14:    lol(a);
    15:    return;
    16: }

    Index     Name      Kind        Type      Scope     Attribute 

    0         a         variable    void      1         


    Index     Name      Kind        Type      Scope     Attribute 

    0         foo       function    void      0         void
    1         lol       function    void      0         void
    2         main      function    void      0         


    Total lines: 16
    ```

### STAR this repo if you like it!
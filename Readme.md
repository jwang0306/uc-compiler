# µC Compiler
A simple [µC programming language](https://www.it.uu.se/katalog/aleji304/CompilersProject/uc.html) compiler for Java Assembly Code Generation.

The grammar used here is based on [ANSI C Yacc grammar rules](http://www.quut.com/c/ANSI-C-grammar-y.html) basically.

## Prerequisite
* Environment
    - Linux (Ubuntu 16.04 LTS (or later)
* Lexical analyzer (Flex) and syntax analyzer (Bison):
    ```
    sudo apt-get install flex bison
    ```
* Java Virtual Machine (JVM):
    ```
    sudo add-apt-repository ppa:webupd8team/java
    sudo apt-get update
    sudo apt-get install default-jre
    ```

## Usage
1. compile
    ```
    make
    ```
2. generate java asembly code
    ```
    ./myparser < ./example_input/xxx.c
    ```
3. translate to java bytecode
    ```
    java -jar jasmin.jar uc_compiler.j
    ```
4. run by JVM and output the executed result
    ```
    java uc_compiler
    ```
## Example
- µC program:
    ```
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

- generated java asembly code
    ```
    .class public uc_compiler
    .super java/lang/Object
    .method public static foo(I)I
    .limit stack 50
    .limit locals 50
        ldc 6
        iload 0
        swap
        iadd
        istore 0
        iload 0
        ireturn
    .end method
    .method public static lol(I)V
    .limit stack 50
    .limit locals 50
        iload 0
        getstatic java/lang/System/out Ljava/io/PrintStream;
        swap
        invokevirtual java/io/PrintStream/println(I)V
        return
    .end method
    .method public static main([Ljava/lang/String;)V
    .limit stack 50
    .limit locals 50
        ldc 0
        istore 0
        ldc 4
        invokestatic uc_compiler/foo(I)I
        istore 0
        iload 0
        invokestatic uc_compiler/lol(I)V
        return
    .end method

    ```
- executed result
    ```
    10
    ```

## Work flow
![](https://i.imgur.com/2XDz97R.png)

### STAR this repo if you like it!
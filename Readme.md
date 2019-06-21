# µC Compiler

A simple compiler for the [µC programming language](https://www.it.uu.se/katalog/aleji304/CompilersProject/uc.html).

## Prerequisite
### Environment
* Linux (Ubuntu 16.04 LTS (or later)
### Lexical analyzer (Flex) and syntax analyzer (Bison):
```
sudo apt-get install flex bison
```
### Java Virtual Machine (JVM):
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
    ./myparser < ./example_input/test.c 
    ```
3. generate JVM class
    ```
    java -jar jasmin.jar uc_compiler.j
    ```
4. run on JVM
    ```
    java uc_compiler
    ```
## Example


## Work flow
![](https://i.imgur.com/2XDz97R.png)
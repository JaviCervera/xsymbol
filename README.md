# XSymbol

XSymbol is a purely symbolic functional programming language that I developed around 2007 while being a student of Software Engineering at the Technical University of Madrid. I was learning functional programming in Lisp and thought it would be nice to create my own functional language. It interpreted and dynamically typed, and the interpreter was written in [BlitzMax](https://github.com/blitz-research/blitzmax), a commercial programming language that was quite popular in the indie game development scene back then. Since it is now open source, installers for Windows, macOS and Linux have been added to the [v1.0 release](https://github.com/JaviCervera/xsymbol/releases/tag/v1.0).

To build the interpreter, compile "XSymbolRun.bmx" using BlitzMax. The generated interpreter can then be used like this:

```
XSymbolRun file.sym [arguments]
```

The optional arguments will be passed as a list to the `@main` function of the script, which is the entry point of an XSymbol program.

## Syntax

Some words have a special meaning:

* `id` indicates an identifier. Identifiers begin with a letter or an underscore, and are followed by any sequence of numbers, letters or underscores.
* `exp` indicates an expression. All arithmetic operations are prefixed in XSymbol, so `2 + 2` is expressed as `+ 2 2`.
* `prm` indicates a parameter, which have the same naming rules as any identifier. Functions in XSymbol have a single parameter. To support multiple parameters, pass a list with all the values as argument and handle them using [argument unpacking](#argument-unpacking).
* Square brackets (`[]`) are used to indicate an optional construct.
* Curly brackets (`{}`) are used to indicate a construct that can appear multiple times (at least once). Each repetition is separated with one or more whitespaces.

The syntax rules are quite simple and are briefly explained below:

* `'`: Begins a single line comment.
* `({exp})`: Creates a new list.
* `+ exp exp`: Addition.
* `- exp exp`: Subtration.
* `* exp exp`: Multiplication.
* `/ exp exp`: Division.
* `% exp exp`: Division remainder.
* `& exp exp`: Logic and.
* `| exp exp`: Logic or.
* `! exp`: Logic not.
* `= exp exp`: Equality comparison.
* `< exp exp`: "Lesser than" comparison.
* `> exp exp`: "Greater than" comparison.
* `<= exp exp`: "Lesser or equal to" comparison.
* `>= exp exp`: "Greater or equal to" comparison.
* `id exp`: Calls the function named `id`, passing the expression value as argument.
* `? exp {exp} : {exp};`: If the first expression evaluates to true, executes the second block of expressions; otherwise, runs the third block of expressions.
* `@ id prm {exp};`: Defines a function named `id`.

### Argument unpacking

XSymbol functions receive a single argument. If we want tu pass multiple values, we must group them in a list. This list could then be processed by the function like this:

```
@foo x
  print get (x 1)
  print get (x 2)
  print get (x 3)
;
```

The function could be called as `foo (0 10 30)`, which would print `0`, `10`, and `30` in three separate lines. But this way of defining a function is inconvenient, since it is not explicit about how many values are expected in the list, and the way to access each element is too verbose. For this reason, XSymbol supports syntactic sugar to unpack the values of a list passed as argument into their own identifiers:

```
@foo (x y z)
  print x
  print y
  print z
;
```

### Builtin functions

```
print string
```
Prints the indicated string to the console.

```
car list
```
Returns the first element in a list.

```
cdr list
```
Returns a list with all the elements of the given list except for the first one.

```
list exp
```
Indicates whether the given expression is a list or not.

```
null exp
```
Indicates whether the given expression is an empty list or not.

```
get (list index)
```
Returns the specified element from the list. Indices start couting at `1` in XSymbol.

```
cat (list1 list2)
```
Returns a list with all the elements from both lists concatenated.

```
random (min max)
```
Returns a pseudo random number between `min` and `max`.

```
val string
```
Returns the string converted to a number. For example, for `"367.28"` it gives `367.28`.

```
str number
```
Returns the number converted to a string. For example, for `245` it gives `"245"`.

```
strcat ({string})
```
Returns a string with all the elements in the given list concatenated.

```
inc number
```
Returns the given number incremented in one.

```
dec number
```
Returns the given number decremented in one.

```
zero number
```
Indicates whether the given number is zero.

## Examples

In order to learn the language syntax, you can run the file "test.sym". Other examples are provided here:

```
' Adds all the elements in a list (they must be numbers)
@add x
  ? null x
    0
  :
    + car x  add cdr x
  ;
;
```

```
' Counts the number of elements in a list
@ count x
  ? null x
    0
  :
    inc count cdr x
  ;
;
```

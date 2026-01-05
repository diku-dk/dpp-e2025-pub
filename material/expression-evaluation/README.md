# Material for expression evaluation

The file [arithmetic.alp](arithmetic.alp) looks as follows:

```
num = \-?[0-9]+;
var = [a-z]+;
ignore = \s|\n|\t|\r;

E0 = E1 E0';
E0' = "+" E1 E0'
    | "-" E1 E0'
    | ;
E1 = E2 E1';
E1' = "*" E2 E1'
    | "/" E2 E1'
    | ;
E2 = "(" E0 ")"
   | num
   | var;
```

It defines an unambiguous grammar without left recursion for arithmetic
expressions with integers, variables, parentheses. The first three lines define
terminals, and the remaining defines the various nonterminals, with one line per
production.

This is a grammar that can be processed with
[alpacc](https://github.com/diku-dk/alpacc) to produce a parallel lexer and
parser expresed in Futhark:

```
$ alpacc futhark --lookback 1 --lookahead 1 arithmetic.alp
```

This produces the program [arithmetic.fut](arithmetic.fut), which defines a
function `parse` that parse a string according to the grammar. We can load it
into `futhark repl` and try it out:

```
> parse "123+456"
#some [(0, #production 0),
       (0, #production 4),
       (1, #production 9),
       (2, #terminal 0 (0, 3)),
       (1, #production 7),
       (0, #production 1),
       (5, #terminal 5 (3, 4)),
       (5, #production 4),
       (7, #production 9),
       (8, #terminal 0 (4, 7)),
       (7, #production 7),
       (5, #production 3)]
```

What we get back is a *derivation array* - a description of how to apply the
productions in order to obtain the given input. This array also encodes the
*concrete syntax tree* (CST). Each tuple element represents a node:

* The first component of each tuple is the parent of the node. Note how the
  root, the first element, is its own parent.

* The second component describes what kind of node it is. Production nodes are
  tagged with the index of the production in the grammar, starting from zero.
  Terminal nodes contain a number defining which terminal (which is usually not
  meaningful), and also indexes into the input denoting the position of the
  terminal. This can be used to retrieve the actual underlying text.

Many of the productions contain no meaningful information and are artifacts of
how the grammar has been expressed - these should be removed in order to produce
an *abstract syntax tree* (AST). Further, if you draw the tree for various
inputs (write a program to do this) you will see that the structure is a bit
odd, although perhaps suitable enough for evaluation.

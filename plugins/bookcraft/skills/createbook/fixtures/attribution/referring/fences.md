# Fenced examples

Chapter 1 shows a list, fenced:

```text
- chapter 9 is where "this fenced line is an example and quotes nothing"
```

~~~
A tilde fence carries [9-9], which no book defines.
~~~

````markdown
```
[9-8] sits after a three-backtick line, which does not close a four-backtick fence.
```
````

A declaration shown in a fence declares nothing, so this file still cites only the book it is checked against:

```markdown
<!-- cites: The Companion Guide (default) -->
```

Chapter 2 sets out the steps:

```text
- a step
```

- "a quotation the second chapter never makes, and inherits nothing"

```inline``` written at the head of a line opens no fence, since a backtick fence's info string holds no backtick, so the tag on the next line is read.
[1-1] is cited here, outside any fence.

# MetaMerge.jl
Merge functions with identical names from distinct modules 

Suppose in our main module we create a function `f`: 

```
julia> f() = nothing
f (generic function with 1 method)
```

Suppose also that we also intend to use the following modules A and B:

```julia
module A

export f, g
immutable Foo end
f(::Foo) = print("This is Foo.")
f(x::Int64) = x
g(::Foo) = print("This is also Foo")

end

module B

export f, g
immutable Bar end
f(::Bar) = print("This is Bar.")
f(x::Int64) = 2x
g(::Bar) = print("This is also Bar")

end
```

As of Julia 3.7, unqualified use of a name common to both modules -- say, the name '`f`' -- will elicit behavior that depends on the order in which we declare to be `using` the modules:

```
julia> using A, B
Warning: using A.f in module Main conflicts with an existing identifier.
Warning: using B.f in module Main conflicts with an existing identifier.

julia> methods(f)
# 1 method for generic function "f":
f() at none:1

julia> f(A.Foo())
ERROR: `f` has no method matching f(::Foo)

julia> A.f(A.Foo())
This is Foo.
```

But suppose we want unqualified use of '`f`' to refer to the correct object `f` --- either `f`, `A.f` or `B.f` --- depending on the signature of the argument on which `f` is called. The present "package" offers this functionality through the `metamerge()` function, which "merges" the methods of `A.f` and `B.f` into our original function `f` as defined in `Main`. (At its core, this is just extending the `f` defined in `Main`.) This allows unqualified use of the name '`f`' to dispatch on signatures for which methods are defined in other modules:

```
julia> metamerge(f, A, B)
f (generic function with 3 methods)

julia> f(A.Foo())
This is Foo.
julia> f(B.Bar())
This is Bar.
```

Note that no method for the signature `(x::Int64,)` was merged since both `A.f` and `B.f` have methods for this signature. To choose one to merge, use the optional `conflicts_favor` keyword argument:
```
julia> metamerge(f, A, B, conflicts_favor=A)
f (generic function with 4 methods)

julia> f(2)
2
```
If the `conflicts_favor` argument is omitted, then only those methods whose signatures unambiguously specify precisely one of `A.f` or `B.f` will be merged.


IMPORTANT: The name '`f`' must refer to a function that lives in the module in which `metamerge()` is called:

```
julia> whos()
A                             Module
B                             Module
Base                          Module
Core                          Module
Main                          Module
__metamerge#1__               Function
__metamerge#2__               Function
ans                           Int64
f                             Function
makemethod                    Function
metamerge                     Function
```

Otherwise, `metamerge(f, A, B)` will try to extend an `f` that lives in either `A` or `B` (depending on the order in which they were declared to be used). In general, this will fail. Thus, at least in Julia 3.7, one must define a function named '`f`' *before* `using` the modules `A` and `B`. Right now this can be inconvenient. However, I expect this situation will change in Julia 4.0, in which (as I understand it) new rules for importing conflicting names from different modules are adopted. 

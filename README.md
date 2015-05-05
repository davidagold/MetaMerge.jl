# MetaMerge.jl

Suppose we create a function `f` in `Main`: 

```
julia> f() = nothing
f (generic function with 1 method)
```

Suppose also that we also intend to use the following modules `A` and `B`:

```julia
module A

export f
immutable Foo end
f(::Foo) = print("This is Foo.")
f(x::Int64) = x

end

module B

export f
immutable Bar end
f(::Bar) = print("This is Bar.")
f(x::Int64) = 2x

end
```

As of Julia 0.3.7, unqualified use of a name common to both modules -- say, the name '`f`' -- will elicit behavior that depends on the order in which we declare to be `using` the modules:

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

But suppose we want unqualified use of '`f`' to refer to the correct object --- either `f`, `A.f` or `B.f` --- depending on the signature of the argument on which `f` is called. The present "package" offers this functionality through the `merge!()` function, which "merges" the methods of `A.f` and `B.f` into our original function `f` as defined in `Main`. (At its core, this is just extending the `f` defined in `Main`.) This allows unqualified use of the name '`f`' to dispatch on signatures for which methods are defined in other modules:

```
julia> merge!(f, (A,f), (B,f))

julia> methods(f)
# 3 methods for generic function "f":
f() at none:1
f(x1::Foo)
f(x1::Bar)

julia> f(A.Foo())
This is Foo.
julia> f(B.Bar())
This is Bar.
```

Note that no method for the signature `(x::Int64,)` was merged since both `A.f` and `B.f` have methods for this signature. To choose one to merge, use the optional `conflicts_favor` keyword argument:

```
julia> merge!(f, (A,f), (B,f), conflicts_favor=A)

julia> methods(f)
# 4 methods for generic function "f":
f() at none:1
f(x1::Foo)
f(x1::Bar)
f(x1::Int64)

julia> f(2)
2
```

If the `conflicts_favor` argument is omitted, then only those methods whose signatures unambiguously specify precisely one of `A.f` or `B.f` will be merged.

One can call `merge!()` in modules other than `Main`. 


```julia
module C

export f
using MetaMerge, A, B
f(::Union()) = nothing
merge!(f, (A,f), (B,f), conflicts_favor=A)
h(x::Int64) = f(x)

end
```
The result is that unqualified use of `f` in the module `C` will dispatch across methods defined for `A.f` and `B.f`. We can check this in the REPL:

```
julia> methods(C.f)
# 4 methods for generic function "f":
f(::None) at none:5
f(x1::Foo)
f(x1::Int64)
f(x1::Bar)

julia> C.h(2)
2
```

I hope that this versatility makes `merge!()` suitable for more general use outside the REPL.

One is also free to `merge!()` functions of different names

```
julia> p() = nothing
p (generic function with 1 method)

julia> merge!(p, (A,f), (C,C.h), conflicts_favor=C)

julia> methods(p)
# 3 methods for generic function "p":
p() at none:1
p(x1::Foo)
p(x1::Int64)

julia> p(2)
2
```
(Note that since the name '`h`' was not exported in module `C` we must refer to it by '`C.h`' in the argument of `merge!()`) and also functions from the same module:

```
julia> q(x::Float64) = x
q (generic function with 1 method)

julia> merge!(q, (Main, p), (Main, q))
Warning: Method definition q(Float64,) in module Main at none:1 overwritten in module MetaMerge.

julia> methods(q)
# 4 methods for generic function "q":
q(x1::Float64)
q()
q(x1::Foo)
q(x1::Int64)

julia> q(2)
2

julia> q(A.Foo())
This is Foo.
```

## To do:

1. Currently, `merge!()` only handles two `(Module, Function)` tuples in its argument. In the future, one should be able to call `merge!()` on any number of such arguments, e.g. `merge!(f, (A,f))` or `merge!(f, (A,f), (B,f), (C,f))`.
2. Currently, if one wants to merge multiple functions from two+ modules, one has to `merge!()` each set of names individually. In the future, there should be a `mergeall()` function that automatically merges all commonly named functions between two modules, e.g. `mergeall(A, B, conflicts_favor=A)` generates a list of function names common to `A` and `B` and `merge!`s them.

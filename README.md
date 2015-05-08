# MetaMerge.jl

This package is not currently registered, but you can use the REPL to clone it for yourself with
```
julia> Pkg.clone("git://github.com/davidagold/MetaMerge.jl.git")
```
### What's new (as of v0.3)
1. Changed 'merge!()' to 'fmerge!()' in order to avoid potential name conflicts with base (wouldn't that be ironic?). I don't plan on doing this ever again.
2. Added support for arbitrary number of `(::Module, ::Function)` arguments for `fmerge!()`.
3. Added "tracking mechanism" of sorts for methods added via `fmerge!()` (see below).


### Motivation & example usage

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

But suppose we want unqualified use of '`f`' to refer to the correct object --- either `f`, `A.f` or `B.f` --- depending on the signature of the argument on which `f` is called. The present "package" offers this functionality through the `fmerge!()` function, which "merges" the methods of `A.f` and `B.f` into our original function `f` as defined in `Main`. (At its core, this is just extending the `f` defined in `Main`.) This allows unqualified use of the name '`f`' to dispatch on signatures for which methods are defined in other modules:

```
julia> fmerge!(f, (A,f), (B,f))

julia> methods(f)
# 3 methods for generic function "f":
f() at none:1
f(x1_A::Foo)
f(x1_B::Bar)

julia> f(A.Foo())
This is Foo.
julia> f(B.Bar())
This is Bar.
```
For merged methods with at least one argument, the name of the module from which the method originates is appended to the first argument in the method definition, as can be seen above. This can help one keep track of which methods come from which modules. However, this machinery only keeps track of the most recent module from which the method originates. If a method has been merged multiple times through multiple modules, its ultimate origin will be obscured.

Note that no method for the signature `(x::Int64,)` was merged since both `A.f` and `B.f` have methods for this signature. To choose one to merge, use the optional `priority` keyword argument, which takes an array of `(::Module, ::Function)` tuples in the order of priority rank:

```
julia> fmerge!(f, (A,f), (B,f), priority=[(A,f)])

julia> methods(f)
# 4 methods for generic function "f":
f() at none:1
f(x1_A::Foo)
f(x1_B::Bar)
f(x1_A::Int64)

julia> f(3)
3
```
If, for a given signature, a method exists in both `Module1.f` and `Module2.f`, then the method from whichever of `(Module1, f)`, `(Module2, f)` with the greater rank (so *lower* numerical rank, e.g. 1 is greatest) will be merged. `(::Module, ::Function)` arguments passed to `fmerge!()` but omitted from `priority` are by default given the lowest possible rank. If `(Module1, f)`, `(Module2, f)` have the same rank (which will only occur if they are not specified in `priority`) then neither method will be merged. This means that if one omits the `priority` argument, then only those methods whose signatures unambiguously specify precisely one of the `(::Module, ::Function)` arguments passed to `fmerge!()` will be merged.

WARNING: As of yet I haven't figured out how to use reflection to distinguish between otherwise identical signatures with user-defined *types* of the same name. Thus if module `B` above also defined a `Foo` type and defined a method for `f(::Foo)`, these two methods would be seen to conflict by `fmerge!()`. 

One can call `fmerge!()` in modules other than `Main`. 


```julia
module C

export f
using MetaMerge, A, B
f(::Union()) = nothing
fmerge!(f, (A,f), (B,f), conflicts_favor=A)
h(x::Int64) = f(x)

end
```
The result is that unqualified use of `f` in the module `C` will dispatch across methods defined for `A.f` and `B.f`. We can check this in the REPL:

```
julia> methods(C.f)
# 4 methods for generic function "f":
f(::None) at none:5
f(x1_A::Foo)
f(x1_A::Int64)
f(x1_B::Bar)

julia> C.h(2)
2
```

I hope that this versatility makes `fmerge!()` suitable for more general use outside the REPL.

One is also free to `fmerge!()` functions of different names, as well as functions from the same module.


## To do:

1. ~~Currently, `merge!()` only handles two `(Module, Function)` tuples in its argument. In the future, one should be able to call `merge!()` on any number of such arguments, e.g. `merge!(f, (A,f))` or `merge!(f, (A,f), (B,f), (C,f))`.~~ featured in v0.3. 
2. Currently, if one wants to merge multiple functions from two+ modules, one has to `merge!()` each set of names individually. In the future, there should be a `mergeall()` function that automatically merges all commonly named functions between two modules, e.g. `mergeall(A, B, conflicts_favor=A)` generates a list of function names common to `A` and `B` and `merge!`s them.
3. Find a way to handle name clashes of user defined types from different modules (WARNING above). 

module MetaMerge

export metamerge

function makemethod(f::Function, argtypes::Tuple, modulename::Symbol)

    # Note that passing a value such as 'A.f' to makemethod() will drop the module
    # from the function name. We must therefore add it to the expression passed to
    # RHS (below):
    expr_Mf = Expr(:., modulename, QuoteNode(symbol("$f")))

    # Expression calling 'newf'
    LHS = Expr(:call, symbol("$f"))

    # Expression calling 'oldf' with proper module prefix
    RHS = Expr(:call, expr_Mf)

    # Adds argument symbols with type annotations to signature of call to 'newf'
    # Adds just argument symbols to call of 'oldf'
    for (i, arg) in enumerate(argtypes)
        push!(LHS.args, Expr(:(::), symbol("x$i"), arg))
        push!(RHS.args, symbol("x$i"))
    end
    # println(LHS)
    # println(RHS)

    # Sets the calls of 'newf' and 'oldf' equal to one another and evaluates.
    exeq = Expr(:(=), LHS, RHS)
    @eval($exeq)
end

function metamerge(f::Function, module_A::Module, module_B::Module; conflicts_favor=Module)

    # Generate symbols for $module_A.$f, $module_B.$f
    expr_fA = Expr(:., symbol("$module_A"), QuoteNode(symbol("$f")))
    expr_fB = Expr(:., symbol("$module_B"), QuoteNode(symbol("$f")))

    # Generate calls to functions $module_A.$f, $module_B.$f
    expr_fAcall = Expr(:call, expr_fA)
    expr_fBcall = Expr(:call, expr_fB)

    # Generate arrays of Method objects for f, g
    const fA_methods = methods(@eval($expr_fA), (Any...))
    const fB_methods = methods(@eval($expr_fB), (Any...))

    # Generate arrays of method signatures for A.f, B.f.
    # Note that the 'sig' field of a Method is (as of 3.7) a tuple of types.
    fA_sigs = [ fA_methods[i].sig for i in 1:length(fA_methods) ]
    fB_sigs = [ fB_methods[i].sig for i in 1:length(fB_methods) ]

    # Generate array of overlapping signatures of A.f, B.f, i.e. ambiguous cases.
    const AB_intr = intersect(fA_sigs, fB_sigs)

    # Adjust either fA_sigs or fB_sigs according to whether caller wishes cases
    # of ambiguous signatures to be handled by A.f or B.f. If 'conflicts_favor'
    # is void or equal to neither A nor B, then no method is assigned for the
    # ambiguous signature.
    if conflicts_favor == A
        fB_sigs = setdiff(fB_sigs, AB_intr)
    elseif conflicts_favor == B
        fA_sigs = setdiff(fA_sigs, AB_intr)
    else
        fB_sigs = setdiff(fB_sigs, AB_intr)
        fA_sigs = setdiff(fA_sigs, AB_intr)
    end

    # Loop through elements of fA_sigs and assign appropriate methods of A.f to f
    for (i, sig) in enumerate(fA_sigs)
        # println(sig)
        makemethod(f, sig, symbol("$module_A"))
    end

    # Loop through elements of fB_sigs and assign appropriate methods of B.f to f
    for (i, sig) in enumerate(fB_sigs)
        # println(sig)
        makemethod(f, sig, symbol("$module_B"))
    end

    return f

end # Function metamerge(f::Function, module_A::Module, module_B::Module; conflicts_favor=Module)

function metamerge(module_A::Module, module_B::Module; conflicts_favor=Module)

    const names_A = names(module_A)
    const names_B = names(module_B)

    # Initialize arrays of functions with names exported by A, B
    const functions_A = Any[]
    const functions_B = Any[]

    # Add to functions_A functions exported by A
    for (i, name) in enumerate(names_A)
        A_name = Expr(:(.), symbol("$module_A"), QuoteNode(symbol("$name")))
        println(A_name)
        isa(eval(A_name), Function) == true && push!(functions_A, eval(name))
    end

    # Add to functions_B functions exported by B
    for (i, name) in enumerate(names_B)
        B_name = Expr(:(.), symbol("$module_B"), QuoteNode(symbol("$name")))
        isa(eval(B_name), Function) == true && push!(functions_B, eval(name))
    end

    # Generate an array of functions exported and identically named by both A and B
    const functions_intr = intersect(functions_A, functions_B)

    # Merge functions in functions_intr
    for (i, f) in enumerate(functions_intr)
        metamerge(f, module_A, module_B, conflicts_favor=@eval($conflicts_favor))
        println("Merged function $f with methods from $module_A, $module_B.")
    end

end # Function metamerge(module_A::Module, module_B::Module; conflicts_favor=Module)

end # Module MetaMerge

module MetaMerge

importall Main

export merge!

function makemethod(expr_fmerged, expr_fmodule::Expr, argtypes::Tuple)

    # Expression calling fmerged
    LHS = Expr(:call, expr_fmerged)

    # Expression calling function denoted by expr_fmodule
    RHS = Expr(:call, expr_fmodule)

    # Adds argument symbols with type annotations to signature of call to 'fmerged'
    # Adds just argument symbols to call of 'fmodule'
    for (i, arg) in enumerate(argtypes)
        push!(LHS.args, Expr(:(::), symbol("x$i"), arg))
        push!(RHS.args, symbol("x$i"))
    end
    # println(LHS)
    # println(RHS)

    # Set the calls of 'newf' and 'oldf' equal to one another and evaluates.
    ex_eq = Expr(:(=), LHS, RHS)

    # Generate method
    # println(ex_eq)
    eval(ex_eq)
end

function merge!(fmerged::Function, modfuncA::(Module, Function), modfuncB::(Module, Function); conflicts_favor=nothing)

    # Generate symbol for module calling mergemethods()
    # Hereafter the calling module will be known as 'here'.
    symb_here = symbol("$(current_module())")

    # Generate expression for Main.here.fmerged
    expr_here = Expr(:., symbol("Main"), QuoteNode(symb_here))
    expr_fmerged = Expr(:., expr_here, QuoteNode(symbol("$fmerged")))

    # Generate symbols for fA, fB
    symb_moduleA = symbol("$(modfuncA[1])")
    symb_moduleB = symbol("$(modfuncB[1])")

    # Generate symbols for moduleA, moduleB
    fA = symbol("$(modfuncA[2])")
    fB = symbol("$(modfuncB[2])")

    # Generate expressions for Main.moduleA, Main.moduleB
    expr_MainA = Expr(:., symbol("Main"), QuoteNode(symb_moduleA))
    expr_MainB = Expr(:., symbol("Main"), QuoteNode(symb_moduleB))

    # Generate expressions for Main.ModuleA.fA, Main.ModuleB.fB
    expr_fA = Expr(:., expr_MainA, QuoteNode(fA))
    expr_fB = Expr(:., expr_MainB, QuoteNode(fB))

    # Generate arrays of Method objects for Main.ModuleA.fA, Main.ModuleB.fB
    const methods_fA = methods(eval(expr_fA), (Any...))
    const methods_fB = methods(eval(expr_fB), (Any...))

    # Generate arrays of method signatures for Main.ModuleA.fA, Main.ModuleB.fB
    # Note that the 'sig' field of a Method is (as of 3.7) a tuple of types.
    const sigs_fA = [ methods_fA[i].sig for i in 1:length(methods_fA) ]
    const sigs_fB = [ methods_fB[i].sig for i in 1:length(methods_fB) ]

    # Generate array of overlapping signatures of A.f, B.f, i.e. ambiguous cases.
    const conflicts = intersect(sigs_fA, sigs_fB)

    # Adjust either sigs_fA or sigs_fB according to whether caller wishes cases
    # of ambiguous signatures to be handled by A.f or B.f. If 'conflicts_favor'
    # is void or equal to neither A nor B, then no method is assigned for the
    # ambiguous signature.
    if conflicts_favor == eval(expr_MainA)
        sigs_fB = setdiff(sigs_fB, conflicts)
    elseif conflicts_favor == eval(expr_MainB)
        sigs_fA = setdiff(sigs_fA, conflicts)
    else
        sigs_fB = setdiff(sigs_fB, conflicts)
        sigs_fA = setdiff(sigs_fA, conflicts)
    end

    # Loop through elements of sigs_fA and assign appropriate methods of A.f to h
    for (i, sig) in enumerate(sigs_fA)
        # println(sig)
        makemethod(expr_fmerged, expr_fA, sig)
    end

    # Loop through elements of sigs_fB and assign appropriate methods of B.f to h
    for (i, sig) in enumerate(sigs_fB)
        # println(sig)
        makemethod(expr_fmerged, expr_fB, sig)
    end

end # Function merge!(fmerged::Function, modfuncA::(Module, Function), modfuncB::(Module, Function); conflicts_favor=Module)

end # Module MetaMerge

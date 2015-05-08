# Is it this one???

module MetaMerge

importall Main

export merge!

function makemethod(expr_fmerged::Expr, expr_fmodule::Expr, argtypes::Tuple, source::Symbol)

    # Expression calling fmerged
    LHS = Expr(:call, expr_fmerged)

    # Expression calling function denoted by expr_fmodule
    RHS = Expr(:call, expr_fmodule)

    # Add argument symbols with type annotations to signature of call to 'fmerged'
    # Add just argument symbols to call of 'fmodule'
    for (i, arg) in enumerate(argtypes)
        # Include the name of the module from which the method is derived in the name of the first argument
        if i == 1
            push!(LHS.args, Expr(:(::), symbol("x$i\_$source"), arg))
            push!(RHS.args, symbol("x$i\_$source"))
        else
            push!(LHS.args, Expr(:(::), symbol("x$i"), arg))
            push!(RHS.args, symbol("x$i"))
        end
    end

    # Set the calls of 'newf' and 'oldf' equal to one another and evaluates.
    ex_eq = Expr(:(=), LHS, RHS)

    # Generate method
    eval(ex_eq)
end

function fexpress(modufunc::(Module, Function))

    # Generate symbol for modu (hereafter "module" in comments)
    symb_module = symbol("$(modufunc[1])")

    # Generate symbol for func (hereafter "f" in comments)
    symb_f = symbol("$(modufunc[2])")

    # Generate expressions for Main.module
    expr_main = Expr(:., symbol("Main"), QuoteNode(symb_module))

    # Generate expressions for Main.module.f
    expr_f = Expr(:., expr_main, QuoteNode(symb_f))

    return expr_f

end


function getsigs(modufunc::(Module, Function))

    # Generate an array of Method objects respective to Main.module.f
    const fmethods = methods(eval(fexpress(modufunc)), (Any...))

    # Generate arrays of method signatures respective to each method of Main.module.f in fmethods.
    # Note that the 'sig' field of a Method is (as of 3.7) a tuple of types.
    const fsigs = [ fmethods[i].sig for i in 1:length(fmethods) ]

    return fsigs

end

function merge!(fmerged::Function, modufuncs::(Module, Function)...; priority=[])

    # Generate symbol for module calling mergemethods()
    # Hereafter the calling module will be known as 'here'.
    symb_here = symbol("$(current_module())")

    # Generate expression for Main.here.fmerged
    expr_here = Expr(:., symbol("Main"), QuoteNode(symb_here))
    expr_fmerged = Expr(:., expr_here, QuoteNode(symbol("$fmerged")))

    # Create a dictionary of ranks
    ranks = [ priority[i] => i for i in 1:length(priority) ]
    for mfpair in setdiff(modufuncs, priority)
        ranks[mfpair] = length(modufuncs)
    end

    # Create a dictionary of signatures where each key is a (module, function) and the value is the array of signatures the function
    const sigregister = [ (modufuncs[i])=>getsigs(modufuncs[i]) for i in 1:length(modufuncs) ]

    # In the following loop, each "mfpair" variable is a (Module, Function) 2-tuple. We will refer to the Module by "module" and the Function by "f"
    for mfpair in modufuncs

        fsigs = sigregister[(mfpair)]

        for sig in fsigs
            currentrank = ranks[mfpair]
            bestrank = length(modufuncs) + 1

            # Loops through (Module, Function) pairs other than current pair and checks for matching signatures. If there is a match, then 'bestrank' is compared to the rank of the (M,F) pair of the matching signature and replaced is the latter rank is better (i.e. less than 'bestrank').
            for mfpair2 in setdiff(modufuncs, [mfpair])
                matches = find(x -> string(x)=="$sig", sigregister[mfpair2])
                if isempty(matches)
                    nothing
                else
                    for match in matches
                        ranks[mfpair2] < bestrank && (bestrank = ranks[mfpair2])
                    end
                end
            end

            # A method is made for the current signature only if the rank its source (M,F) pair is best. Note that in the case of tied ranks, no method is made. Tied ranks can occur only if both (M,F) pairs have rank length(modufuncs), i.e. only if the user does not explicitly include them in the 'priority' argument.
            currentrank < bestrank && makemethod(expr_fmerged, fexpress(mfpair), sig, symbol("$(mfpair[1])"))

        end

    end

end # Function merge!(fmerged::Function, modfuncA::(Module, Function), modfuncB::(Module, Function); conflicts_favor=Module)

end # Module MetaMerge

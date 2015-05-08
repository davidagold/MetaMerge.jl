
module MetaMerge

importall Main

export fmerge!

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


function fmerge!(fmerged::Function, modufuncs::(Module, Function)...; priority=[])
    # 'modufuncs' is an array of (Module, Function) tuples. Hereafter in the comments we will refer to such tuples individually as (m,f), e.g. "for (m,f) in modufunc"

    # Generate symbol for module calling mergemethods()
    # Hereafter the calling module will be known as 'here'.
    symb_here = symbol("$(current_module())")

    # Generate expression for Main.here.fmerged
    expr_here = Expr(:., symbol("Main"), QuoteNode(symb_here))
    expr_fmerged = Expr(:., expr_here, QuoteNode(symbol("$fmerged")))

    # Create a dictionary of priority ranks, initialize with ranks specified by user in 'priority' keyword argument
    ranks = ((Module,Function)=>Int64)[ priority[i] => i for i in 1:length(priority) ]

    # Add keys for (m, f) pairs not specified in 'priority', assign each such key the value length(modufuncs), i.e. make them all equally ranked last.
    for mfpair in setdiff(modufuncs, priority)
        ranks[mfpair] = length(modufuncs)
    end

    # Create a dictionary of signatures where each key is an (m,f) from 'modufuncs' and the value is the array of signatures the function
    const sigregister = [ (modufuncs[i])=>getsigs(modufuncs[i]) for i in 1:length(modufuncs) ]

    # In the following loop, each 'mfpair' variable is an (m,f) pair
    for mfpair in modufuncs

        fsigs = sigregister[(mfpair)]

        # Each 'sig' is a tuple of datatypes (in Julia 0.3.7)
        for sig in fsigs
            currentrank = ranks[mfpair]
            # Initialize 'bestrank' as impossibly low rank
            bestrank = length(modufuncs) + 1

            # Loops through (m,f) pairs other than current pair and checks for matching signatures. If there is a match, then 'bestrank' is compared to the rank of the (m,f) pair of the matching signature and replaced is the latter rank is better (i.e. less than 'bestrank').
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

            # A method is made for the current signature only if the rank its source (m,f) pair is best. Note that in the case of tied ranks, no method is made. Tied ranks can occur only if both (m,f) pairs have rank length(modufuncs), i.e. only if the user does not explicitly include them in the 'priority' argument.
            currentrank < bestrank && makemethod(expr_fmerged, fexpress(mfpair), sig, symbol("$(mfpair[1])"))

        end # for sig in fsigs

    end # for mfpair in modufuncs

end # Function merge!(fmerged::Function, modufuncs::(Module, Function)...; priority=[])

end # Module MetaMerge

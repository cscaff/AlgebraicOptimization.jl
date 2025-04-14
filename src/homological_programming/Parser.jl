""" CellularSheafParser

TO DO
"""
module CellularSheafParser

using ..CellularSheafTerm: Declaration, restrictionMap, vertexStalk, TypeName, Product, Equation, untypedDeclaration, typedDeclaration, CellularSheafExpr, construct
using MLStyle: @match 

export @cellular_sheaf

""" macro cellular_sheaf(expr...)

Constructs a cellular sheaf using a language of linear relations.
"""
macro cellular_sheaf(expr...)
    local_vars = expr[1:end - 1] # Get local vars passed in as parameters
    block = expr[end] # Get macro code

    # Escape local values and preserve the names
    esc_vals = esc.(local_vars)
    names = QuoteNode.(local_vars)

    return :(parse_cellular_sheaf(($(esc_vals...)), ($(names...)), $(Meta.quot(block))))

end

function parse_cellular_sheaf(local_vals::Tuple{Vararg{Matrix{Int64}}}, local_names::Expr, block::Expr)
    stmts = map(block.args) do line
        @match line begin
            # Filter unneeded line metadata
            ::LineNumberNode => missing

            # Accepts Variable Declarations
            Expr(:tuple, args...) => parse_declaration.(args) # X, Y, Z
            Expr(:(::), _, _) || ::Symbol => parse_declaration(line)

            # Accepts linear relations after declarations
            Expr(:call, :(==), lhs::Expr, rhs::Expr) => Equation(parse_product(lhs), parse_product(rhs)) # A*x == B*y
            _ => error("Line $line is malformed.")
        end
    end |> skipmissing |> collect

    # Define arrays for declarations and equations
    decs = []
    eqns = []

    # Divide statements into declarations and equations
    foreach(stmts) do s
        @match s begin
            ::typedDeclaration || ::untypedDeclaration => push!(decs, s)
            ::Vector{typedDeclaration} || ::Vector{untypedDeclaration} => append!(decs, s)
            ::Equation => push!(eqns, s)
            _ => error("Statement containing $s of type $(typeof(s)) was not added.")
        end
    end

    # Append passed in local arguments to declaration array
    for (name, val) in zip(Tuple(local_names.args), local_vals)
        push!(decs, untypedDeclaration(name, val))
    end

    # Build root of AST
    root = CellularSheafExpr(decs, eqns)
    return construct(root)
end

function parse_declaration(declaration::Any)
    @match declaration begin
        Expr(:(::), a::Symbol, b::Expr) => typedDeclaration(a, TypeName(b.args[1], b.args[2]), nothing) # x::Stalk{4}
        a::Symbol => untypedDeclaration(a, nothing) # x 
        _ => throw("Variable declaration: $declaration format is invalid.")
    end
end

# Create equations with meaningless values (Will be decorated later in semantic phase)
function parse_product(product::Expr)
    @match product begin
        Expr(:call, :(*), lhs::Symbol, rhs::Symbol) => Product(restrictionMap(lhs, Matrix{Any}(undef, 0, 0)), vertexStalk(rhs, 0)) # A*X
        Expr(:call, name::Symbol, arg::Symbol) => Product(restrictionMap(name, Matrix{Any}(undef, 0, 0)), vertexStalk(arg, 0)) # A(x)
        _ => error("Term $product is an invalid product.]\nA product is of form A*x or A(x).")
    end
end

end
""" CellularSheafParser

Parses restriction maps, vertex stalks, and a series of linear relations to more intuitively create cellular sheaves with more discipline.
"""
module CellularSheafParser

using ..CellularSheafTerm: Declaration, restrictionMap, vertexStalk, TypeName, Product, Equation, untypedDeclaration, typedDeclaration, CellularSheafExpr, construct
using MLStyle: @match 

export @cellular_sheaf

""" cellular_sheaf(expr...)

This macro abstracts functions such as:

1. ```julia CellularSheaf(vertex_stalks::Vector{Int}, edge_stalks::Vector{Int}) ``` 
2. ```julia set_edge_maps!(s::AbstractCellularSheaf, v1::Int, v2::Int, e::Int, rm1::AbstractMatrix, rm2::AbstractMatrix)```

It accepts restriction map matrices as argument parameters and allows a user to declare vertex stalks and linear relations
representing edges in the cellular sheaf. For instance, a user can represent a triangular sheaf using the following julia code:

```julia

# Define restriction maps as matrices
A = [1 0 0 0]
B = [1 0 0 0]
C = [1 0 0 0]

# You can pass in the maps as follows: 

triangle = @cellular_sheaf A, B, C begin
    # You can define vertex stalks using the format: name::Stalk{dimension}
    x::Stalk{4}, y::Stalk{4}, z::Stalk{4}

    # Then, you can define your relations as equations:

    # For instance, in "A(x) == B(y)", x and y are incident vertices. A maps x to the shared edge stalk. B maps y to the shared edge stalk.
    A(x) == B(y)
    A(x) == C(z)
    B(y) == C(z)

end
```

The previous code is the same as writing:

```julia

c = CellularSheaf([4, 4, 4], [1, 1, 1])
set_edge_maps!(c, 1, 2, 1, C, C)
set_edge_maps!(c, 1, 3, 2, C, C)
set_edge_maps!(c, 2, 3, 3, C, C)
```

While the first example may appear like more lines of code, it is far easier to understand the pattern that is occuring, making it easier for developers
to quickly construct cellular sheaves. Likewise, because edge stalk dimensions are inferred, this provides a more disciplined approach to building sheaves,
leaving less room for errors.
"""
macro cellular_sheaf(expr...)
    local_vars = expr[1:end - 1] # Get local vars passed in as parameters
    block = expr[end] # Get macro code

    # Escape local values and preserve names
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

# Creates equations with meaningless values (Will be decorated later in semantic phase)
function parse_product(product::Expr)
    @match product begin
        Expr(:call, :(*), lhs::Symbol, rhs::Symbol) => Product(restrictionMap(lhs, Matrix{Any}(undef, 0, 0)), vertexStalk(rhs, 0)) # A*X
        Expr(:call, name::Symbol, arg::Symbol) => Product(restrictionMap(name, Matrix{Any}(undef, 0, 0)), vertexStalk(arg, 0)) # A(x)
        _ => error("Term $product is an invalid product.]\nA product is of form A*x or A(x).")
    end
end

end
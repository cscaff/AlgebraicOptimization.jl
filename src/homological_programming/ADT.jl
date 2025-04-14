""" CellularSheafTerm

This module defines an abstract data type for expressing a cellular sheaf in terms of an abstract syntax tree (AST).
The general structure is as follows. A CellularSheafTerm contains a SheafExpr of which contains a context and a list of equations.
The context holds a list of variable declarations such as restriction maps or vertex stalks:

```julia

A::Map, B::Map, C::Map
x::stalk{4}, y::stalk{4}, z::stalk{4}

```
The equations contain
a system of linear relations:

```julia

Ax = By
By = Cz
Cz = Ax

```

where A, B, C represent restriction maps and x, y, and z represent vertex stalks. Ax = By represents two incident vertices mapping to
a shared edge stalk.

"""
module CellularSheafTerm

using MLStyle: @data, @match
using StructTypes
using ..CellularSheaves

abstract type AbstractTerm end

""" Restriction Map 

This is the child node of Produuct and represents the restriction map "A" in a product "Ax".
"""
mutable struct restrictionMap <: AbstractTerm
    name::Symbol
    matrix::Matrix{Any}
end

""" Vertex Stalk

This is the child node of Product and represents the vertex stalk "x" in a product "Ax".
"""
mutable struct vertexStalk <: AbstractTerm
    name::Symbol
    dim::Int
end

""" Product

A product is a child node of Equation. It contains the prodct between a 
restriction map "A" and vertex stalk "x".

"""
struct Product <: AbstractTerm
    restriction_map::restrictionMap
    vertex_stalk::vertexStalk
end

""" TypeName

A type name is the child node of a declaration. It contains the type annotation for the 
variable being declared. For instance if variable "A" is a restriction map, we might see:
"A::Map" or if "x" is a vertex stalk, we might see the type and dimension: "x::stalk{1}".

"""
struct TypeName <: AbstractTerm
    name::Symbol
    dim::Int
end

""" Equation

An equation is a child node of CellularSheafTerm, the root node. It contains two products:
For instance, "A*x" and "B*y" which represents the restriction map and vertex stalks.
They are related through an equality operator "=".

"""
struct Equation <: AbstractTerm
    lhs::Product
    rhs::Product
end

@doc """ Declaration

A declaration is a child node of a context node. It represents a variable declaration in our language.
A declaration can be typed "A::map" or untyped "A" in the situation we are already passed a restriction
map that is inferred.

"""
Declaration

@data Declaration <: AbstractTerm begin
    untypedDeclaration(name::Symbol, val::Union{Matrix, Nothing})
    typedDeclaration(name::Symbol, type::TypeName, val::Union{Matrix, Nothing})  
end
# The only declaration that carries a value is a restriction map w/ a matrix value.

StructTypes.StructType(::Type{Declaration}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{Declaration}) = :_type
StructTypes.subtypes(::Type{Declaration}) = (untypedDeclaration=untypedDeclaration, typedDeclaration=typedDeclaration)

""" CellularSheafExpr

A cellular sheaf term represents the root node in our AST. It contains two child nodes:
- Context (A list of declarations)
- Equations (A list of equations)

"""
struct CellularSheafExpr <: AbstractTerm
    context::Vector{Declaration}
    equations::Vector{Equation}
end

""" construct(expr::CellularSheafExpr)

 TO DO 
"""
function construct(expr::CellularSheafExpr)
    # Dictionaries for storing constructor parameters
    vertex_dims = Int[] 
    vertex_to_index = Dict{Symbol, Int}() 

    edge_to_index = Dict{Equation, Int}()
    edge_dims = Int[]

    # Generate variable look up table
    look_up_table = generate_look_up_table(expr.context)

    # Decorate equation tree nodes
    decorate_equations(expr.equations, look_up_table, edge_dims, edge_to_index)

    # Gather vertex stalk dimensions for construction
    for declaration in expr.context
        if declaration isa typedDeclaration
            push!(vertex_dims, declaration.type.dim)
            # Store mappiong for construction
            vertex_to_index[declaration.name] = length(vertex_dims)
        end
    end    

   # Construct Cellular Sheaf
   c = CellularSheaf(vertex_dims, edge_dims)

   # Construct edge maps
   for eq in expr.equations
       set_edge_maps!(c, vertex_to_index[eq.lhs.vertex_stalk.name], vertex_to_index[eq.rhs.vertex_stalk.name], edge_to_index[eq], eq.lhs.restriction_map.matrix, eq.rhs.restriction_map.matrix)
   end

   return c
end

function generate_look_up_table(context::Vector{Declaration})
    look_up_table = Dict{Symbol, Declaration}()

    for declaration in context
        # Confirm that the type used is a supported type (Current Supported Types: "Stalk" [Vertex Stalk])
        if declaration isa typedDeclaration && type_name(declaration) != Symbol("Stalk")
            error("Variable \"$(declaration.name)\" type \"$(declaration.type.name)\" is unsupported.\nCurrent types include: \"Stalk\" (Vertex Stalk).")
        end

        # Confirm there are no variable redeclarations
        name =  @match declaration begin
            untypedDeclaration(name, _) => name
            typedDeclaration(name, _, _) => name
        end

        if haskey(look_up_table, name)
            error("Variable: \"$name\" has already been declared.")
        else
            look_up_table[name] = declaration
        end
    end

    return look_up_table
end

function decorate_equations(equations::Vector{Equation}, table::Dict{Symbol, Declaration}, edge_dims::Vector{Int}, edge_mapping::Dict{Equation, Int})
    for eq in equations
        # Extract restriction maps & vertices
        rm_lhs = eq.lhs.restriction_map
        rm_rhs = eq.rhs.restriction_map
        vs_lhs = eq.lhs.vertex_stalk
        vs_rhs = eq.rhs.vertex_stalk

        # Assert that all variables in the equation have been declared
        assert_variable_declaration(rm_lhs.name, table, eq)
        assert_variable_declaration(rm_rhs.name, table, eq)
        assert_variable_declaration(vs_lhs.name, table, eq)
        assert_variable_declaration(vs_rhs.name, table, eq)

        # Decorate Restriction Maps w/ declaration definition
        rm_lhs.matrix = table[rm_lhs.name].val
        rm_rhs.matrix = table[rm_rhs.name].val

        # Decorate Vertex Stalks w/ declaration definition
        vs_lhs.dim = table[vs_lhs.name].type.dim
        vs_rhs.dim = table[vs_rhs.name].type.dim

        # Infer edge stalks, confirm the restriction maps and vertex stalks are consistent, and store their values for construction
        infer_edge(eq, edge_dims, edge_mapping)
    end
end

function infer_edge(eq::Equation, edge_dims::Vector{Int}, edge_mapping::Dict{Equation, Int})
    # Extract restriction maps & vertices
    rm_lhs = eq.lhs.restriction_map
    rm_rhs = eq.rhs.restriction_map
    vs_lhs = eq.lhs.vertex_stalk
    vs_rhs = eq.rhs.vertex_stalk
    
    # Ensure restriction map can be multiplied by vertex stalk
    if (size(rm_lhs.matrix)[2] == vs_lhs.dim) && (size(rm_rhs.matrix)[2] == vs_rhs.dim)
        if size(rm_lhs.matrix)[1] == size(rm_rhs.matrix)[1]
            push!(edge_dims, size(rm_lhs.matrix)[1])
            edge_mapping[eq] = length(edge_dims)
        else
            error(
            """Inferred edge stalk on relation: "$(rm_lhs.name)$(vs_lhs.name) = $(rm_rhs.name)$(vs_rhs.name)" is inconsistent.
                Left restriction map maps dimension $(size(rm_lhs.matrix)[2]) to dimension $(size(rm_lhs.matrix)[1]).
                Right restriction map maps dimension $(size(rm_rhs.matrix)[2]) to dimension $(size(rm_rhs.matrix)[1]).
            """)
        end
    else
        if size(rm_lhs.matrix)[2] != vs_lhs.dim
            error("Left restriction map (Size: $(size(rm_lhs.matrix))) cannot map left vertex stalk (Dimension: $(vs_lhs.dim)).")
        else
            error("Right restriction map (Size: $(size(rm_rhs.matrix))) cannot map right vertex stalk (Dimension: $(vs_rhs.dim)).")
        end
    end
end

function assert_variable_declaration(name::Symbol, table::Dict{Symbol, Declaration}, eq::Equation)
    if !haskey(table, name)
        error("Restriction map \"$name\" in \"", eq.lhs.restriction_map.name, eq.lhs.vertex_stalk.name, " = ", eq.rhs.restriction_map.name, eq.rhs.vertex_stalk.name, "\" is undefined.")
    end
end

function type_name(j::Declaration)
    @match j begin
        typedDeclaration(name, type, _) => type.name
        untypedDeclaration(name, _) => nothing
    end
end

end
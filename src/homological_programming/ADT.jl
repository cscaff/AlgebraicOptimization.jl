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
    # Check variable declarations

    # Generate Variable Look Up Table
    look_up_table = Dict{Symbol, Declaration}()

    for declaration in expr.context
        # 1. Confirm type is a valid typing:
        if declaration isa typedDeclaration
            if declaration.type.name != Symbol("Stalk")
                error("Variable \"$(declaration.name)\" type \"$(declaration.type.name)\" is unsupported.\nCurrent types include: Stalk.")
            end 
        end

        # 2. Confirm variable has not already been declared:
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
    
    # Gathers vertex stalk array from declarations
    vertex_dims = Int[] 
    vertex_to_index = Dict{Symbol, Int}() # Store array locations for later edge mapping
    
    for j in expr.context
        if type_name(j) == Symbol("Stalk")
            push!(vertex_dims, j.type.dim)
            vertex_to_index[j.name] = length(vertex_dims)
        end
    end

    # Check that system of linear relations are well defined:
    # - Two Credentials:
    #   - Variables declared
    #   - Inferred edge stalk is consistent per incident restriction map + vertex stalks 
    # Decorate equations with declared values
    # Infer and gather edge stalk dimensions

    edge_to_index = Dict{Equation, Int}() # Store array locations for later edge mapping
    edge_dims = Int[]

    for eq in expr.equations
        # Extract map & vertices
        rm_lhs = eq.lhs.restriction_map
        rm_rhs = eq.rhs.restriction_map
        vs_lhs = eq.lhs.vertex_stalk
        vs_rhs = eq.rhs.vertex_stalk

        eq_vars = [rm_lhs.name, vs_lhs.name, rm_rhs.name,  vs_rhs.name]

        # Assert declarations for four variables
        for var in eq_vars
            assert_variable_declaration(var, eq_vars[1], eq_vars[2], eq_vars[3], eq_vars[4], look_up_table)
        end

        # Decorate equations with variable definitions

        # Maps
        eq.lhs.restriction_map.matrix = look_up_table[eq.lhs.restriction_map.name].val
        eq.rhs.restriction_map.matrix = look_up_table[eq.rhs.restriction_map.name].val

        # Stalks
        eq.lhs.vertex_stalk.dim = look_up_table[eq.lhs.vertex_stalk.name].type.dim
        eq.rhs.vertex_stalk.dim = look_up_table[eq.rhs.vertex_stalk.name].type.dim

        # Infers edge stalk and asserts consistencies with vertex stalks and restriction maps 

        # Ensure restriction map can be multiplied by vertex stalk
        if (size(rm_lhs.matrix)[2] == vs_lhs.dim) && (size(rm_rhs.matrix)[2] == vs_rhs.dim)
            if size(rm_lhs.matrix)[1] == size(rm_rhs.matrix)[1]
                push!(edge_dims, size(rm_lhs.matrix)[1])
                edge_to_index[eq] = length(edge_dims)
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

   # Construct Cellular Sheaf
   c = CellularSheaf(vertex_dims, edge_dims)

   # Construct edge maps
   for eq in expr.equations
       set_edge_maps!(c, vertex_to_index[eq.lhs.vertex_stalk.name], vertex_to_index[eq.rhs.vertex_stalk.name], edge_to_index[eq], eq.lhs.restriction_map.matrix, eq.rhs.restriction_map.matrix)
       print("DEBUG: V1: $(vertex_to_index[eq.lhs.vertex_stalk.name]), V2: $(vertex_to_index[eq.rhs.vertex_stalk.name]), E1: $(edge_to_index[eq]), RM1: $(eq.lhs.restriction_map.matrix), RM2: $(eq.rhs.restriction_map.matrix)\n")
   end

   return c
end

function assert_variable_declaration(name::Symbol, map_lhs::Symbol, vertex_lhs::Symbol, map_rhs::Symbol, vertex_rhs::Symbol, table::Dict{Symbol, Declaration})
    if !haskey(table, name)
        error("Restriction map \"$name\" in \"", map_lhs, vertex_lhs, " = ", map_rhs, vertex_rhs, "\" is undefined.")
    end
end

function type_name(j::Declaration)
    @match j begin
        typedDeclaration(name, type, _) => type.name
        untypedDeclaration(name, _) => nothing
    end
end


end
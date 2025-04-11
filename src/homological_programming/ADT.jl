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

abstract type AbstractTerm end

""" Restriction Map 

This is the child node of Produuct and represents the restriction map "A" in a product "Ax".
"""
struct restrictionMap <: AbstractTerm
    name::Symbol
    matrix::Matrix{Any}
end

""" Vertex Stalk

This is the child node of Produuct and represents the vertex stalk "x" in a product "Ax".
"""
struct vertexStalk <: AbstractTerm
    name::Symbol
    dim::Symbol
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

A type name is the child node of a judgement. It contains the type annotation for the 
variable being declared. For instance if variable "A" is a restriction map, we might see:
"A::Map" or if "x" is a vertex stalk, we might see the type and dimension: "x::stalk{1}".

"""
struct TypeName <: AbstractTerm
    name::Symbol
    dim::Symbol
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

@doc """ Judgement

A judgement is a child node of a context node. It represents a variable declaration in our language.
A declaration can be typed "A::map" or untyped "A" in the situation we are already passed a restriction
map that is inferred.

"""
Judgement

@data Judgement <: AbstractTerm begin
    untypedVar(name::Symbol)
    typedVar(name::Symbol, type::TypeName)  
end

StructTypes.StructType(::Type{Judgement}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{Judgement}) = :_type
StructTypes.subtypes(::Type{Judgement}) = (untyped_var=untyped_var, typed_var=typed_var)

""" CellularSheafExpr

A cellular sheaf term represents the root node in our AST. It contains two child nodes:
- Context (A list of judgements)
- Equations (A list of equations)

"""
struct CellularSheafExpr <: AbstractTerm
    context::Vector{Judgement}
    equations::Vector{Equation}
end

""" construct(expr::CellularSheafExpr)

 TO DO 
"""
function construct(expr::CellularSheafExpr)
    # Check variable declarations

    # Generate Variable Look Up Table
    look_up_table = Dict{Symbol, Judgement}()

    for judgement in expr.context
        name =  @match judgement begin
            untypedVar(name) => name
            typedVar(name, _) => name
        end

        # Assert no variable redeclarations
        if haskey(look_up_table, name)
            error("Variable: \"$name\" has already been declared.")
        else
            look_up_table[name] = judgement
        end
    end
    
    # Check that system of linear relations are well defined:
    # - Two Credentials:
    #   - Variables declared
    #   - Inferred edge stalk is consistent per incident restriction map + vertex stalks 
    for eq in expr.equations
        # Extract map & vertex names
        eq_vars = [eq.lhs.restriction_map.name, eq.lhs.vertex_stalk.name, eq.rhs.restriction_map.name,  eq.rhs.vertex_stalk.name]

        # Assert declarations for four variables: O(1)
        for var in eq_vars
            assert_variable_definition(var, eq_vars[1], eq_vars[2], eq_vars[3], eq_vars[4], look_up_table)
        end

        # Infers edge stalk and asserts consistencies with vertex stalks and restriction maps 
    end
end

function assert_variable_definition(name::Symbol, map_lhs::Symbol, vertex_lhs::Symbol, map_rhs::Symbol, vertex_rhs::Symbol, table::Dict{Symbol, Judgement})
    if !haskey(table, name)
        error("Restriction map \"$name\" in \"", map_lhs, vertex_lhs, " = ", map_rhs, vertex_rhs, "\" is undefined.")
    end
end


end
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
module CellularSheafAST

using MLStyle: @data
using StructTypes

abstract type AbstractTerm end

""" Restriction Map 

This is the child node of Produuct and represents the restriction map "A" in a product "Ax".
"""
struct restriction_map <: AbstractTerm
    name::Symbol
    matrix::Matrix
end

StructTypes.StructType(::Type{restriction_map}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{restriction_map}) = :_type
StructTypes.subtypes(::Type{restriction_map}) = (restriction_map=restriction_map)

""" Vertex Stalk

This is the child node of Produuct and represents the vertex stalk "x" in a product "Ax".
"""
struct vertex_stalk <: AbstractTerm
    name::Symbol
    dim::Symbol
end

StructTypes.StructType(::Type{vertex_stalk}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{vertex_stalk}) = :_type
StructTypes.subtypes(::Type{vertex_stalk}) = (vertex_stalk=vertex_stalk)

@doc """ Product

A product is a child node of Equation. It contains the prodct between a 
restriction map "A" and vertex stalk "x".

"""
Product

@data Product <: AbstractTerm begin
    Prod(restriction_map::restriction_map, vertex_stalk::vertex_stalk)
end

StructTypes.StructType(::Type{Product}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{Product}) = :_type
StructTypes.subtypes(::Type{Product}) = (Prod=Prod)

@doc """ TypeName

A type name is the child node of a judgement. It contains the type annotation for the 
variable being declared. For instance if variable "A" is a restriction map, we might see:
"A::Map" or if "x" is a vertex stalk, we might see the type and dimension: "x::stalk{1}".

"""
TypeName

@data TypeAnnotation <: AbstractTerm begin
    TypeName(name::Symbol, dim::Symbol)
end

StructTypes.StructType(::Type{TypeName}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{TypeName}) = :_type
StructTypes.subtypes(::Type{TypeName}) = (TypeName=TypeName)

@doc """ Equation

An equation is a child node of CellularSheafTerm, the root node. It contains two products:
For instance, "A*x" and "B*y" which represents the restriction map and vertex stalks.
They are related through an equality operator "=".

"""
Equation

@data Equation <: AbstractTerm begin
    Eq(lhs::Product, rhs::Product)
end

StructTypes.StructType(::Type{Equation}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{Equation}) = :_type
StructTypes.subtypes(::Type{Equation}) = (Equation=Equation)

@doc """ Judgement

A judgement is a child node of a context node. It represents a variable declaration in our language.
A declaration can be typed "A::map" or untyped "A" in the situation we are already passed a restriction
map that is inferred.

"""
Judgement

@data Judgement <: AbstractTerm begin
    untyped_var(name::Symbol)
    typed_var(name::Symbol, type::TypeAnnotation)  
end

StructTypes.StructType(::Type{Judgement}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{Judgement}) = :_type
StructTypes.subtypes(::Type{Judgement}) = (untyped_var=untyped_var, typed_var=typed_var)

@doc """ CellularSheafTerm

A cellular sheaf term represents the root node in our AST. It contains two child nodes:
- Context (A list of judgements)
- Equations (A list of equations)

"""
CellularSheafTerm

@data CellularSheafTerm <: AbstractTerm begin
    SheafExpr(context::Vector{Judgement}, equations::Vector{Equation})
end

StructTypes.StructType(::Type{CellularSheafTerm}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{CellularSheafTerm}) = :_type
StructTypes.subtypes(::Type{CellularSheafTerm}) = (SheafExpr=SheafExpr)

end
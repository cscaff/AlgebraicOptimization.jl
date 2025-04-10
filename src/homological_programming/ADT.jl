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

using MLStyle
using StructTypes

abstract type AbstractTerm end


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
StructTypes.subtypes(::Type{UWDTerm}) = (SheafExpr=SheafExpr)

@doc """ Judgement

A judgement is a child node of a context node. It represents a variable declaration in our language.
A declaration can be typed "A::map" or untyped "A" in the situation we are already passed a restriction
map that is inferred.

"""
Judgement

@data Judgement <: AbstractTerm begin
    untyped_var(name::Symbol)
    typed_var(name::Symbol, type::TypeName)  
end

StructTypes.StructType(::Type{Judgement}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{Judgement}) = :_type
StructTypes.subtypes(::Type{Judgement}) = (untyped_var=untyped_var, typed_var=typed_var)

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

@docs """ Product

A product is a child node of Equation. It contains the prodct between a 
restriction map "A" and vertex stalk "x".

"""
Product

@data Product <: AbstractTerm begin
    restriction_map(name::Symbol, matrix::Matrix)
    vertex_stalks(name::Symbol, dim::Symbol)
end

StructTypes.StructType(::Type{Product}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{Product}) = :_type
StructTypes.subtypes(::Type{Product}) = (restriction_map=restriction_map, vertex_stalks=vertex_stalks)

@docs """ TypeName

A type name is the child node of a judgement. It contains the type annotation for the 
variable being declared. For instance if variable "A" is a restriction map, we might see:
"A::Map" or if "x" is a vertex stalk, we might see the type and dimension: "x::stalk{1}".

"""
TypeName

@data TypeName <: AbstractTerm begin
    TypeName(name::Symbol, dim::Symbol)
end

StructTypes.StructType(::Type{TypeName}) = StructTypes.AbstractType()
StructTypes.subtypekey(::Type{TypeName}) = :_type
StructTypes.subtypes(::Type{TypeName}) = (TypeName=TypeName)

end
module TestADT

using Test
using AlgebraicOptimization.HomologicalProgramming.CellularSheafTerm: 
    Declaration, restrictionMap, vertexStalk, TypeName, Product, Equation, untypedDeclaration, typedDeclaration, CellularSheafExpr, construct
using AlgebraicOptimization

# Let's prove that the current AST properly represents a cellular sheaf

### Judgements:

# Restriction Maps
A = untypedDeclaration(Symbol("A"), [1 0 0 0])
B = untypedDeclaration(Symbol("B"), [1 0 0 0])
C = untypedDeclaration(Symbol("C"), [1 0 0 0])

# Stalks
generic_type = TypeName(Symbol("Stalk"), 4)

x = typedDeclaration(Symbol("x"), generic_type, nothing)
y = typedDeclaration(Symbol("y"), generic_type, nothing)
z = typedDeclaration(Symbol("z"), generic_type, nothing)

### Products

# Restriction Maps 
A_rm = restrictionMap(Symbol("A"), [1 0 0 0])
B_rm = restrictionMap(Symbol("B"), [1 0 0 0])
C_rm = restrictionMap(Symbol("C"), [1 0 0 0])


# Vertex Stalks
x_stalk = vertexStalk(Symbol("x"), 4)
y_stalk = vertexStalk(Symbol("y"), 4)
z_stalk = vertexStalk(Symbol("z"), 4)

Ax = Product(A_rm, x_stalk)
By = Product(B_rm, y_stalk)
Cz = Product(C_rm, z_stalk)

### Equations

EQ1 = Equation(Ax, By)
EQ2 = Equation(By, Cz)
EQ3 = Equation(Cz, Ax)

### CellularSheafExpr

triangularSheaf = CellularSheafExpr([A, B, C, x, y, z], [EQ1 ,EQ2, EQ3])

# Testing no duplicate variables!
triangularSheafDuplicate = CellularSheafExpr([A, A, B, C, x, y, z], [EQ1 ,EQ2, EQ3])
@test_throws ErrorException("Variable: \"A\" has already been declared.") construct(triangularSheafDuplicate)

# Testing undeclared variable in equation
R_rm = restrictionMap(Symbol("R"), [1 0 0 0])
x_stalk = vertexStalk(Symbol("x"), 4)

Rx = Product(R_rm, x_stalk)
EQ_undefined = Equation(Rx, By)

triangularSheafUndeclared = CellularSheafExpr([A, B, C, x, y, z], [EQ_undefined ,EQ2, EQ3])
@test_throws ErrorException("Restriction map \"R\" in \"Rx = By\" is undefined.") construct(triangularSheafUndeclared)

# Test inconsistent edge stalk inferred from bad restriction maps
B_rm = restrictionMap(Symbol("B"), [1 0 0 0; 0 0 0 1])
y_stalk = vertexStalk(Symbol("y"), 4)

By = Product(B_rm, y_stalk)
EQ_inconsistent = Equation(Ax, By)

triangularSheafInconsistent = CellularSheafExpr([A, B, C, x, y, z], [EQ_inconsistent ,EQ2, EQ3])
@test_throws ErrorException(
    """Inferred edge stalk on relation: "Ax = By" is inconsistent.
        Left restriction map maps dimension 4 to dimension 1.
        Right restriction map maps dimension 4 to dimension 2.
    """) construct(triangularSheafInconsistent)

# Incorrect vertex stalk dimension or restriction map size
B_rm = restrictionMap(Symbol("B"), [1 0 0]) # Size 1 x 3
y_stalk = vertexStalk(Symbol("y"), 4) # Dimension 4 

By = Product(B_rm, y_stalk)
EQ_bad_map = Equation(Ax, By)

triangularSheafWrongMapping = CellularSheafExpr([A, B, C, x, y, z], [EQ_bad_map ,EQ2, EQ3])
@test_throws ErrorException("Right restriction map (Size: (1, 3)) cannot map right vertex stalk (Dimension: 4).") construct(triangularSheafWrongMapping)

# DEBUG
construct(triangularSheaf)


# Macro Tests

A = [1 0 0 0]
B = [1 0 0 0]
C= [1 0 0 0]

@cellular_sheaf A, B, C begin
    x::Stalk{4}, y::Stalk{4}

    A*x == B*y

end

end
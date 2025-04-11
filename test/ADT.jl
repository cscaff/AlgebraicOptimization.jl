module TestADT

using Test
using AlgebraicOptimization.HomologicalProgramming.CellularSheafTerm: 
    restrictionMap, vertexStalk, TypeName, Product, Equation, untypedVar, typedVar, CellularSheafExpr

# Let's prove that the current AST properly represents a cellular sheaf

### Judgements:

# Restriction Maps
A = untypedVar(Symbol("A"))
B = untypedVar(Symbol("B"))
C = untypedVar(Symbol("C"))

# Stalks
generic_type = TypeName(Symbol("Stalk"), Symbol("4"))

x = typedVar(Symbol("x"), generic_type)
y = typedVar(Symbol("y"), generic_type)
z = typedVar(Symbol("z"), generic_type)

### Products

# Restriction Maps 
A_rm = restrictionMap(Symbol("A"), [1 0 0 0])
B_rm = restrictionMap(Symbol("B"), [1 0 0 0])
C_rm = restrictionMap(Symbol("C"), [1 0 0 0])

# Vertex Stalks
x_stalk = vertexStalk(Symbol("x"), Symbol("4"))
y_stalk = vertexStalk(Symbol("y"), Symbol("4"))
z_stalk = vertexStalk(Symbol("z"), Symbol("4"))

Ax = Product(A_rm, x_stalk)
By = Product(B_rm, y_stalk)
Cz = Product(C_rm, z_stalk)

### Equations

EQ1 = Equation(Ax, By)
EQ2 = Equation(By, Cz)
EQ3 = Equation(Cz, Ax)

### CellularSheafExpr

triangularSheaf = CellularSheafExpr([A, B, C, x, y, z],[EQ1 ,EQ2, EQ3])

end
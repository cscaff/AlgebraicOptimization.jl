module TestADT

using Test
using AlgebraicOptimization.HomologicalProgramming.CellularSheafAST: 
    restriction_map, vertex_stalks, TypeName, Prod, Eq, untyped_var, typed_var, SheafExpr

# Let's prove that the current AST properly represents a cellular sheaf

### Judgements:

# Restriction Maps
A = untyped_var(Symbol("A"))
B = untyped_var(Symbol("B"))
C = untyped_var(Symbol("C"))

# Stalks
generic_type = TypeName(Symbol("Stalk"), Symbol("4"))

x = typed_var(Symbol("x"), generic_type)
y = typed_var(Symbol("y"), generic_type)
z = typed_var(Symbol("z"), generic_type)

### Products

# Restriction Maps 
A_rm = restriction_map(Symbol("A"), [1 0 0 0])
B_rm = restriction_map(Symbol("B"), [1 0 0 0])
C_rm = restriction_map(Symbol("C"), [1 0 0 0])

# Vertex Stalks
x_stalk = vertex_stalks(Symbol("x"), Symbol("4"))
y_stalk = vertex_stalks(Symbol("y"), Symbol("4"))
z_stalk = vertex_stalks(Symbol("z"), Symbol("4"))







end
using Test
using AlgebraicOptimization

# Equality Checking Helper Function
function isEqual(sheafOne::CellularSheaf, sheafTwo::CellularSheaf)
    @test sheafOne.vertex_stalks == sheafTwo.vertex_stalks
    @test sheafOne.edge_stalks == sheafTwo.edge_stalks
    @test sheafOne.coboundary == sheafTwo.coboundary
end

# Triangle Sheaf 
A = [1 0 0 0]
B = [1 0 0 0]
C = [1 0 0 0]

# Macro
test = @cellular_sheaf A, B, C begin
    x::Stalk{4}, y::Stalk{4}, z::Stalk{4}

    A(x) == B(y)
    A(x) == C(z)
    B(y) == C(z)

end

# Functions
c = CellularSheaf([4, 4, 4], [1, 1, 1])
set_edge_maps!(c, 1, 2, 1, A, B)
set_edge_maps!(c, 1, 3, 2, A, C)
set_edge_maps!(c, 2, 3, 3, B, C)

# Test
isEqual(test, c)
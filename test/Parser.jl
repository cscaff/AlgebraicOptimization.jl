using Test
using AlgebraicOptimization

# Equality Checking Helper Function
function isEqual(sheafOne::CellularSheaf, sheafTwo::CellularSheaf)
    @test sheafOne.vertex_stalks == sheafTwo.vertex_stalks
    @test sheafOne.edge_stalks == sheafTwo.edge_stalks
    @test sheafOne.coboundary == sheafTwo.coboundary
end

# Triangle Sheaf for Consensus
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

# Formation Sheaf
A = [1 0 0 0; 0 0 1 0]
B = [1 0 0 0; 0 0 1 0]

test = @cellular_sheaf A, B begin
    x::Stalk{4}, y::Stalk{4}, z::Stalk{4}

    A(x) == B(y)
    A(x) == B(z)

end

c = CellularSheaf([4, 4, 4], [2, 2])
set_edge_maps!(c, 1, 2, 1, A, B)
set_edge_maps!(c, 1, 3, 2, A, B)

# Test
isEqual(test, c)

# Testing for malformed line
A = [1 0 0 0]
B = [1 0 0 0]
C = [1 0 0 0]

@test_throws ErrorException("Line A(x) == A(x) == C(z) is malformed.") @cellular_sheaf A, B, C begin
    x::Stalk{4}, y::Stalk{4}, z::Stalk{4}

    A(x) ==
    A(x) == C(z)
    B(y) == C(z)

    end

# Testing invalid product
A = [1 0 0 0]
B = [1 0 0 0]
C = [1 0 0 0]

@test_throws ErrorException("Term B / y is an invalid product.\nA product is of form A*x or A(x).") @cellular_sheaf A, B, C begin
    x::Stalk{4}, y::Stalk{4}, z::Stalk{4}

    A(x) == B/y
    A(x) == C(z)
    B(y) == C(z)

    end

    # Testing invalid declaration
A = [1 0 0 0]
B = [1 0 0 0]
C = [1 0 0 0]

@test_throws ErrorException("Variable declaration: A(x) == B(y) format is invalid.") @cellular_sheaf A, B, C begin
    x::Stalk{4}, y::Stalk{4},

    A(x) == B(y)
    A(x) == C(z)
    B(y) == C(z)

    end
# Throwing correct exception but test errors? "BoundsError: attempt to access 53-codeunit String at index [1]"
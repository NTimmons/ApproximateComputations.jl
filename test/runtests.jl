using Test
using ApproximateComputations

@testset "Approximation Type" begin
## Approximation Tests
 a = Approximation(6.0)
 b = 4.0
 
 @test typeof(a - b) == Approximation{typeof(b)}
 @test typeof(a + b) == Approximation{typeof(b)}
 @test typeof(a * b) == Approximation{typeof(b)}
 @test typeof(a / b) == Approximation{typeof(b)}
 
 @test typeof(Get(a)) == Float64

end
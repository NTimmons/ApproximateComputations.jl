using Test
using ApproximateComputations

using ImportAll
@importall Base

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

@testset "AST Approximation" begin
	little(x)  = (x * 2) + 5
	
	@test UpdateEnvironmentForFunction(little) == nothing
	
	littletree = little(Variable(123))
	
	@test EmulateTree(littletree) == 251
	
	ReplaceSubTree(littletree, Variable(0), 1)
	
	@test EmulateTree(littletree) == 5
end

@testset "Loop Perforation" begin
	expr = quote
				function newfunc()
					aa = 0
					for i in 1:10
						aa = aa + 1
					end
					aa
				end
			end
	
	LoopAllExpr(expr, UnitRange, ClipFrontAndBackRange)
	eval(expr)
	@test newfunc() == 8

end
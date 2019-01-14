# AST Manipulation for Approximate Computation

# Our main types and wrappers:
# ############################

global g_ID = 0
function GetGlobalID()
   global g_ID
    g_ID = g_ID + 1
    g_ID
end

function ResetGlobalID()
   global g_ID
    println("WARNING: Global ID has been reset")
    g_ID = 0
end

abstract type TreeMember end

mutable struct Variable <: TreeMember
    var
    id
    Variable(x) = new(x, GetGlobalID())
end

mutable struct Operator <: TreeMember
    op
    leaves
    id
	result
	precomputed::Bool
    Operator(x::Variable) = new(identity, [x]      , GetGlobalID(), "NotComputedYet", false)
    Operator(fun, x)      = new(fun     , [x]      , GetGlobalID(), "NotComputedYet", false)
    Operator(fun, x,y)    = new(fun     , [x, y]   , GetGlobalID(), "NotComputedYet", false)
    Operator(fun, x,y,z)  = new(fun     , [x, y, z], GetGlobalID(), "NotComputedYet", false)
end

# Debug function to view the tree.

function printtree(node::TreeMember, level = 0)
    outstr = "|"
    if(level > 0)
        for i in 1:level
            outstr = string(outstr,"  |")
        end
    end
    
    if(typeof(node) == Operator)
        println(string(outstr, "Function(", node.op, ") - (id:$(node.id)) - Result:", node.result))
        for leaf in node.leaves        
            if(leaf != nothing)
                if(typeof(leaf) <: TreeMember)
                    printtree(leaf, level+1)
                else
                    varindent ="|"
                    for i in 1:level+1
                        varindent = string(varindent,"  |")
                    end
                    print(string(varindent, "Const ", typeof(leaf), "(", leaf, ")", "\n"))
                end
            end
        end
    else
        println(string(outstr, typeof(node.var), "(", node.var, ") - (id:$(node.id))"))
    end
	
	if(level == 0)
		println("\n")
	end
end



# Extending the environment to allow for operators to work on wrapped types:
# ##########################################################################
# These functions allow us to automatically generate the functions we need for
# the functions we are trying to evaluate.

function GetOverrideFunctionList(func)
    display(func)
    ast = Base.uncompressed_ast(first(methods(func)))
    callsymbols = []
    for line in ast.code
        if(line.head == Symbol(:call))
            argTypes = []
            for arg in line.args[2:end]
                push!(argTypes, Float64)
            end
            
            argumentcount = length(line.args[2:end])
            argTypes[1] = TreeMember
            typeTuple = tuple(argTypes ...)
                       
            # This optimisation check excluded a number of base operators due to the fold definition: operators.jl:502
            #    for op in (:+, :*, :&, :|, :xor, :min, :max, :kron)
            #    @eval begin
            #        ($op)(a, b, c, xs...) = afoldl($op, ($op)(($op)(a,b),c), xs...)
            #    end
            #end
            #if( length(methods(eval(line.args[1].name), typeTuple)) == 0)
                push!(callsymbols, (line.args[1].name, argumentcount))   
                #println("Submitted $(line.args[1].name)")
            #end
        end
    end
    
    callsymbols
end

+(x::TreeMember, y::TreeMember) = Operator(+, x,y)
+(x::TreeMember, y) 			= Operator(+, x,y)
+(x, y::TreeMember) 			= Operator(+, x,y)

-(x::TreeMember, y::TreeMember) = Operator(-, x,y)
-(x::TreeMember, y) 			= Operator(-, x,y)
-(x, y::TreeMember) 			= Operator(-, x,y)
-(x::TreeMember) 				= Operator(-, x)

*(x::TreeMember, y::TreeMember) = Operator(*, x,y)
*(x::TreeMember, y) 			= Operator(*, x,y)
*(x, y::TreeMember) 			= Operator(*, x,y)

/(x::TreeMember, y::TreeMember) = Operator(/, x,y)
/(x::TreeMember, y) 			= Operator(/, x,y)
/(x, y::TreeMember) 			= Operator(/, x,y)

function BuildOverrideFromArray(ovr)
    for op = ovr
        display(eval(quote
            if($(op[2] == 1))
                    $(op[1])(x::TreeMember)       = Operator(($(op[1])), x)
            elseif($(op[2] == 2))
                    $(op[1])(x::TreeMember, y)    = Operator(($(op[1])), x,y)
                    $(op[1])(x, y::TreeMember)    = Operator(($(op[1])), x,y)
                    $(op[1])(x::TreeMember, y::TreeMember)    = Operator(($(op[1])), x,y)
            elseif($(op[2] == 3))
                    $(op[1])(x::TreeMember, y, z) = Operator(($(op[1])), x,y,z)
                    $(op[1])(x, y::TreeMember, z) = Operator(($(op[1])), x,y,z)
                    $(op[1])(x, y, z::TreeMember) = Operator(($(op[1])), x,y,z)
                    $(op[1])(x::TreeMember, y::TreeMember, z::TreeMember) = Operator(($(op[1])), x,y,z)
                    $(op[1])(x, y::TreeMember, z::TreeMember) = Operator(($(op[1])), x,y,z)
                    $(op[1])(x::TreeMember, y, z::TreeMember) = Operator(($(op[1])), x,y,z)
                    $(op[1])(x::TreeMember, y::TreeMember, z) = Operator(($(op[1])), x,y,z)                  
            end
        end))
    end
	
	for op in ovr
		println("$(op[1]) - declared with $(op[2]) inputs")
	end
end

function GetOverrides(func)
    overridefunctions = GetOverrideFunctionList(func)
    override = tuple(overridefunctions...)
end

function UpdateEnvironmentForFunction(func)
    overridefunctions = GetOverrideFunctionList(func)
    override = tuple(overridefunctions...)
    BuildOverrideFromArray(override)
end

function GetConstructionFunction()
    (quote
        function BuildOverrideFromArray_Gen(ovr)
            for op = ovr
                display(eval(quote
                    if($(op[2] == 1))
                            $(op[1])(x::TreeMember)       = Operator(($(op[1])), x)
                    elseif($(op[2] == 2))
                            $(op[1])(x::TreeMember, y)    = Operator(($(op[1])), x,y)
                            $(op[1])(x, y::TreeMember)    = Operator(($(op[1])), x,y)
                            $(op[1])(x::TreeMember, y::TreeMember)    = Operator(($(op[1])), x,y)
                    elseif($(op[2] == 3))
                            $(op[1])(x::TreeMember, y, z) = Operator(($(op[1])), x,y,z)
                            $(op[1])(x, y::TreeMember, z) = Operator(($(op[1])), x,y,z)
                            $(op[1])(x, y, z::TreeMember) = Operator(($(op[1])), x,y,z)
                            $(op[1])(x::TreeMember, y::TreeMember, z::TreeMember) = Operator(($(op[1])), x,y,z)
                            $(op[1])(x, y::TreeMember, z::TreeMember) = Operator(($(op[1])), x,y,z)
                            $(op[1])(x::TreeMember, y, z::TreeMember) = Operator(($(op[1])), x,y,z)
                            $(op[1])(x::TreeMember, y::TreeMember, z) = Operator(($(op[1])), x,y,z)                  
                    end
                end))
            end

            for op in ovr
                println("$(op[1]) - declared with $(op[2]) inputs")
            end
        end
    end)
end

macro BuildOverrideFromArray()
	:(eval(GetConstructionFunction()))
end


# Tree Manipulation Functions

function GetAllTrees(node)
    treelist = []
    if(typeof(node) == Operator)  
        push!(treelist, node)   
        for leaf in node.leaves        
            if(leaf != nothing)                
                if(typeof(leaf) <: TreeMember)
                    childarray = copy(GetAllTrees(leaf))
                    treelist = vcat(treelist, childarray)
                else
                    push!(treelist, Variable(copy(leaf)))
                end
                
            end
        end
    else
        treelist = vcat(treelist, node)
    end    
    treelist
end

HasId(x::TreeMember, target ) = x.id == target
HasId(x, target ) = false

function ReplaceSubTree(node, replnode, targetID)   
    if(typeof(node) == Operator)  
        for i in 1:length(node.leaves)        
            if(node.leaves[i] != nothing)                
                if HasId(node.leaves[i], targetID)
                    if(typeof(node.leaves[i]) != typeof(replnode) )
                        node.leaves[i] = typeof(node.leaves[i])(replnode)
                    else
                        node.leaves[i] = replnode
                    end
                else
                    ReplaceSubTree(node.leaves[i], replnode, targetID)
                end                
            end
        end
    end    
end

function WrapTree(node::TreeMember)
   Operator(identity, node) 
end

function UnwrapTree(node::TreeMember)
    if(node.op == identity)
       return node.leaves[1]
    end
end

function FullUnwrap(node::TreeMember)   
    current = node
    while(typeof(current) == Operator && current.op == identity)
       current = current.leaves[1]
    end
    return current
end

# Function to execute an AST

SymbolDict = Dict()
function SetSymbolValue(name, value)
	SymbolDict[name] = value
end

ClearSymbolDict() = SymbolDict = Dict()

function EmulateTree(node, localSymbolDict = Dict())   
    result = 0    

    if(typeof(node) == Operator)
        operation = node.op
		emulatedInputs = []
		for leaf in node.leaves
			push!(emulatedInputs, EmulateTree(leaf, localSymbolDict) )
		end
        #emulatedInputs = EmulateTree.(node.leaves, localSymbolDict)
        result = operation(emulatedInputs...)   
		node.result = result		
    elseif (typeof(node) == Variable)
        result = node.var
    else
        result = node
    end    
    
    if(typeof(result) == Symbol)
		if(haskey(localSymbolDict, result) )
			result = localSymbolDict[result]
		elseif(haskey(SymbolDict, result))
			result = SymbolDict[result]
		else
			@show localSymbolDict
			@show SymbolDict
			println("ERROR: Undefined symbol: $(result)")
			println("ERROR: Proceeding with nil value...")
			result = 0
		end
    end
    
    result
end


function InArray(arr, x)
	for v in arr
		if(v == x)
			return true
		end
	end
	
	return false
end

function GetAllLeaves(nodes)
    variables = []
    for v in nodes
        if(typeof(v) != Operator)
			if( !InArray(variables, v) )
				push!(variables, v)
			end
        end
    end
    variables
end

function GetAllSymbols(node)
    GetAllSymbolsList(GetAllLeaves(node))
end

function GetAllSymbolsList(leafArray)
    variables = []
    for v in leafArray
        if(typeof(v) == Variable)
            if(typeof(v.var) == Symbol)
                push!(variables, v.var)
            end
        elseif typeof(v) == Symbol
            push!(variables, v)
        end 
    end
    variables
end



##################
## Tree Editing Functions
##
######
function ReplaceAllVariablesOfType(node::TreeMember, targettype, replacementtype) 
    if(typeof(node) == Operator)
        for i in 1:length(node.leaves)
            if(node.leaves[i] != nothing)
                if(typeof(node.leaves[i]) == Operator)
                    ReplaceAllVariablesOfType(node.leaves[i], targettype, replacementtype)
                elseif (typeof(node.leaves[i]) == Variable)
                    if(typeof(node.leaves[i].var)==targettype)
                       node.leaves[i].var =  replacementtype(node.leaves[i].var)
                    end
                end
            end
        end
    end    
end

function ReplaceTypeOfSpecifiedVariable(node::TreeMember, id, replacementtype)
    if(typeof(node) == Operator)
        for i in 1:length(node.leaves)
            if(node.leaves[i] != nothing)
                if(typeof(node.leaves[i]) == Operator)
                    ReplaceTypeOfSpecifiedVariable(node.leaves[i], id, replacementtype)
                elseif (typeof(node.leaves[i]) == Variable)
                    if( node.leaves[i].id== id)
                        @show "Replacing!"
                       node.leaves[i].var =  replacementtype(node.leaves[i].var)
                    end
                end
            end
        end
    end    
end

function ReplaceConstantsWithVariables(node::TreeMember) 
    if(typeof(node) == Operator)
        for i in 1:length(node.leaves)
            if(node.leaves[i] != nothing)
                if(typeof(node.leaves[i]) <: TreeMember)
                    ReplaceConstantsWithVariables(node.leaves[i])
                else
                    node.leaves[i] = Variable(node.leaves[i])
                end
            end
        end
    end    
end






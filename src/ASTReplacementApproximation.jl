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
    Operator(x::Variable) = new(identity, [x]      , GetGlobalID())
    Operator(fun, x)      = new(fun     , [x]      , GetGlobalID())
    Operator(fun, x,y)    = new(fun     , [x, y]   , GetGlobalID())
    Operator(fun, x,y,z)  = new(fun     , [x, y, z], GetGlobalID())
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
        println(string(outstr, node.op, "(id:$(node.id))"))
        for leaf in node.leaves        
            if(leaf != nothing)
                if(typeof(leaf) <: TreeMember)
                    printtree(leaf, level+1)
                else
                    varindent ="|"
                    for i in 1:level+1
                        varindent = string(varindent,"  |")
                    end
                    printtree(string(varindent, leaf, "\n"))
                end
            end
        end
    else
        println(string(outstr, node.var, "(id:$(node.id))"))
    end
end



# Extending the environment to allow for operators to work on wrapped types:
# ##########################################################################
# These functions allow us to automatically generate the functions we need for
# the functions we are trying to evaluate.

function GetOverrideFunctionList(func)
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

function BuildOverrideFromArray(ovr)
    for op = ovr
        eval(quote
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
        end)
    end
end

function UpdateEnvironmentForFunction(func)
    overridefunctions = GetOverrideFunctionList(func)
    override = tuple(overridefunctions...)
    BuildOverrideFromArray(override)
end

# Tree Manipulation Functions

function GetAllTrees(node)
    treelist = []
    if(typeof(node) == Operator)  
        push!(treelist, node)   
        for leaf in node.leaves        
            if(leaf != nothing)                
                if(typeof(leaf) <: TreeMember)
                    childarray = GetAllTrees(leaf)
                    treelist = vcat(treelist, childarray)
                else
                    push!(treelist, Variable(leaf))
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

function EmulateTree(node)   
    result = 0     
    if(typeof(node) == Operator)
        operation = node.op
        emulatedInputs = EmulateTree.(node.leaves)
        result = operation(emulatedInputs...)     
    elseif (typeof(node) == Variable)
        result = node.var
    else
        result = node
    end    
    
    if(typeof(result) == Symbol)
        println("Result is a symbol... $(result)")
        result = @eval ($result)
        println(typeof(result))
        println("Result is a $(typeof(result))... $(result)")
    end
    
    result
end
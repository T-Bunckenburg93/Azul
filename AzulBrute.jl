using Combinatorics
using Multisets
using Random
using Multisets
using MetaGraphsNext
using Graphs


# First up, lets define the constants of Azul.
include("constants.jl")
include("game.jl")
include("processGame.jl")


# ok, so for a game, I want to map out all the possible moves that can be made.

game = initGame(players = 2)
moveList = PlayerMove[]

while !(playerMoves(game,game.playerTurn) == [])

    m = playerMoves(game,game.playerTurn)
    # randomly pick a move:
    move = shuffle(m)[end]
    push!(moveList,move)
    runMove!(game,move)
    if playerMoves(game,game.playerTurn) == []
        println("round Over")
        break
    end
# 
end


typeof(hash(game))
moveList

AzulGraph = MetaGraph(DiGraph(); label_type=UInt64, vertex_data_type=Game);    

# add the first node
game = initGame(players = 2)
add_vertex!(AzulGraph,hash(game),game)


node = AzulGraph[hash(game)]

function addChildren!(Agraph, node)
    if !(length(getActions(node,node.playerTurn)) == 0)
        for move in playerMoves(node,node.playerTurn)
            game = deepcopy(node)
            runMove!(game,move)
            add_vertex!(Agraph,hash(game),game)
            add_edge!(Agraph,hash(node),hash(game))
        end
    end

end

addChildren!(AzulGraph,node)

AzulGraph

getActions(node,node.playerTurn)

nv(AzulGraph)







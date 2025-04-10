using Flux


"""
Order invariant one hot encoding
allows duplicate values on each row, but only one value per row..

# if we have (:blue, :yellow), or (:yellow, :blue) we want the same encoding.
# instead of [1,0,0,1,] or [0,1,1,0] we get [1,1,0,0]
"""
function OIOneHotBatch(data::Multiset,labels::Vector{Symbol})

    szData = length(data)
    szLabel = length(labels)
    m = zeros(Bool,szLabel,szData)

    for i in 1:szLabel
        val = labels[i]
        ln = data[val]
        if ln > 0
            # println(val,ln)
            m[i,1:ln] .= 1
        end
    end
    return m
end
function OIOneHotBatch(data::Vector{Symbol},labels::Vector{Symbol})

    szData = length(data)
    szLabel = length(labels)
    m = zeros(Bool,szLabel,szData)

    for i in 1:szLabel
        val = labels[i]
        ln = length(filter(x -> x == val,data))
        if ln > 0
            # println(val,ln)
            m[i,1:ln] .= 1
        end
    end
    return m
end



game = initGame()
OIOneHotBatch(game.islands[1],tile_colours)
game.boards[1].triangle.rows[4].tiles[1:3] .= :blue
game.boards[1].triangle.rows[4].tiles
OIOneHotBatch(game.boards[1].triangle.rows[4].tiles,tile_colours)
game.boards[1].triangle.rows[4].tiles

game.pool = game.pool + Multiset([:blue,:blue,:blue,:blue,:blue,:blue,:blue])
length(game.pool)

function processTriangleRow(tr::TriangleRow)

    m = OIOneHotBatch(tr.tiles,tile_colours)
    m2 = reshape(m,tr.sz*5)
    return m2
end
processTriangleRow(game.boards[1].triangle.rows[4])


function processDiscard(discard::Vector{Symbol})

    sz = length(discard)

    m = zeros(Bool,43)

    if sz >= 1
        m[1:6] = reshape(OIOneHotBatch(discard[1:1],vcat(tile_colours,:start_token)),6)
    end
    if sz > 1
        m[7:6+(sz-1)*5] = reshape(OIOneHotBatch(discard[2:end],tile_colours),(sz-1)*5)
    end

    return m
end
game.boards[1].discard = [:blue,:yellow,:red,:black,:white]
processDiscard(game.boards[1].discard)


function processIsland(i::Multiset{Symbol})

    m = OIOneHotBatch(i,tile_colours)
    mSz = length(m)
    m2 = vcat(reshape(m,mSz),zeros(Bool,20 - mSz)) # this is only in the rare case that there are less than 4 tiles on the island

    return m2
end


g = initGame(players = 2)
g.islands[1] = Multiset([:blue,:yellow,])
processIsland(g.islands[1])

g.pool

function processPool(pool::Multiset{Symbol})

    # max pool length is 15 + start_token  for 2px
    # 15*5 + 1 = 76
    v = zeros(Bool,76)
    sz = length(filter(x->x != :start_token,collect(pool)))

    v[1:sz*5] = reshape(OIOneHotBatch(filter(x->x != :start_token,collect(pool)),tile_colours),sz*5)

    if pool[:start_token] == 1

        v[end] = 1

    end
    return v
end

g = initGame()
g.pool =  Multiset([:start_token,:blue,:red,:blue,:red,:blue,:blue,:blue])
processPool(g.pool)

# game.boards[1].triangle.rows[1]
# TriangleRow(game.boards[1].triangle.rows[1])

function processBoard(board::Board)

    score = board.score
    wall = reshape(board.mosaic.grid,25)
    # get the rows
    rows = vcat(
        # Maybe look at turning this into a full 1hot encoding
        # ie 5th row 5*5 = 25
        processTriangleRow(board.triangle.rows[1]),
        processTriangleRow(board.triangle.rows[2]),
        processTriangleRow(board.triangle.rows[3]),
        processTriangleRow(board.triangle.rows[4]),
        processTriangleRow(board.triangle.rows[5])
    )
    discard = processDiscard(board.discard) # if 1hot then this needs to be 27*5

    return vcat(score,wall,rows,discard)

end

g = initGame()
processBoard(g.boards[1])

"""
This turns the gamestate into a vector.
"""
function processGame2px(game::Game;p = -1)

    if p == -1
        p = game.playerTurn
    end
    
    if game.playerTurn == 1
        p1 = processBoard(game.boards[1])
        p2 = processBoard(game.boards[2])
    else
        p2 = processBoard(game.boards[1])
        p1 = processBoard(game.boards[2])
    end

    # get the pool
    pool = processPool(game.pool)

    islands = zeros(Int,20*5)
    # and process the islands
    island_sz = length(game.islands)
    for i in 1:island_sz
        islands[20*i - 19:20*i] = processIsland(game.islands[i])
    end


    return vcat(p1,p2,pool,islands)

end

g = initGame()
processGame2px(g)



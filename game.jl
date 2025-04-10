using Random
using Multisets
# using ReinforcementLearning
# lets simplify this shit. tiles are just symbols and bags are just multisets of symbols.
# ie 
# bag = Multiset([tile_colours;tile_colours])

# This contains the structs and the struct initalisations. 


"""
Bag is a collection of tiles. This is used to represent the bag of tiles that players draw from, 
but is also used to represent the pool of tiles in the middle of the board, the islands, and the player's discard.

A full Azul board can be initalised with `CreateBag()`. This will return a bag with 100 tiles, 20 of each colour.

An empty bag can be initalised with `CreateBag(empty = true)`. This will return an empty bag.

```julia
B = CreateBag()
B2 = CreateBag(empty = true)

length(B) # 100
length(B2) # 0

```
"""
function CreateBag(;empty = false)

    if empty
        b = Multiset(Symbol[])
        return b
    end
    if !empty
        b = Multiset([
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;                
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;
            tile_colours;    
                ])

        return b
    end
end

CreateBag(empty = false)

"""
This removes a random tile from the bag and returns it.

```julia
B = Multiset([tile_colours;tile_colours])
t = drawTile!(B)
# t is a MosaicTile from the bag
```

"""
function drawTile!(bag::Multiset)


    b = shuffle(collect(bag))
    @assert length(b) > 0 "ERROR: Trying to draw from and empty bag"
    b_pop = pop!(b)
    push!(bag,b_pop,-1)
    return b_pop

end

"""
This adds a tile to the bag

```julia
B = Multiset([tile_colours;tile_colours])
addTile!(B, :blue)
```
"""
function addTile!(bag::Multiset, tile::Symbol)

    push!(bag,tile,1)
    return nothing

end

"""
This moves all the tiles to the first bag.

```julia
B1 = CreateBag(empty = true)    
B2 = CreateBag(empty = true)

addTile!(B1, :blue)
addTile!(B1, :red)

bagToBag!(B1, B2) # moves tiles from B2 to B1

length(B1) # 0
length(B2) # 2
"""
function bagToBag!(discard::Multiset, bag::Multiset)

    discard = discard ∪ bag
    bag = Multiset(Symbol[])
    return nothing

end
B1 = CreateBag(empty = true)    
B2 = CreateBag(empty = true)

addTile!(B1, :blue)
addTile!(B1, :red)

bagToBag!(B1, B2) # moves tiles from B2 to B1

length(B1) # 2
length(B2) # 0


# We don't need a custiom struct for islands, the islands are just a vector of multisets.
"""
Islands are the collection of tiles that players can draw from. Each island has 4 tiles on it.
We initalise an island populateIsland!(island, bag) which will take an island and a bag and populate the island with 4 tiles from the bag.

```julia

I1 = Bag(Tile[])
B = CreateBag()

length(B) # 100

populateIsland!(I1, B)

length(I1) # 4
length(B) # 96
```
"""
function populateIsland!(island::Multiset, bag::Multiset)

    for i in 1:4
        try addTile!(island, drawTile!(bag)) # if the bag runs out, no stresso. 
        catch
            break
        end
    end

end

I1 = Multiset(Symbol[])
B = CreateBag()

length(B) # 100

populateIsland!(I1, B)

length(I1) # 4
length(B) # 96
##### Board #####
#######################################


##### Triangle #####

mutable struct TriangleRow
    tiles::Array{Symbol, 1}
    eligible::Set{Symbol}
    sz::Int
    completed::Bool
end

"""
Internal function for initalising a row of the triangle.
"""
function initRow(; len = 1)
    t = TriangleRow(Vector{Symbol}(undef, len), Set(tile_colours), len,false)
    # b =  (mosaicTile(:blank))
    t.tiles .= (:blank,)
    return t
end

initRow(len = 2)

"""
The triangle is the main part of the board. It is a triangle of tiles that players can add tiles to. The triangle has 5 rows, with the first row having 1 tile, the second row having 2 tiles, and so on, up to the 5th row having 5 tiles. 
there is also a 6th 'void' row with length 0 that players add tiles to if they have no other valid moves. This will move them into the boards discard.

The triangle is initalised with `initTriangle()`. This will return a triangle with 6 rows, the first 5 rows having 1, 2, 3, 4, and 5 tiles respectively, and the 6th row being the void row.
The triangle is initalised with blank tiles.

```julia
T = initTriangle()
T.rows[1].tiles # [:blank]
T.rows[2].tiles # [:blank, :blank]
```
"""
mutable struct Triangle
    rows::Array{TriangleRow, 1}

end

"""
The triangle is the main part of the board. It is a triangle of tiles that players can add tiles to. The triangle has 5 rows, with the first row having 1 tile, the second row having 2 tiles, and so on, up to the 5th row having 5 tiles. 
there is also a 6th 'void' row with length 0 that players add tiles to if they have no other valid moves. This will move them into the boards discard.

The triangle is initalised with `initTriangle()`. This will return a triangle with 6 rows, the first 5 rows having 1, 2, 3, 4, and 5 tiles respectively, and the 6th row being the void row.
The triangle is initalised with blank tiles.

```julia
T = initTriangle()
T.rows[1].tiles # [:blank]
T.rows[2].tiles # [:blank, :blank]
```


"""
function initTriangle()

    rows = TriangleRow[]
    for i in 1:5
        push!(rows, initRow(len = i))
    end 
    push!(rows, initRow(len = 0))
    return Triangle(rows)

end

Tri = initTriangle()
# I want to add a tile to the first tier of the triangle
Tri.rows[1].tiles[1] = :blue
Tri
# want to make this a subtype of Tile



"""
The pool is the collection of tiles in the middle of the board that players can draw from. The pool is initalised with a start tile. When players first take from the pool, they take the start tile, and they are the first player in the next round.

```julia
p = initPool()
p.tiles # [startTile()]
```
"""
function initPool()
    p = Multiset(Symbol[])
    push!(p, :start_token,1)
    return p
end

pool = initPool()


"""
This is the wall that tiles are placed on. This is a 5x5 bool matrix, that indicates if a tile is present in a given position. It pairs with the mosaicMap to see what colour tiles go where

```julia
M = initMosaic()
M.grid # 5x5 Array{Bool,2}
```
"""
mutable struct MosaicWall
    grid::Array{Bool, 2}  # (false, 5, 5)
end

"""
This is the wall that tiles are placed on. This is a 5x5 bool matrix, that indicates if a tile is present in a given position. It pairs with the mosaicMap to see what colour tiles go where

```julia
M = initMosaic()
M.grid # 5x5 Array{Bool,2}
```
"""
function initMosaic()

    M = Array{Bool}(undef, 5, 5)
    M .= false
    return MosaicWall(M)

end

M = initMosaic()

# Need a function that takes a colour and a row, adds the colour to the row, and calculates the score from adding that tile
"""
Finds the longest sequence of tiles in a row or column that the tile is in. This is used to calculate the score of adding a tile to the mosaic wall.

```julia

v = [true, true, true, false, true]
scoreVec(v, 1) # 3
scoreVec(v, 5) # 1

used on cols and rows of the mosaic wall to calculate the score of adding a tile

```
"""
function scoreVec(BooVec::Vector{Bool},pos::Int64)

    # Init at -1 because we don't want to double countthe center Tile
    cnt = -1
    i = pos

    # Look forwards
    while i ∈ 1:5 && BooVec[i]
        cnt+=1
        i+=1
    end

    i = pos # reinit the counter
    # Look Backwards
    while i ∈ 1:5 && BooVec[i]
        cnt+=1
        i-=1
    end

    # Later we take the min across both row and col being 1, so single squares need to go to zero, 
    # else the single square would equal 2
    if cnt == 1
        cnt = 0
    end
    return cnt
end


"""
This takes a mosiac wall, a colour and a row, and populates the row with the colour, modifying the wall. It then calculates the score of adding that tile to the row and returns it.

```julia
M = initMosaic()
addToRow!(M,:yellow,1) # 1
```
"""
function addToRow!(wall::MosaicWall,colour::Symbol,row::Int)

    # find the position of the color across
    if colour == :blank
        return 0
    end


    pos = findfirst(mosaicMap[row,:] .== colour)

    @assert pos ∈ 1:5 "Position not mosaic wall: $pos, $colour"
    @assert row ∈ 1:5 "Row not in mosaic wall: $row"


    # check if already populated
    # @assert wall.grid[row,pos] == false "There is already a tile present"
    if wall.grid[row,pos]
        @warn "There is already a tile present. Returning score anyway"
    end

    # update the value
    wall.grid[row,pos] = true

    # and find the score from the row
    # s = scoreVec(wall.grid[row,:],pos ) + scoreVec(wall.grid[:,pos],row)

    score = max(scoreVec(wall.grid[row,:],pos ) + scoreVec(wall.grid[:,pos],row ),1)

    return score

end

M = initMosaic()
addToRow!(M,:yellow,1)


function addToRow(wall::MosaicWall,colour::Symbol,row::Int)

    # find the position of the color across
    if colour == :blank
        return 0
    end

    pos = findfirst(mosaicMap[row,:] .== colour)

    @assert pos ∈ 1:5 "Position not mosaic wall: $pos, $colour"
    @assert row ∈ 1:5 "Row not in mosaic wall: $row"


    # check if already populated
    # @assert wall.grid[row,pos] == false "There is already a tile present"
    if wall.grid[row,pos]
        @warn "There is already a tile present. Returning score anyway"
    end

    score = max(scoreVec(wall.grid[row,:],pos ) + scoreVec(wall.grid[:,pos],row ),1)
    return score

end


# M = initMosaic()
# addToRow(M,:yellow,1)

"""
This board is the main object that players interact with. It hold the triangle, the mosaic wall, the discard, and the score of the player.

```julia
B = initBoard()
B.triangle # Triangle
B.mosaic # MosaicWall
B.discard # Bag
B.score # 0
```

"""
mutable struct Board

    triangle::Triangle
    mosaic::MosaicWall
    discard::Vector{Symbol}
    score::Int
    prevscore::Int
end

function initBoard()
    Board(initTriangle(), initMosaic(), Symbol[], 0, 0)
end


P1 = initBoard()


"""
this is the game object that holds everything that is needed to play the game. 
It holds the bag, the islands, the pool, the boards, the rounds, and the players turn.
You can choose between 2-4 players via players = 2,3,4

```julia
game = initGame(players = 2)
game.bag # Bag
game.islands # Islands
game.pool # Pool
game.boards # Vector{Board}
game.rounds # 0
game.playerTurn # 1
```

"""
mutable struct Game
    bag::Multiset{Symbol}
    islands::Vector{Multiset{Symbol}}
    pool::Multiset{Symbol}
    boards::Vector{Board}
    rounds::Int
    playerTurn::Int
    gameID::Int
    turn::Int
end
# Multiset(Symbol[])
function initGame(; players::Int = 2, playerStart = 1)
    bag = CreateBag()
    islands = Vector{Multiset{Symbol}}()
    pool = initPool()
    boards = Vector{Board}()
    rounds = 0
    id = rand(Int)

    if players == 2

        push!(boards, initBoard())
        push!(boards, initBoard())

        for i in 1:5
            I = Multiset(Symbol[])
            populateIsland!(I, bag)
            push!(islands, I)
        end
    end

    if players == 3

        push!(boards, initBoard())
        push!(boards, initBoard())
        push!(boards, initBoard())

        for i in 1:7
            I = Multiset(Symbol[])
            populateIsland!(I, bag)
            push!(islands, I)
        end

    end

    if players == 4

        push!(boards, initBoard())
        push!(boards, initBoard())
        push!(boards, initBoard())
        push!(boards, initBoard())

        for i in 1:9
            I = Multiset(Symbol[])
            populateIsland!(I, bag)
            push!(islands, I)
        end
    end

    return Game(bag, islands, pool, boards, rounds, playerStart,id,1)
end

game = initGame(players = 2)

# 


# check if a row is full
function isRowFull(row::TriangleRow)

    # count of tiles
    if row.sz == 0
        return false
    end
    if row.tiles[1] == :blank
        return false
    else
        return count( f -> f == row.tiles[1], row.tiles) == row.sz
    end
end


# game = initGame(players = 2)
# addTilesToRow!(game, 1, 2, [mosaicTile(:blue)]); # adds some tiles
# isRowFull(game.boards[1].triangle.rows[2]) # row has been filled up)



"""
This function takes a game, a board, a row, and a set of tiles, and applies the tiles to the row. If the row is full, it sets the row to completed, and if there are any tiles left, it puts them in the pool.

```julia
game = initGame(players = 2)
addTilesToRow!(game, 1, 2, [mosaicTile(:blue),mosaicTile(:blue),mosaicTile(:blue),]); # adds some tiles
game.boards[1].triangle.rows[2] # row has been filled up
game.boards[1].discard.tiles # one blue tile left over

```

note that the row of tiles all have to be the same colour

"""
function addTilesToRow!(game::Game, board_i::Int, row_i::Int, tiles::Vector{Symbol})
    
    @assert length(Set(tiles)) == 1 "Multiple colours in incoming tiles: $tiles"
    @assert tiles[1] ∈ game.boards[board_i].triangle.rows[row_i].eligible "Colour not eligible for row"

    if row_i == 6 # 0
        # Push tiles straight to the pool
        for tile in tiles
            push!(game.boards[board_i].discard, tile)
        end
        game.boards[board_i].discard = first(game.boards[board_i].discard, 7)
        return game
    end

    # update eligible colours 
    game.boards[board_i].triangle.rows[row_i].eligible = Set([tiles[1]])

    for i in 1:game.boards[board_i].triangle.rows[row_i].sz
        # for each bit in the row, we add the tile if it is blank
        if game.boards[board_i].triangle.rows[row_i].tiles[i] == :blank && length(tiles) > 0

            game.boards[board_i].triangle.rows[row_i].tiles[i] = pop!(tiles)
        end
    end

    # if we still have tiles here, it means the row has filled up so we update
    
    if row_i != 6 && isRowFull(game.boards[board_i].triangle.rows[row_i])
        game.boards[board_i].triangle.rows[row_i].completed = true
        # println("Row $row_i is completed")
    end

    # Now once we are out of the loop, we need to push the rest of the tiles to the pool
    for i in 1:length(tiles)
        push!(game.boards[board_i].discard, pop!(tiles))
    end
    # and ensure that we only have 7 in our discard.
    game.boards[board_i].discard = first(game.boards[board_i].discard, 7)
    return game

end

# game = initGame(players = 2)
# addTilesToRow!(game, 1, 2, [:blue,:blue,:blue]); # adds some tiles

# game.boards[1].triangle.rows[2] # row has been filled up
# game.boards[1].discard # one blue tile left over


"""
This function takes a game, a player, an island, a colour, and a row, and applies the player's action to the game. If the island =  0, the player is taking from the pool, otherwise they are taking from the island number.
This function will take the tiles from the pool or island, and apply them to the player's board. If the row is full, the tiles will go to the player's discard. If the player takes the start token, it will go to the player's discard.

```julia
game = initGame(players = 2)
game.islands.islands[1].tiles = [mosaicTile(:blue), mosaicTile(:blue), mosaicTile(:blue), mosaicTile(:red)]
playerAction!(game, 1, 1, :blue, 2)

game.boards[1].triangle.rows[2] # row has been filled up
game.boards[1].discard.tiles # one blue tile left over
game.pool.tiles # the rest of the tiles in the pool 
game.islands.islands # the island has been removed
```

Once an island is taken from it is removed, so islands won't maintain their id between turns.

"""
function playerAction!(game::Game, player::Int, island_i::Int, colour::Symbol, triangleRow::Int)

    # If island == 0, then we are pulling from the pool
    # If island > 0, then we are pulling from the specified island
    if island_i == 0

        slurp = game.pool
        if :start_token ∈ slurp
            # println("player $player has taken the start token")
            pushfirst!(game.boards[player].discard,:start_token) #put start token in discard
            slurp[:start_token] = 0 # remove start token from pool
            game.boards[player].discard = first(game.boards[player].discard, 7) # ensure discard is only 7
        end
    else
        slurp = game.islands[island_i]
    end

    println(slurp)
   
    if triangleRow == 0
        # Then we are adding straight to the discard
        triangleRow = 6  # This is the void row
    end

    # Assert that the colour is in the slurp
    @assert colour ∈ slurp "ERROR: Colour $colour not in pool or island $slurp"

    # Assert that the triangle is eligible for the colour
    @assert colour ∈ game.boards[player].triangle.rows[triangleRow].eligible "ERROR: Colour $colour not eligible for triangle $triangleRow"

    # Cool cool. Take the tiles from the slurp and dump the rest into the pool
    # See how many spaces we have in the triangle available.

    n = slurp[colour]

    # create a vector of n colours
    n_v = Symbol[]
    for i in 1:n
        push!(n_v, colour)
    end
    addTilesToRow!(game, player, triangleRow, n_v)

    # rm th tiles from the slurp
    slurp[colour] = 0

    println(slurp)

    if island_i != 0

        # and slap em back in the pool and rm the island
        println("moving things")
        for c in keys(slurp)
                push!(game.pool, c, slurp[c])
        end

        popat!(game.islands, island_i)
    else
        # and slap em back in the pool
        game.pool = slurp
 
    end

    println(slurp)


    game.playerTurn = mod1(player + 1, length(game.boards))
    game.turn += 1

    return game

end

# game = initGame()
# game.islands

# # # take 3rd tile from first factory
# playerAction!(game, 1, 1, first(keys(game.islands[1])), 5)
# game.islands
# game.boards[1].triangle.rows[5].tiles
# game.boards[1].discard
# game.pool

# an action is a tuple of the row, the colour, the location and the bag
# row is 1:6 with 6 being the discard
# colour is one of :blue, :yellow, :red, :black, :white
# where location is :I for island and :P for pool
# Eg
# (1, :blue, :I, {blue,blue,blue,blue})
# (6, :white, :P, {white,white,white})

# This is then hashed. 

function getActions(game::Game,player::Int)

    # ok, we want to get the actions from the pool and the islands
    # these are all bags we can draw from. 
    bags = Tuple[]
    for k in keys(game.pool)
        if k ∈ tile_colours

            n = game.pool[k]
            n = min(n, 7)
            push!(bags, (:P,Multiset([k for _ in 1:n])))

        end
    end
    # and look at the islands
    for i in game.islands
            push!(bags,(:I,i))
    end

    # for each bag, we want to see what rows we can add them to.
    # as well as what colours we could pull from them.

    validActions = Tuple[]

    for row in 1:6
        for bag in bags
            for token in keys(last(bag))
                if token ∈ game.boards[player].triangle.rows[row].eligible
                    push!(validActions, (row, token,first(bag), last(bag)))
                end

            end
            

        end
    end

    return validActions

end

game = initGame()
playerAction!(game, 1, 1, first(keys(game.islands[1])), 5)
game.pool
p = getActions(game,1)


"""
Contains a valid move that the player can select. These are a combination of the colours and pool/islands, as well as the valid rows to put the tiles in.

Produced in the playerMoves function for the runMove! function
"""
struct PlayerMove
    player::Int # player number
    colour::Symbol # tile colour that will be pulled
    amount::Int # amount of tiles of that colour
    pool::Int # 0 for pool, 1:island
    row::Int # triangle row to put the tiles
    hash::UInt # hash of the move that links to the action space
end

_player = 1
_colour = :blue
amount = 1
_pool = 1
_triangleRow = 1
# hash()
PM = PlayerMove(_player, _colour,2, _pool, _triangleRow,hash(1))

import Base.show

function Base.show(io::IO, move::PlayerMove)

    if move.pool == 0
        pool = "Pool"
    else
        pool = "Isl-$(move.pool)"
    end

    if move.row == 6
        row = "Discard"
    else
        row = "Row-$(move.row)"
    end

    println(io, "P$(move.player): $(move.amount) $(move.colour) from $pool -> $row")
end


# this returns a tuple of the pool or is
"""
Looks at the moves on the board and returns the moves that are possible for the player
returns a PlayerMove object that can be used in the runMove! function
"""
function playerMoves(game::Game,player::Int)

    actions = getActions(game,player) # get moves eligible for the player

    pMoves = PlayerMove[] # store the moves that are possible for the player

    # and apply them to the player's trianges to see what is possible
    for move in actions

        row = move[1]
        colour = move[2]
        pool = move[3]
        bag = move[4]

        sz = bag[colour]

        if pool == :I
            for i in 1:length(game.islands)
                if game.islands[i] == bag
                    push!(pMoves, PlayerMove(player, colour, sz, i, row, hash(move)))
                end
            end
        end
        if pool == :P
            push!(pMoves, PlayerMove(player, colour, sz, 0, row, hash(move)))
        end

    end

    return pMoves
end

PM = playerMoves(game,1)


# # This runs the move that comes from the function above.
"""
This function takes a game and a move, and applies the move to the game. The move is a PlayerMove object that is produced by the playerMoves function.
"""
function runMove!(game::Game, move::PlayerMove)
    playerAction!(game, move.player, move.pool, move.colour, move.row)
end


function isGameOver(game::Game)

    for b in game.boards

        for i in 1:5
            if b.mosaic.grid[i,:] == [true,true,true,true,true]
                # println("")
                # println("###")
                # println("Game is over")
                # println("###")

                return true
            end
        end
    end
    # else
    return false
end


# now we want to add the scoring function
function findWhoStarts(game::Game)

    b = 0
    for i in 1:length(game.boards)
        if :start_token ∈ game.boards[i].discard
            b = i
        end
    end

    return b
end

g = initGame()
g.boards[2].discard = [:start_token,:blue]
findWhoStarts(g)





function updateEligibilty!(board::Board)

    for i in board.triangle.rows
        if i.tiles !=Symbol[] && i.tiles[1] == :blank # this should mean that the row is empty
            # get the tiles that have been completed.

            colourRow = mosaicMap[i.sz,:]
            completed = board.mosaic.grid[i.sz,:]
            doneColours = colourRow[findall(x -> x == true, completed)]

            i.eligible = Set(setdiff(tile_colours, doneColours))

        end
    end
end
# game = initGame(players = 2)
# addTilesToRow!(game, 1, 2, [:blue,:blue])
# applyScore!(game.boards[1])
# updateEligibilty!(game.boards[1])



# This finds the amount we reduce the score by.
# n is the number of tiles in the discard row
"""
This function calculates the penalty for the number of tiles in the discard row. This is the number of tiles in the discard row divided by 2, rounded up.
"""
function pentaltyCalc(n)::Int

    score = 0

    for i in 1:n
        score +=ceil(4/2)
    end
    return score
end

"""
This function calculates the score
It moves all the tiles off of the board, updates the mosaic wall, calculates the score, and returns the tiles. 
It then updates the score of the board and updates eligible colours.

"""
function applyScore!(board::Board)

    returnTiles = CreateBag(empty = true)

    score = 0
    for i in board.triangle.rows

        if i.completed
            # update the score and rm the tiles
            score =  score + addToRow!(board.mosaic, i.tiles[1],i.sz)
            
            # Apply discard tiles to bag
            for n in 1:i.sz -1
                push!(returnTiles ,i.tiles[1])
            end

            # and reinit the row
            i.completed = false
            i.tiles = Vector{Symbol}(undef, i.sz)
            i.tiles .= (:blank)

        end
    end

    # now we look at the number of tiles in the discard
    score = score - pentaltyCalc(length(board.discard))

    # and update the board score
    board.score = board.score + score
    if board.score < 0
        board.score = 0
    end

    # and add these tiles to the output
    returnTiles = union(returnTiles,board.discard) ## need to make this work. Combine multisets somehwo?
    board.discard = Symbol[]

    # finally. update the eligible colours
    updateEligibilty!(board)

    return returnTiles
end


function finishRound!(game::Game)

    if length(getActions(game,game.playerTurn)) == 0

        # println("Round is over")

        # check what player has the start token
        game.playerTurn = findWhoStarts(game)


        # The round is over and we need to move objects over to the mosaic.
        for b in game.boards
            b.prevscore = b.score
            tiles = applyScore!(b) # apply score and do the things
            append!(game.bag,tiles) # add the leftover tiles to the bag.
        end

        # move the start token to the Pool
        push!(game.pool.tiles,popat!(game.bag.tiles,findfirst(x -> x.colour == :start_token ,game.bag.tiles)))
        # and update the round number
        game.rounds+=1 

        # repopulate the islands

        players  = length(game.boards)
        if players == 2
            for i in 1:5
                I = Bag(Tile[])
                populateIsland!(I, game.bag)
                if length(I.tiles) > 0
                    push!(game.islands.islands, I)
                end
            end
        end
        
        if players == 3
            for i in 1:7
                I = Bag(Tile[])
                populateIsland!(I, game.bag)
                if length(I.tiles) > 0
                    push!(game.islands.islands, I)
                end
            end
        
        end
        
        if players == 4
            for i in 1:9
                I = Bag(Tile[])
                populateIsland!(I, game.bag)
                if length(I.tiles) > 0
                    push!(game.islands.islands, I)
                end
            end
        end

        
        return game
    else

        println("ERROR: Round not over")
        return game

    end
end



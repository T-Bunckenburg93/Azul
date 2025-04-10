
using Random, DataFrames, Flux
import Flux.onehot


# Structures:
# Tile # Board # Triangle # Mosaic # Overflow # Score # Islands # Tile Management
"""
These are the colours of the tiles in the game
"""
const global tile_colours = [:blue, :yellow, :red, :black, :white]

# OneTo(9)

# Define the mosaic tiles
mTiles = deepcopy(tile_colours)
_mosaic = Array{Symbol, 2}(undef, 5, 5)

for i in 1:5
    _mosaic[i, 1:5] = mTiles[1:5]
    pushfirst!(mTiles, pop!(mTiles))
end


"""
this is the lookup for the mosaic tiles:
    :blue    :yellow  :red     :black   :white
    :white   :blue    :yellow  :red     :black
    :black   :white   :blue    :yellow  :red
    :red     :black   :white   :blue    :yellow
    :yellow  :red     :black   :white   :blue
"""
const global mosaicMap = _mosaic


##### Tile #####

# Tile Colours:

"""
Tiles are the basic unit of the game. They can be of any colour, or blank.

Access the colour of the tile with `tile.colour`:

```julia
t = mosaicTile(:blue)
t.colour # :blue
```

"""
abstract type Tile end


# Overload the Base functions for tile
import Base.==

function ==(t1::Tile, t2::Tile)
    t1.colour == t2.colour
end


"""
MosaicTile is a subtype of Tile. These are the tiles that are used in the game.
they can be present in either the bag, the pool, the islands, or the player's discard.
"""
struct MosaicTile <: Tile
    colour::Symbol
end

"""
Initaliser for MosaicTile. This will take a colour and return a MosaicTile.

```julia
t = mosaicTile(:blue)
s = mosaicTile("blue")
```

"""
function mosaicTile(colour::Union{String, Symbol})
    if colour isa String
        colour = Symbol(colour)
    end

    @assert colour ∈ vcat(tile_colours, :blank) "Colour not in tile colours"
    return MosaicTile(colour)
end

# mosaicTile(:blue)

##### Bag #####

"""
Bag is a collection of tiles. This is used to represent the bag of tiles that players draw from, but is also used to represent the pool of tiles in the middle of the board, the islands, and the player's discard.

A full Azul board can be initalised with `CreateBag()`. This will return a bag with 100 tiles, 20 of each colour.

An empty bag can be initalised with `CreateBag(empty = true)`. This will return an empty bag.

```julia
B = CreateBag()
B2 = CreateBag(empty = true)

length(B) # 100
length(B2) # 0

```

"""
mutable struct Bag
    tiles::Array{Tile, 1}
end

"""
Bag is a collection of tiles. This is used to represent the bag of tiles that players draw from, but is also used to represent the pool of tiles in the middle of the board, the islands, and the player's discard.

A full Azul board can be initalised with `CreateBag()`. This will return a bag with 100 tiles, 20 of each colour.

An empty bag can be initalised with `CreateBag(empty = true)`. This will return an empty bag.

```julia
B = CreateBag()
B2 = CreateBag(empty = true)

length(B) # 100
length(B2) # 0

```

"""
function CreateBag(; empty::Bool = false)

    tiles = Tile[]
    if !empty
        for colour in tile_colours
            for i in 1:20
                push!(tiles, mosaicTile(colour))
            end
        end
        shuffle!(tiles)
    end

    return Bag(tiles)
end


# Overload the Base functions for Bag
import Base.length
function length(x::Bag)
    length(x.tiles)
end
import Base.append!
function append!(bag::Bag,add::Bag)
    append!(bag.tiles,add.tiles)
end

B = CreateBag()
discard = CreateBag(empty = true)
pool = CreateBag(empty = true)


"""
This removes a tile from the bag and returns it. The bag is then shuffled

```julia
B = CreateBag()
t = drawTile!(B)
# t is a MosaicTile from the bag
```

"""
function drawTile!(bag::Bag)
    shuffle!(bag.tiles)
    return pop!(bag.tiles)
end
"""
This adds a tile to the bag and shuffles the bag

```julia
B = CreateBag()
t = mosaicTile(:blue)
addTile!(B, t)
```
"""
function addTile!(bag::Bag, tile::Tile)
    push!(bag.tiles, tile)
    shuffle!(bag.tiles)
end

B = CreateBag()
t1 = drawTile!(B)
addTile!(B, t1)

"""
This moves all the tiles in one bag to another bag, and then shuffles the bag

```julia
B1 = CreateBag(empty = true)    
B2 = CreateBag(empty = true)

addTile!(B1, mosaicTile(:blue))
addTile!(B1, mosaicTile(:red))

moveTiles!(B1, B2)

length(B1) # 0
length(B2) # 2

"""
function bagToBag!(discard::Bag, bag::Bag)

    for tile in discard.tiles
        addTile!(bag, tile)
    end
    discard.tiles = Tile[]
    shuffle!(bag.tiles)

end

# B1 = CreateBag(empty = true)
# B2 = CreateBag(empty = true)

# addTile!(B1, mosaicTile(:blue))
# addTile!(B1, mosaicTile(:red))

# bagToBag!(B1, B2)

# length(B1) # 0
# length(B2) # 2


##### Islands #####

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

"""
mutable struct Islands
    islands::Vector{Bag}
end

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

"""
function populateIsland!(island::Bag, bag::Bag)
    for i in 1:4
        try push!(island.tiles, drawTile!(bag)) # if the bag runs out, no stresso. 
        catch
            break
        end
    end
end


##### Board #####
#######################################

##### Triangle #####

mutable struct TriangleRow
    tiles::Array{MosaicTile, 1}
    eligible::Set{Symbol}
    sz::Int
    completed::Bool
end

"""
Internal function for initalising a row of the triangle.
"""
function initRow(; len = 1)
    t = TriangleRow(Vector{MosaicTile}(undef, len), Set(tile_colours), len,false)
    # b =  (mosaicTile(:blank))
    t.tiles .= (mosaicTile(:blank),)
    return t
end

initRow(len = 1)

"""
The triangle is the main part of the board. It is a triangle of tiles that players can add tiles to. The triangle has 5 rows, with the first row having 1 tile, the second row having 2 tiles, and so on, up to the 5th row having 5 tiles. 
there is also a 6th 'void' row with length 0 that players add tiles to if they have no other valid moves. This will move them into the boards discard.

The triangle is initalised with `initTriangle()`. This will return a triangle with 6 rows, the first 5 rows having 1, 2, 3, 4, and 5 tiles respectively, and the 6th row being the void row.
The triangle is initalised with blank tiles.

```julia
T = initTriangle()
T.rows[1].tiles # [mosaicTile(:blank)]
T.rows[2].tiles # [mosaicTile(:blank), mosaicTile(:blank)]
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
T.rows[1].tiles # [mosaicTile(:blank)]
T.rows[2].tiles # [mosaicTile(:blank), mosaicTile(:blank)]
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
Tri.rows[1].tiles[1] = mosaicTile(:blue)

# want to make this a subtype of Tile

mutable struct StartTile <: Tile
    colour::Symbol
end

function startTile()
    return StartTile(:start_token)
end

# # This is the player's overflow
# mutable struct Discard
#     tiles::Array{Tile, 1}
# end


# discar = Discard(Tile[])
# push!(discar.tiles, startTile())
# push!(discar.tiles, mosaicTile(:blue))
# discar.tiles

# This is the pool of tiles in the middle of the board
"""
The pool is the collection of tiles in the middle of the board that players can draw from. The pool is initalised with a start tile. When players first take from the pool, they take the start tile, and they are the first player in the next round.

```julia
p = initPool()
p.tiles # [startTile()]
```

"""
mutable struct Pool
    tiles::Array{Tile, 1}
end

"""
The pool is the collection of tiles in the middle of the board that players can draw from. The pool is initalised with a start tile. When players first take from the pool, they take the start tile, and they are the first player in the next round.

```julia
p = initPool()
p.tiles # [startTile()]
```
"""
function initPool()
    p = Bag(Tile[])
    push!(p.tiles, startTile())
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
    discard::Bag
    score::Int
    prevscore::Int
end

function initBoard()
    Board(initTriangle(), initMosaic(), CreateBag(empty = true), 0, 0)
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
    bag::Bag
    islands::Islands
    pool::Bag
    boards::Vector{Board}
    rounds::Int
    playerTurn::Int
    gameID::Int
    turn::Int
end

function initGame(; players::Int = 2, playerStart = 1)
    bag = CreateBag()
    islands = Islands(Bag[])
    pool = initPool()
    boards = Vector{Board}()
    rounds = 0
    id = rand(Int)

    if players == 2

        push!(boards, initBoard())
        push!(boards, initBoard())

        for i in 1:5
            I = Bag(Tile[])
            populateIsland!(I, bag)
            push!(islands.islands, I)
        end
    end

    if players == 3

        push!(boards, initBoard())
        push!(boards, initBoard())
        push!(boards, initBoard())

        for i in 1:7
            I = Bag(Tile[])
            populateIsland!(I, bag)
            push!(islands.islands, I)
        end

    end

    if players == 4

        push!(boards, initBoard())
        push!(boards, initBoard())
        push!(boards, initBoard())
        push!(boards, initBoard())

        for i in 1:9
            I = Bag(Tile[])
            populateIsland!(I, bag)
            push!(islands.islands, I)
        end
    end

    return Game(bag, islands, pool, boards, rounds, playerStart,id,1)
end

game = initGame(players = 2)

# The main game action: players can either pull a colour from the bag or the pool,
# and then apply it to a triangle on their board, and any other colours go to the pool.
# Any surplus colours go to their discard.
# ok, so I want a function that will apply tiles to the specified row of the triangle
# and pop the rest into the pool. We assume that the tiles are already in the slurp
# and that the colour is eligible for the row.

# check if a row is full
function isRowFull(row::TriangleRow)

    # count of tiles
    if row.sz == 0
        return false
    end
    if row.tiles[1].colour == :blank
        return false
    else
        return count( f -> f.colour == row.tiles[1].colour, row.tiles) == row.sz
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
function addTilesToRow!(game::Game, board_i::Int, row_i::Int, tiles::Union{Vector{Tile},Vector{MosaicTile}})
    
    @assert length(Set(tiles)) == 1 "Multiple colours in incoming tiles: $tiles"
    @assert tiles[1].colour ∈ game.boards[board_i].triangle.rows[row_i].eligible "Colour not eligible for row"

    if row_i == 6 # 0
        # Push tiles straight to the pool
        for tile in tiles
            push!(game.boards[board_i].discard.tiles, tile)
        end
        game.boards[board_i].discard.tiles = first(game.boards[board_i].discard.tiles, 7)
        return game
    end

    # update eligible colours 
    game.boards[board_i].triangle.rows[row_i].eligible = Set([tiles[1].colour])

    for i in 1:game.boards[board_i].triangle.rows[row_i].sz
        # for each bit in the row, we add the tile if it is blank
        if game.boards[board_i].triangle.rows[row_i].tiles[i].colour == :blank && length(tiles) > 0

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
        push!(game.boards[board_i].discard.tiles, pop!(tiles))
    end
    # and ensure that we only have 7 in our discard.
    game.boards[board_i].discard.tiles = first(game.boards[board_i].discard.tiles, 7)
    return game

end

mosaicTile.([:blue])


# This is the main game loop. Here a player chooses a tile from either the pool or an island.
# The corresponding effects are then applied.
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

        slurp = game.pool.tiles
        if StartTile(:start_token) ∈ slurp
            # println("player $player has taken the start token")
            pushfirst!(game.boards[player].discard.tiles, popat!(slurp, findfirst(x -> x.colour == :start_token, slurp)))
            game.boards[player].discard.tiles = first(game.boards[player].discard.tiles, 7)
        end
    else
        slurp = game.islands.islands[island_i].tiles
    end

   
    if triangleRow == 0
        # Then we are adding straight to the discard
        triangleRow = 6  # This is the void row
    end

    # Assert that the colour is in the slurp
    @assert MosaicTile(colour) ∈ slurp "ERROR: Colour $colour not in pool or island $slurp"

    # Assert that the triangle is eligible for the colour
    @assert colour ∈ game.boards[player].triangle.rows[triangleRow].eligible "ERROR: Colour $colour not eligible for triangle $triangleRow"

    # Cool cool. Take the tiles from the slurp and dump the rest into the pool
    # See how many spaces we have in the triangle available.
    tile_positions = findall(x -> x.colour == colour, slurp)

    # println(tile_positions)
    tiles2Add = slurp[tile_positions]  # Get the tiles to add
    addTilesToRow!(game, player, triangleRow, tiles2Add)  # Add them to a row

    # And add them to the row for i in 1:length(tile_positions)
    for i in 1:length(tile_positions)
        popat!(slurp, findfirst(x -> x.colour == colour, slurp))
    end

    if island_i != 0
        # Add to pool
        append!(game.pool.tiles, slurp)
        popat!(game.islands.islands, island_i)

    else
        # And add the rest to the pool
        game.pool.tiles = slurp
    end
    # finally update the player turn and game turn
    game.playerTurn = mod1(player + 1, length(game.boards))
    game.turn += 1

    return game

end


"""
This function checks the moves that are possible in the game. It returns a tuple of the pool or island to pull from, the colour of the tile, and the amount of tiles of that colour.

"""
function checkMoves(game::Game)

    moves = []
    # Check pool tiles
    for i in collect(Set(game.pool.tiles))
        if i.colour != :start_token

            len = length(findall(x -> x.colour == i.colour, game.pool.tiles))
            push!(moves, (0, i.colour, len))

        end
    end

    # Check island tiles

    for i in 1:length(game.islands.islands)
        for j in collect(Set(game.islands.islands[i].tiles))
            if j.colour != :start_token
                len = length(findall(x -> x.colour == j.colour, game.islands.islands[i].tiles))
                push!(moves, (i, j.colour, len))

            end
        end
    end
    return moves
end

"""
Contains a valid move that the player can select. These are a combination of the colours and pool/islands, as well as the valid rows to put the tiles in.

Produced in the playerMoves function for the runMove! function
"""
struct PlayerMove
    player::Int # player number
    colour::Symbol # tile colour that will be pulled
    amount::Int # amount of tiles of that colour
    pool::Int # pool to pull from
    row::Int # triangle row to put the tiles
end

_player = 1
_colour = :blue
amount = 1
_pool = 1
_triangleRow = 1
PM = PlayerMove(_player, _colour,2, _pool, _triangleRow)

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

    moves = checkMoves(game) # get moves eligible in the game. 
    pMoves = PlayerMove[] # store the moves that are possible for the player

    # and apply them to the player's trianges to see what is possible
    for move in moves

        pool = move[1]
        colour = move[2]
        amount = move[3]

        for row in 1:6
            if colour ∈ game.boards[player].triangle.rows[row].eligible
                # check if the row is full
                # if length(game.boards[player].triangle.rows[row].tiles) < game.boards[player].triangle.rows[row].sz
                    # || row == 6
                    # then we can add the move to the list of possible moves
                    
                    push!(pMoves, PlayerMove(player, colour,amount, pool, row))
                # end
            end
        end
    end

    return pMoves
end



# game = initGame()

# # take 3rd tile from first factory
# playerAction!(game, 1, 1, game.islands.islands[1].tiles[3].colour, 5)
# game.islands.islands

# # and take from the middle
# playerAction!(game, 2, 0, game.pool.tiles[end].colour, 5)

# # make a full row
# game.islands.islands[1].tiles = [mosaicTile(:blue), mosaicTile(:blue), mosaicTile(:blue), mosaicTile(:blue)]
# playerAction!(game, 2, 1, :blue, 4)


# playerMoves(game,1)

# game.boards[1].triangle.rows[5]



# # This runs the move that comes from the function above.
"""
This function takes a game and a move, and applies the move to the game. The move is a PlayerMove object that is produced by the playerMoves function.
"""
function runMove!(game::Game, move::PlayerMove)
    playerAction!(game, move.player, move.pool, move.colour, move.row)
end

game = initGame(players = 2)
moves = playerMoves(game,1)

moves[1]
# runMove!(game, moves[1])





# MosaicWall
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

pentaltyCalc(0)

# TriangleRow
# I want to take a board, move all the tiles off of it, update the mozaic wall, calculate the score and return the tiles,
# and then update the score of the board.
# This also yeets the start tile if it exists. 


function updateEligibilty!(board::Board)

    for i in board.triangle.rows
        if i.tiles !=MosaicTile[] && i.tiles[1].colour == :blank # this should mean that the row is empty
            # get the tiles that have been completed.

            colourRow = mosaicMap[i.sz,:]
            completed = board.mosaic.grid[i.sz,:]
            doneColours = colourRow[findall(x -> x == true, completed)]

            i.eligible = Set(setdiff(tile_colours, doneColours))

        end
    end
end


# game = initGame(players = 2)
# addTilesToRow!(game, 1, 2, [mosaicTile(:blue),mosaicTile(:blue)])
# applyScore!(game.boards[1])
# updateEligibilty!(game.boards[1])

game.boards[1].triangle.rows[2].eligible


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
            score =  score + addToRow!(board.mosaic, i.tiles[1].colour,i.sz)
            
            # Apply discard tiles to bag
            for n in 1:i.sz -1
                push!(returnTiles.tiles ,mosaicTile(i.tiles[1].colour))
            end

            # and reinit the row
            i.completed = false
            i.tiles = Vector{MosaicTile}(undef, i.sz)
            i.tiles .= (mosaicTile(:blank),)

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
    append!(returnTiles.tiles,board.discard.tiles)
    board.discard = CreateBag(empty = true)

    # finally. update the eligible colours
    updateEligibilty!(board)

    return returnTiles
end



game = initGame(players = 2)
# B = initBoard()

addTilesToRow!(game,1, 4, [mosaicTile(:blue),mosaicTile(:blue)])
game.boards[1].triangle.rows[4].tiles
game.boards[1].triangle.rows[4].eligible

applyScore!(game.boards[1])
game.boards[1].triangle.rows[4].completed

game.boards[1].mosaic.grid



game.boards[1]

game.boards[1].score
addTilesToRow!(game,1, 4, [mosaicTile(:blue),mosaicTile(:blue)])

game.boards[1].triangle.rows[4].tiles
game.boards[1].triangle.rows[4].eligible
game.boards[1].triangle.rows[4].completed
game.boards[1].discard.tiles



applyScore!(game.boards[1])


game.boards[1].score
game.boards[1].triangle.rows[4].eligible




function findWhoStarts(game::Game)

    b = 0
    for i in 1:length(game.boards)
        if startTile() ∈ game.boards[i].discard.tiles
            b = i
        end
    end

    return b
end

game = initGame()
_t = game.islands.islands[1].tiles

# take a tile
playerAction!(game, 1, 1, _t[3].colour, 5)
game.islands.islands

# and take from the middle
playerAction!(game, 2, 0, game.pool.tiles[end].colour, 5)

# make a full row
game.islands.islands[1].tiles = [mosaicTile(:blue), mosaicTile(:blue), mosaicTile(:blue), mosaicTile(:blue)]
playerAction!(game, 2, 1, :blue, 4)



applyScore!(game.boards[2])

game.bag

game.boards[2].score

game.boards[2].discard.tiles

findWhoStarts(game)

# finishRound!(game)


game.bag.tiles

gb = game.bag.tiles

findfirst(x -> x.colour == :start_token ,game.bag.tiles)
# A round ends when there are no more valid moves

function finishRound!(game::Game)

    if length(checkMoves(game)) == 0

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



# ok, so we want to check to see if the game is over.
# the game is over if a grid row is full

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

# looks at a board and returns the extra score of the players
function checkExtraScore!(board::Board)

    grid = board.mosaic.grid
    score = 0

    allColours = reshape(mosaicMap,25)[findall(x -> x == true, reshape(grid,25))]

    for i in 1:5
        if grid[i,:] == [true,true,true,true,true]
            # println("Row $i is full")
            score+= 2
        end
    end

    for i in 1:5
        if grid[:,i] == [true,true,true,true,true]
            # println("col $i is full")
            score+= 7
        end
    end

    # and all colours.
    for i in tile_colours

        if count(c -> c == i, allColours) == 5
            score+= 10
        end
    end

    return score
end





# ok, lets have a little test.

# println("Running Game!")

# This runs a game, and returns false if the game is not over, and true if the game is over.
function runGametest(;
    game = initGame(players = 2),
    game_df = DataFrame(gameState = Game[], move = PlayerMove[])
    )

    # println("Running Test Game!")
    # println("")

    # Show moves
    while checkMoves(game) != []
 
        p = game.playerTurn
        moves = playerMoves(game,p);
        moof = rand(moves)
        # println("Player $p is making a move")

        pool = moof.pool
        colour = moof.colour
        amount = moof.amount
        row = moof.row
        
        # println("Player $p is taking $amount $colour from pool $pool to put in row $row")

        push!(game_df,(deepcopy(game),deepcopy(moof)))
        runMove!(game,moof);
    end
    
        finishRound!(game);

        if isGameOver(game)
            for b in game.boards
                b.score+= checkExtraScore!(b)

                # println(b.score)
                # and push the final game state with the final scores.
                push!(game_df,(deepcopy(game),PlayerMove(0, :gameOver,0, -1, -1)))

                return true
            end

            # and print the final scores

        end

        return false;
end



"""
"""
function isWinner2px(game::Game,playerID::Int)

    p1_score = game.boards[1].score
    p2_score = game.boards[2].score

    if p1_score == p2_score
        # println("draw")
        return 1
    elseif playerID == 1 && p1_score > p2_score
        return 1
    elseif playerID == 2 && p2_score > p1_score
        return 1
    else
        return 0
    end
end




# Here are some ML functions that we use to process and train the model


# ok, so now we need to pull out this data and put it into a tabular form.
# for the person whos turn it is, is always the first person in the list
function processBag(bag::Bag)
    v = zeros(Int,5)
    for i in 1:5
        v[i] = count(x -> x.colour == tile_colours[i], bag.tiles)
    end
    return v
end
# function processBag(bag::TriangleRow)
#     v = zeros(Int,5)
#     for i in 1:5
#         v[i] = count(x -> x.colour == tile_colours[i], bag.tiles)
#     end
#     return v
# end

function processTriangleRow(tr::TriangleRow)
    sz = tr.sz
    m = Flux.onehotbatch(getfield.(tr.tiles,:colour),vcat(tile_colours,[:blank]))
    m2 = reshape(m,6*sz)
    return m2
end
# TriangleRow(game.boards[1].triangle.rows[5])

function processDiscard(discard::Bag)

    sz = length(discard.tiles)
    # Flux.onehotbatch(getfield.(discard.tiles,:colour),vcat(tile_colours,[:start_token]))
    m = reshape(Flux.onehotbatch(getfield.(discard.tiles,:colour),vcat(tile_colours,[:start_token])),6*sz)
    m2 = vcat(m,zeros(Bool,42 - length(m)))
    return m2

end


function processIsland(i::Bag)

    v = zeros(Int,20)

    m = Flux.onehotbatch(getfield.(i.tiles,:colour),tile_colours)
    mSz = size(m)
    ln = mSz[1]*mSz[2]
    m2 = reshape(m,ln)

    v[1:ln] = m2
    return v
end

g = initGame(players = 2)
processIsland(g.islands.islands[1])

function processPool(pool::Bag)

    # max pool length is 16 tokens for 2px
    v = zeros(Bool,16*6)
    sz = length(pool.tiles)

    m = Flux.onehotbatch(getfield.(pool.tiles,:colour),vcat(tile_colours,:start_token))
    m2 = reshape(m,sz*6)
    mSz = length(m2)
    v[1:mSz] = m2

    return v
end

processPool(g.pool)




game = initGame(players = 2)
game.pool
# game.boards[1].discard.tiles = [StartTile(:start_token),mosaicTile(:blue),mosaicTile(:blue),mosaicTile(:blue),mosaicTile(:blue),mosaicTile(:blue),mosaicTile(:blue),mosaicTile(:blue)]

# processDiscard(game.boards[1].discard)

# processDiscard(game.boards[1].discard)







processDiscard(game.boards[1].discard)

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

game = initGame(players = 2)
processBoard(game.boards[1])





"""
This turns the gamestate into a vector.
"""
function processGame2px(game::Game)

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
    island_sz = length(game.islands.islands)
    for i in 1:island_sz
        islands[20*i - 19:20*i] = processIsland(game.islands.islands[i])
    end


    return vcat(p1,p2,pool,islands)

end

g = initGame(players = 2)
processGame2px(g)

# and now process the move
# movetile_colours
"""
This transforms a a move into a vector.
"""
function processMove(move::PlayerMove)

    colour = zeros(Int,5)
    for i in 1:5
        colour[i] =  move.colour == tile_colours[i]
    end
    # pool = move.pool
    pool = onehot(move.pool,0:5)
    # row = move.row
    row = onehot(move.row,1:6)
    return vcat(colour,pool,row)
end


# processMove(moves[1])

function getScore(game::Game,playerID::Int)
    if playerID == 0
        return 0
    end
    return game.boards[playerID].score
end

# getScore(GameData.gameState,GameData.playerTurn)


# ok, so I want a function that looks at the move and game, and sees what the short term effect will be.
# This will basically be the scoring function.
function getShortTermEffect(game::Game,move::PlayerMove)

    if move.colour == :gameOver
        return 0
    end

    scoreΔ = 0
    board = game.boards[move.player]
    tile_n = move.amount

    row = board.triangle.rows[move.row]
    avalibleSlots = row.sz - length(findall(x -> x.colour != :blank, row.tiles))

    discardCosts  = [1,1,2,2,2,3,3]
    availableDiscardCosts = discardCosts[max(1,length(board.discard.tiles)):end]
    

    if move.pool == 0
        # Check for the start token
        if StartTile(:start_token) ∈ game.pool.tiles && length(availableDiscardCosts) > 0

            # Find the score from the start token going to discard
            scoreΔ -= availableDiscardCosts[1]
            # and modify the discard cost vector
            popfirst!(availableDiscardCosts)
            return scoreΔ
        end
    end


    if move.row == 6 && length(availableDiscardCosts) > 0
        # then we are going to discard all the tiles up to the amount available in the discard vec
        scoreΔ -= sum(availableDiscardCosts[1:min(tile_n,length(availableDiscardCosts))])
        return scoreΔ
    end

    if move.row != 6
        # then we are adding to a row
        if avalibleSlots > tile_n
            # then we won't fill up a row lol rip. 
            return scoreΔ
        else
            # ok, so now we look at its position on the grid, and see if there is any overflow.

            scoreΔ += addToRow(board.mosaic,move.colour,row.sz)

            if avalibleSlots < tile_n
                scoreΔ -= sum(availableDiscardCosts[1:min(tile_n - avalibleSlots,length(availableDiscardCosts))])
            end

            return scoreΔ
        end
    end
end

# g = initGame(players = 2)
# m = PlayerMove(1,:blue,5,1,5)
# getShortTermEffect(g,m)


function applyTargets(sdf::SubDataFrame)

    sdf.playerWin = isWinner2px.((sdf.gameState[end],),getfield.(sdf.move,1))
    sdf.playerScore = getScore.(sdf.gameState,sdf.playerTurn)
    # sdf._score = getScore.(sdf.gameState,sdf.playerTurn)

    endGame = sdf.gameState[end]

    p1 = getScore(endGame,1)
    p2 = getScore(endGame,2)

    leftjoin!(sdf,DataFrame(playerTurn = [1,2], fs = [p1,p2]),on = :playerTurn)
    sdf.finalScore = sdf.fs
    select!(sdf, Not(:fs))
    # DataFrame(player = [1,2], score = [p1,p2])

    # sdf.finalScore .= 1


    sdf.gameState[end].boards[2].mosaic.grid
    sdf.gameState[end].boards[1].score

    isGameOver(sdf.gameState[end])

    # checkExtraScore(sdf.gameState[end].boards[1])

    tile_colours
    B = sdf.gameState[end-1].boards[1]

    B.discard
    B.triangle.rows
    B.mosaic.grid

    score = combine(groupby(sdf,[:round,:playerTurn,]),:playerScore => maximum => :scoreNextRound)
    


    # get final scores:
    push!(score,(score.round[end],1,getScore(sdf.gameState[end],1)))
    push!(score,(score.round[end],2,getScore(sdf.gameState[end],2)))
    # move the score back one
    score.round .-= 1
    sdf2 = leftjoin(sdf,score,on = [:round,:playerTurn])

    sdf2.playerScoreIncrease = sdf2.scoreNextRound - sdf2.playerScore
    select!(sdf2, Not(:playerScore,:scoreNextRound))
    filter!(x -> !ismissing(x.playerScoreIncrease) ,sdf2)
    return sdf2
end


# gdf = combine(groupby(GameData, :ID), applyTargets)
function transformData(df_in)

    df = deepcopy(df_in)   

    df.vec = vcat.(processGame2px.(df.gameState),processMove.(df.move))
    df.shortTermMove = getShortTermEffect.(df.gameState,df.move)
    df.ID = getfield.(df.gameState,:gameID)
    df.playerTurn = getfield.(df.move,1)
    df.round = getfield.(df.gameState,:rounds)
    df.gameOver = isGameOver.(df.gameState)

    # targets
    df.playerWin .= 0
    df.playerScore .= 0
    df.playerScoreIncrease .= 0
    # df.finalScore .= 0
    
    _df = combine(groupby(df, :ID), applyTargets)
    filter!(row ->row.gameOver !== true,_df)
    return _df

end

# PlayerMove
# TriangleRowq


# function transformScore(x)
#     if x == 0 
#         return 0
#     elseif x > 0
#         return log(x+1)
#     else
#         return -log(-x+1)
#     end
# end
transformScore(x) = x   

function returnScore(x)
    if x == 0 
        return 0
    elseif x > 0
        return exp(x) - 1
    else
        return -exp(-x) + 1
    end
end

# take a gamestate and a move and score the outcome

function getVec(game::Game,move::PlayerMove)

    vec = vcat(processGame2px(game),processMove(move))
    return vec

end




# ok, so I want to be able to run multiple models, so I can pass the model in as a param. 
function pickMove(game::Game, player::Int; model=rand,all = false)

    p = game.playerTurn
    @assert p == player "Player $player does not have the current turn"

    moves = playerMoves(game,p);

    if model == rand
        move = rand(moves)
        return move
    end

    if model == getShortTermEffect
        shuffle!(moves) # jiggle it around a bit.
        preds = getShortTermEffect.((game,),moves)
        move = moves[findmax(preds)[2]]
        if all
            return moves,preds
        end
        return move

    end

    # else score the model

    vec = hcat(getVec.((game,),moves)...)
    preds = (model(vec |> device) |> cpu)[1,:]

    move = moves[findmax(preds)[2]]
    # move = moves[findmin(preds)[2]]

    if all
        return moves,preds
    end
    return move

end



"""
This runs a game of azul with specified models. Returns true if the game is over.
"""
function runRound(;
    game = initGame(players = 2),
    game_df = DataFrame(gameState = Game[], move = PlayerMove[]),
    p1 = rand,
    p2 = rand,
    p3 = rand,
    p4 = rand
)

while checkMoves(game) != []
 
    p = game.playerTurn
    # println("Player $p is making a move")
    # select the players move
    if     p == 1
        move = pickMove(game,p,model = p1)
    elseif p == 2
        move = pickMove(game,p,model = p2)
    elseif p == 3
        move = pickMove(game,p,model = p3)
    elseif p == 4
        move = pickMove(game,p,model = p4)
    end

    pool = move.pool
    colour = move.colour
    amount = move.amount
    row = move.row
    # println("Player $p is taking $amount $colour from pool $pool to put in row $row")

    push!(game_df,(deepcopy(game),deepcopy(move)))
    runMove!(game,move);
end

    finishRound!(game);
    if isGameOver(game)
        for b in game.boards
            b.score+= checkExtraScore!(b)

            # and push the final game state with the final scores.
            push!(game_df,(deepcopy(game),PlayerMove(0, :gameOver,0, 1, 1)))
            return true
        end

    end
    # Game is not over so return false
    return false

end




using Random

# Structures:
# Tile # Board # Triangle # Mosaic # Overflow # Score # Islands # Tile Management
const global tile_colours = [:blue, :yellow, :red, :black, :white]

# Define the mosaic tiles
mTiles = deepcopy(tile_colours)
_mosaic = Array{Symbol, 2}(undef, 5, 5)

for i in 1:5
    _mosaic[i, 1:5] = mTiles[1:5]
    pushfirst!(mTiles, pop!(mTiles))
end
const global mosaicMap = _mosaic


##### Tile #####

# Tile Colours:

# Start_token
abstract type Tile end

# add equivulency
import Base.==
function ==(t1::Tile, t2::Tile)
    t1.colour == t2.colour
end

struct MosaicTile <: Tile
    colour::Symbol
end


function mosaicTile(colour::Union{String, Symbol})
    if colour isa String
        colour = Symbol(colour)
    end

    @assert colour ∈ vcat(tile_colours, :blank) "Colour not in tile colours"
    return MosaicTile(colour)
end

# mosaicTile(:blue)

##### Bag #####


mutable struct Bag
    tiles::Array{Tile, 1}
end


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


function drawTile!(bag::Bag)
    return pop!(bag.tiles)
end

function addTile!(bag::Bag, tile::Tile)
    push!(bag.tiles, tile)
    shuffle!(bag.tiles)

end
B = CreateBag()
t1 = drawTile!(B)
addTile!(B, t1)


function discard2Bag!(discard::Bag, bag::Bag)

    for tile in discard.tiles
        addTile!(bag, tile)
    end

    discard.tiles = Tile[]
    shuffle!(bag.tiles)

end


##### Islands #####

mutable struct Islands
    islands::Array{Bag, 1}
end

 
function populateIsland!(island::Bag, bag::Bag)
    for i in 1:4
        push!(island.tiles, drawTile!(bag))
    end
end
I1 = Bag(Tile[])
populateIsland!(I1, B)
I1

##### Board #####
#######################################

##### Triangle #####

mutable struct TriangleRow
    tiles::Array{MosaicTile, 1}
    eligible::Set{Symbol}
    sz::Int
    completed::Bool
end


function initRow(; len = 1)
    t = TriangleRow(Vector{MosaicTile}(undef, len), Set(tile_colours), len,false)
    # b =  (mosaicTile(:blank))
    t.tiles .= (mosaicTile(:blank),)
    return t
end

initRow(len = 1)

mutable struct Triangle
    rows::Array{TriangleRow, 1}
end

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
mutable struct Pool
    tiles::Array{Tile, 1}
end

function initPool()
    p = Bag(Tile[])
    push!(p.tiles, startTile())
    return p
end

pool = initPool()

# We will do score and mosaic tiles later

# Lets do the interactions between the board and the bag during a round.
# Score is literally just a number that can't drop to zero.
# Mosaic is a bit trickier?

mutable struct MosaicWall
    grid::Array{Bool, 2}  # (false, 5, 5)
end

function initMosaic()

    M = Array{Bool}(undef, 5, 5)
    M .= false
    return MosaicWall(M)

end

M = initMosaic()

# Need a function that takes a colour and a row, adds the colour to the row, and calculates the score from adding that tile

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
    s = scoreVec(wall.grid[row,:],pos ) + scoreVec(wall.grid[:,pos],row)

    score = max(scoreVec(wall.grid[row,:],pos ) + scoreVec(wall.grid[:,pos],row ),1)

    return score

end

M = initMosaic()
addToRow!(M,:yellow,1)

# islands::Islands
# pool::Pool
# Init the board
mutable struct Board

    triangle::Triangle
    mosaic::MosaicWall
    discard::Bag
    score::Int
end

function initBoard()
    Board(initTriangle(), MosaicWall(Array{Bool}(undef, 5, 5)), CreateBag(empty = true), 0)
end

# P1 = initBoard()

mutable struct Game
    bag::Bag
    islands::Islands
    pool::Bag
    boards::Vector{Board}
    rounds::Int
    playerTurn::Int
end

function initGame(; players::Int = 2, playerStart = rand(1:players))
    bag = CreateBag()
    islands = Islands(Bag[])
    pool = initPool()
    boards = Vector{Board}()
    rounds = 0

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

    return Game(bag, islands, pool, boards, rounds, playerStart)
end

game = initGame(players = 2)

# The main game action: players can either pull a colour from the bag or the pool,
# and then apply it to a triangle on their board, and any other colours go to the pool.
# Any surplus colours go to their discard.
# ok, so I want a function that will apply tiles to the specified row of the triangle
# and pop the rest into the pool. We assume that the tiles are already in the slurp
# and that the colour is eligible for the row.

function addTilesToRow!(game::Game, board_i::Int, row_i::Int, tiles::Union{Vector{Tile},Vector{MosaicTile}})
    
    @assert length(Set(tiles)) == 1 "Multiple colours in incoming tiles: $tiles"
    @assert tiles[1].colour ∈ game.boards[board_i].triangle.rows[row_i].eligible "Colour not eligible for row"

    if row_i == 0
        # Push tiles straight to the pool
        for tile in tiles
            push!(game.boards[board_i].discard.tiles, tile)
        end
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
    if length(tiles) > 0 && row_i != 6
        game.boards[board_i].triangle.rows[row_i].completed = true
        println("Row $row_i is completed")
    end

    # Now once we are out of the loop, we need to push the rest of the tiles to the pool
    for i in 1:length(tiles)
        push!(game.boards[board_i].discard.tiles, pop!(tiles))
    end
    return game

end

game = initGame(players = 2)
addTilesToRow!(game, 1, 2, [mosaicTile(:blue),]);
game.boards[1].triangle.rows[2]


# This is the main game loop. Here a player chooses a tile from either the pool or an island.
# The corresponding effects are then applied.
function playerAction!(game::Game, player::Int, island_i::Int, colour::Symbol, triangleRow::Int)

    # If island == 0, then we are pulling from the pool
    # If island > 0, then we are pulling from the specified island
    if island_i == 0

        slurp = game.pool.tiles
        if StartTile(:start_token) ∈ slurp
            println("player $player has taken the start token")
            push!(game.boards[player].discard.tiles, popat!(slurp, findfirst(x -> x.colour == :start_token, slurp)))
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
    # finally update the player turn.
    game.playerTurn = mod1(player + 1, length(game.boards))

    return game

end
game = initGame(players = 2)
_t = game.islands.islands[1].tiles
playerAction!(game, 1, 1, _t[3].colour, 5)
game.islands.islands
game.boards[1].discard.tiles

# game.pool.tiles
# Player action example:
# playerAction!(game, 1, 0, :white, 5)
# game.boards[1]
# Check for vaid options for moves

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

# This is a move object that will be used to store the moves that are possible for the player
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



# this returns a tuple of the pool or is
"""
Looks at the moves on the board and returns the moves that are possible for the player
returns a tuple 
(pool to pull from, colour, amount, triangeRow)
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



game = initGame()

# take 3rd tile from first factory
playerAction!(game, 1, 1, game.islands.islands[1].tiles[3].colour, 5)
game.islands.islands

# and take from the middle
playerAction!(game, 2, 0, game.pool.tiles[end].colour, 5)

# make a full row
game.islands.islands[1].tiles = [mosaicTile(:blue), mosaicTile(:blue), mosaicTile(:blue), mosaicTile(:blue)]
playerAction!(game, 2, 1, :blue, 4)


playerMoves(game,1)

game.boards[1].triangle.rows[5]



# # This runs the move that comes from the function above.
function runMove!(game::Game, move::PlayerMove)

    playerAction!(game, move.player, move.pool, move.colour, move.row)

end

game = initGame(players = 2)
moves = playerMoves(game,1)

moves[1]
runMove!(game, moves[1])





# MosaicWall
# This finds the amount we reduce the score by.
# n is the number of tiles in the discard row

function pentaltyCalc(n)::Int

    score = 0

    for i in 1:n
        score +=ceil(4/2)
    end
    return score
end

pentaltyCalc(2)

# I want to take a board, move all the tiles off of it, update the mozaic wall, calculate the score and return the tiles,
# and then update the score of the board.
# This also yeets the start tile if it exists. 
function applyScore!(board::Board)

    returnTiles = CreateBag(empty = true)

    score = 0
    for i in board.triangle.rows

        if i.completed
            # update the score and rm the tiles
            score+= addToRow!(board.mosaic, i.tiles[1].colour,i.sz)
            
            # Apply discard tiles to bag
            for n in 1:i.sz
                push!(returnTiles.tiles ,mosaicTile(i.tiles[1].colour))
            end

            # and reinit the row
            i.completed = false

        end
    end

    # now we look at the number of tiles in the discard
    score =- pentaltyCalc(length(board.discard))

    # and update the board score
    board.score = max(board.score + score,0)

    # and add these tiles to the output
    append!(returnTiles.tiles,board.discard.tiles)
    board.discard = CreateBag(empty = true)

    return returnTiles

end

B = initBoard()

B.triangle.rows[4].tiles = [mosaicTile(:blue), mosaicTile(:blue), mosaicTile(:blue), mosaicTile(:blue)]
B.discard.tiles = [mosaicTile(:blue), mosaicTile(:blue)]

B.triangle.rows


applyScore!(B)



B.score

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

        println("Round is over")

        # check what player has the start token
        game.playerTurn = findWhoStarts(game)

        # The round is over and we need to move objects over to the mosaic.
        for b in game.boards

            tiles = applyScore!(b) # apply score and do the things
            append!(game.bag,tiles) # add the leftover tiles to the bag.
        end
        # move the start token to the Pool
        push!(game.pool.tiles, startTile())

        return game
    else

        println("ERROR: Round not over")
        return game

    end
end



checkMoves(game)[1]
# ok, lets have a little test.

# println("Running Game!")


function runGametest()
    println("Running Test Game!")
    println("")

    # Init the game
    game = initGame(players = 2)

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
        
        println("Player $p is taking $amount $colour from pool $pool to put in row $row")

        runMove!(game,moof);
    end
    
        # finishRound!(game);
        return game;

end





gtest = runGametest();

gtest.boards[1].score
gtest.boards[2].score
gtest.boards[1].triangle.rows


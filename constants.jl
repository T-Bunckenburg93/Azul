using Combinatorics
using Multisets

"""
These are the colours of the tiles in the game
"""
const global tile_colours = [:blue, :yellow, :red, :black, :white]

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


I = multiset_combinations([tile_colours;tile_colours;tile_colours;tile_colours;tile_colours], 4)

I = Multiset.(collect(I))

T_I = tuple.(:I,I)


pool_I = Multiset[]
for i in tile_colours
    for sz in 1:7 # if its larger than 7, it will be impossible to fill the discard so any more is meaningless
        push!(pool_I, Multiset([i for _ in 1:sz]))
    end
end
pool_I
P_I = tuple.(:P, pool_I)

I_choice = vcat(T_I,P_I)


unique(I_choice)

I_all = Tuple[]

for row in 1:6
    for choice in I_choice
        for token in unique(last(choice))
            push!(I_all, (row, token, first(choice),last(choice)))
        end
    end
end

I_all

I_all_hash = hash.(I_all)
"""
Hashed action space for Azul. Actions are represented as a tuple of (row, token, choice) and then hashed:
    hash((row, token, colours)) # 

"""
const global hashActionMap = I_all_hash

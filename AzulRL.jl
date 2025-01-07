import ReinforcementLearningBase: RLBase
import ReinforcementLearningCore: Player
import CommonRLInterface
using Combinatorics
using Multisets

# First up, lets define the constants of Azul.
include("constants.jl")

# Next, lets define the game state.








# ok, so I need to find/define an action space.

# how many combinations of actions are there?
# lets look at the islands:
# each island has 4 tiles, and there are 5 colours,
I = multiset_combinations([tile_colours;tile_colours;tile_colours;tile_colours;tile_colours], 4)

I = Multiset.(collect(I))

pool_I = Multiset[]
for i in tile_colours
    for sz in 1:7 # if its larger than 7, it will be impossible to fill the discard so any more is meaningless
        push!(pool_I, Multiset([i for _ in 1:sz]))
    end
end

token_I = deepcopy(pool_I)
for i in token_I
    push!(i, :start_token)
end

I_choice = vcat(I, pool_I)

I_all = Tuple[]

for row in 1:6
    for choice in I_choice
        for token in unique(choice)
            push!(I_all, (row,token, choice))
        end
    end
end

I_all

I_all_hash = hash.(I_all)

# This is the action space.


# given a game I need to generate the eligible actions from the state space. 

g = initGame(players = 2);
playerMoves(g,1)

i = g.islands.islands[1]

# i should return 4 moves


zeros(Bool, length(I_all))

function get_actions_island(i::Bag)

    colours = Multiset(getfield.(i.tiles, :colour))
    actions = zeros(Bool, length(I_all))
    
    for row in 1:6 
        for token in unique(colours)

            actions[findfirst( x-> x == hash((row, token, colours)), I_all_hash)] = true

            # push!(actionHash, hash((row, token, colours)))
        end
    end

    return actions
end

h_actions = get_actions_island(i)



get_actions(g) = sum(get_actions.(g.islands.islands))




# intersect(h_actions, I_all_hash)




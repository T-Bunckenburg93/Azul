# import ReinforcementLearningBase: RLBase
# import ReinforcementLearningCore: Player
# import CommonRLInterface
using Combinatorics
using Multisets
using Random


# First up, lets define the constants of Azul.
include("constants.jl")
include("game.jl")
include("processGame.jl")


# Game <: AbstractEnv

mutable struct GameEnv <: AbstractEnv
    game::Game
end

RLBase.players(::GameEnv) = (Player(1), Player(2))

function RLBase.reset!(env::GameEnv)
    env.game = initGame()
end

function RLBase.act!(env::GameEnv,action::PlayerMove)
    runMove!(env.game,action)
end




RLBase.action_space(env::GameEnv) = zeros(Bool,length(hashActionMap))

function legal_action_space(env::GameEnv, player::Player)

    p_id = parse(Int,String(player.name))
    legal_action_space = zeros(Bool,length(hashActionMap))

    pm = playerMoves(env.game,p_id)
    for p in pm
        legal_action_space[findfirst(x -> x == p.hash , hashActionMap)] = true
    end
    return legal_action_space

end

legal_action_space(env::GameEnv) = legal_action_space(env,Player(env.game.playerTurn))

function RLBase.is_terminated(env::GameEnv)

    isGameOver(env.game)

end

function RLBase.reward(env::GameEnv, player::Player)
    if isGameOver(env.game)
        p_id = parse(Int,String(player.name))
        return env.game.boards[p_id].score
    else
        return 0
    end
end




RLBase.state_space(env::GameEnv) = processGame2px(env.game)
RLBase.state(env::GameEnv, ::Observation, ::AbstractPlayer) = env.game

RLBase.current_player(env::GameEnv) = Player(env.game.playerTurn)

RLBase.NumAgentStyle(::GameEnv) = MultiAgent(2)
RLBase.DynamicStyle(::GameEnv) = SEQUENTIAL
RLBase.ActionStyle(::GameEnv) = FULL_ACTION_SET
RLBase.InformationStyle(::GameEnv) = PERFECT_INFORMATION
# RLBase.StateStyle(::GameEnv) = (Observation{Int}(), Observation{String}(), Observation{BitArray{3}}())
# RLBase.RewardStyle(::GameEnv) = TERMINAL_REWARD
# RLBase.UtilityStyle(::GameEnv) = ZERO_SUM
RLBase.ChanceStyle(::GameEnv) = DETERMINISTIC



g = initGame()
env = GameEnv(g)



fieldnames(typeof(Player(1)))

parse(Int,String(Player(1).name))

policy = RandomPolicy(action_space(env))

policy(env)

x = collect(Base.OneTo(4))

reward(env,Player(1))


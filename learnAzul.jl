include("main.jl")

import Flux, Flux.onehot
using StatsBase, Flux, ProgressMeter, Plots
using CUDA  # optional

device = gpu_device()  # function to move data and model to the GPU


# # Now we run a few random games

initData = DataFrame(gameState = Game[], move = PlayerMove[])
# runGametest(game = game,game_df = GameData)

for i in 1:10
    game = initGame(players = 2);

    gameLive = false
    while !gameLive
        gameLive = runRound(game = game,game_df = initData)
    end
end

initData

function getdiscard(game)
    return game.boards[1].discard
end

initData.discard = getdiscard.(initData.gameState)
initData.discard_ln = length.(initData.discard) 

sort!(initData.discard_ln)

initData


data = transformData(initData)
data.vec[1]
# # tile_colours

# board = GameData.gameState[4].boards[1]
# length(game.islands.islands)


randomGameData = DataFrame(gameState = Game[], move = PlayerMove[])
# runGametest(game = game,game_df = GameData)
@info "Running Random Games"
@showprogress for i in 1:100
    game = initGame(players = 2);
    gameLive = false
    while !gameLive && game.rounds < 50
        gameLive = runRound(game = game,game_df = randomGameData,p1=rand,p2=rand)
    end
end
# filter so we only have the games that actually come out to a result
randomdf = transformData(randomGameData)
inData = hcat(randomdf.vec...)
inTarget = Float32.(hcat(transformScore.(randomdf.playerScoreIncrease))')
h = histogram(inTarget[1,:],title = "Score Increase Distribution for Random Moves",xlabel = "Score Increase",ylabel = "Frequency")
display(h)




STGameData = DataFrame(gameState = Game[], move = PlayerMove[])
# runGametest(game = game,game_df = GameData)
@info "Running best ST moves Games"
@showprogress for i in 1:10000
    game = initGame(players = 2);
    gameLive = false
    while !gameLive && game.rounds < 50
        gameLive = runRound(game = game,game_df = STGameData,p1=getShortTermEffect,p2=getShortTermEffect)
    end
end

# filter so we only have the games that actually come out to a result
# GameData2 = filter(row-> row.move.colour == :gameOver && (row.gameState.boards[1].score > 0 || row.gameState.boards[2].score > 0)  ,GameData)
STGameData
st_df = transformData(STGameData) ## This could be faster :/
st_df

mean(st_df.finalScore)

# target = 

inData = hcat(st_df.vec...)
inTarget = Float32.(hcat(transformScore.(st_df.finalScore))')
# inTarget = Float32.(randomdf.playerScoreIncrease)'
h = histogram(inTarget[1,:],title = "Score Increase Distribution for Best short term moves",xlabel = "Score Increase",ylabel = "Frequency")
display(h)


# # Now we train a model on the random games
loader = Flux.DataLoader((inData, inTarget), batchsize=16, shuffle=true)

inDims = size(inData,1)
Hdims = 100

model = Chain(
    # Encoder layer
    Dense(inDims, inDims),
    Dense(inDims, inDims),
    Dense(inDims, Hdims),
    # Dense(Hdims, 10),
    Dense(Hdims, Hdims),
    Dense(Hdims, Hdims),
    Dense(Hdims, Hdims),
    Dense(Hdims, Hdims),
    Dense(Hdims, Hdims),
    Dense(Hdims, 1)
) |> device

optim = Flux.setup(Flux.Adam(0.01), model)
# train the first bit
loss_values = Float64[]

@info "Training Model on random games"
@showprogress for i in 1:10
    # for (x, target) in zip(X, y)
    
    for xy_cpu in loader
        x, y = xy_cpu |> device
        val, grads = Flux.withgradient(model) do m
            y_hat = m(x)
            Flux.mse(y_hat, y)
            # Flux.logitbinarycrossentropy(y_hat, y)
        end
        Flux.update!(optim, model, grads[1])
        push!(loss_values, val)
    end
end
plotLoss = plot(loss_values, title="Training Loss on Random Games", xlabel="Iteration", ylabel="Loss" ,legend = false, ylims = (0,maximum(loss_values)+0.1))
display(plotLoss)
loss_values
# need a way to check that the model isn't just shitting out zeros.

test  = model(inData|>device) |> cpu
mean(test)
histogram(test[1,:])




g = STGameData.gameState[1]
p = g.playerTurn
# playerMoves(g,p);
pickMove(g,p,model=model)
pickMove(g,p,model=getShortTermEffect)
# Now we run a few games with the model

raw = DataFrame(gameState = Game[], move = PlayerMove[])
@info "Running Games with model"
@showprogress  for i in 1:100
    game = initGame(players = 2);

    gameLive = false
    while !gameLive && game.rounds < 50
        gameLive = runRound(game = game,game_df = raw,p1 = model,p2 = model)
    end
end

df = transformData(raw)

inData = hcat(df.vec...)
inTarget = Float32.(hcat(transformScore.(df.finalScore))')
minimum(inTarget)
h = histogram(inTarget[1,:],title = "Score Increase Distribution for trained model v1",xlabel = "Score Increase",ylabel = "Frequency")
display(h)



# if we make em fight, who wins? Any good model need to beat this


raw = DataFrame(gameState = Game[], move = PlayerMove[])
@info "Running Games with model"
@showprogress  for i in 1:100
    game = initGame(players = 2);

    gameLive = false
    while !gameLive && game.rounds < 50
        gameLive = runRound(game = game,game_df = raw,p1 = model,p2 = getShortTermEffect)
    end
end


finishedGames = filter(row-> row.move.colour == :gameOver,raw)
finishedGames.p1_score = getScore.(finishedGames.gameState,1)
finishedGames.p2_score = getScore.(finishedGames.gameState,2)
finishedGames.player1Win = finishedGames.p1_score .> finishedGames.p2_score
finishedGames.player1Draw = finishedGames.p1_score .== finishedGames.p2_score
sum(finishedGames.player1Win)/1000
sum(finishedGames.player1Draw)/1000
mean(finishedGames.p1_score)
mean(finishedGames.p2_score)

println("Player 1 wins $(sum(finishedGames.player1Win)/100) of the time")


g = finishedGames.gameState[1]
p = g.playerTurn


playerMoves(g,p)

moves,preds = pickMove(g,p,model=model,all=true)
sort(DataFrame(m=moves,p=preds),:p)

pickMove(g,p,model=model)

loader = Flux.DataLoader((inData, inTarget) |> device, batchsize=1024, shuffle=true)
optim = Flux.setup(Flux.Adam(0.01), model)

model2 = Chain(
    # Encoder layer
    Dense(inDims, Hdims),
    Dense(Hdims, Hdims),
    # Dense(Hdims, Hdims),
    Dense(Hdims, 1)
) |> device

optim = Flux.setup(Flux.Adam(0.01), model2)
# train the first bit
loss_values2 = Float64[]

# and train the model again:
@info "Training Model on new data"
@showprogress for i in 1:5

    for xy_cpu in loader
        x, y = xy_cpu |> device
        val, grads = Flux.withgradient(model2) do m
            y_hat = m(x)
            Flux.mse(y_hat, y)
            # Flux.logitbinarycrossentropy(y_hat, y)
            
        end
        Flux.update!(optim, model2, grads[1])
        push!(loss_values2, val)
    end
end

plotLoss2 = plot(loss_values2, title="Training loss on second iteration", xlabel="Iteration", ylabel="Loss" ,legend = false,)
display(plotLoss2)

test = model2(inData|>device) |> cpu
mean(test)



# Lets test the model against a random player
randomeTest = DataFrame(gameState = Game[], move = PlayerMove[])
@info "Running Games with model"
@showprogress  for i in 1:100
    game = initGame(players = 2);

    gameLive = false
    while !gameLive && game.rounds < 50
        gameLive = runRound(game = game,game_df = randomeTest,p1 = model,p2 = rand)
    end
end

# player

finishedGames = filter(row-> row.move.colour == :gameOver,randomeTest)

finishedGames.p1_score = getScore.(finishedGames.gameState,1)
finishedGames.p2_score = getScore.(finishedGames.gameState,2)

finishedGames.player1Win = finishedGames.p1_score .> finishedGames.p2_score
finishedGames.player1Draw = finishedGames.p1_score .== finishedGames.p2_score

sum(finishedGames.player1Win)/100
sum(finishedGames.player1Draw)/100
mean(finishedGames.p1_score)
mean(finishedGames.p2_score)

println("Player 1 wins $(sum(finishedGames.player1Win)/100) of the time")

finishedGames.gameState[1].boards[1].mosaic.grid
finishedGames.gameState[1].boards[1].score
MosaicWall


# Lets test the model1 against a model2 player
randomeTest = DataFrame(gameState = Game[], move = PlayerMove[])
@info "Running Games with model"
@showprogress  for i in 1:100
    game = initGame(players = 2);

    gameLive = false
    while !gameLive && game.rounds < 50
        gameLive = runRound(game = game,game_df = randomeTest,p1 = model2,p2 = model)
    end
end

# randomeTest

finishedGames = filter(row-> row.move.colour == :gameOver,randomeTest)

finishedGames.p1_score = getScore.(finishedGames.gameState,1)
finishedGames.p2_score = getScore.(finishedGames.gameState,2)

finishedGames.player1Win = finishedGames.p1_score .> finishedGames.p2_score
finishedGames.player1Draw = finishedGames.p1_score .== finishedGames.p2_score

sum(finishedGames.player1Win)/100
sum(finishedGames.player1Draw)/100
mean(finishedGames.p1_score)
mean(finishedGames.p2_score)

println("Player 1 wins $(sum(finishedGames.player1Win)/100) of the time")


g = randomeTest.gameState[2]
p = g.playerTurn

playerMoves(g,p)
allMoves = pickMove(g,p,model=model,all=true)
pickMove(g,p,model=model2)
dfAll = DataFrame(move=allMoves[1],pred = allMoves[2])
sort!(dfAll,:pred)
# dfAll.scorePred = returnScore.(dfAll.pred)






Hdims = 100
inDims
model = Chain(
    # Encoder layer
    Dense(inDims, Hdims),
    Dense(Hdims, Hdims),
    Dense(Hdims, 10),
    # Dense(Hdims, Hdims),
    # Dense(Hdims, Hdims),
    # Dense(Hdims, Hdims),
    # Dense(Hdims, Hdims),
    # Dense(Hdims, Hdims),
    # Dense(Hdims, Hdims),
    Dense(10, 1)
) |> device





function trainModel(model,n;
    batchSize = 64,
    epochs = 5,
    learningRate = 0.01,
    games = 1000

    )

    # randomGameData = DataFrame(gameState = Game[], move = PlayerMove[])
    # @info "Running Random Games"
    # @showprogress for i in 1:1000
    #     game = initGame(players = 2);
    #     gameLive = false
    #     while !gameLive && game.rounds < 50
    #         gameLive = runRound(game = game,game_df = randomGameData)
    #     end
    # end

    # randomdf = transformData(randomGameData)
    # filter!(row-> row.playerScoreIncrease > 0,randomdf) # take only the games that have a score increase
    
    # @show size(randomdf,1) / size(randomGameData,1)
    
    # inData = hcat(randomdf.vec...)
    # inTarget = Float32.(hcat(transformScore.(randomdf.playerScoreIncrease))')

    # # and now we want to train the model
    # loader = Flux.DataLoader((inData, inTarget), batchsize=1024, shuffle=true)
    # optim = Flux.setup(Flux.Adam(0.01), model)
    # # train the first bit
    # loss_values = Float64[]

    # @info "Training Model on random games"
    # @showprogress for i in 1:10
    #     # for (x, target) in zip(X, y)
        
    #     for xy_cpu in loader
    #         x, y = xy_cpu |> device
    #         val, grads = Flux.withgradient(model) do m
    #             y_hat = m(x)
    #             Flux.mse(y_hat, y)
    #             # Flux.logitbinarycrossentropy(y_hat, y)
    #         end
    #         Flux.update!(optim, model, grads[1])
    #         push!(loss_values, val)
    #     end
    # end
    # plotLoss = plot(loss_values, title="Training Loss on Random Games", xlabel="Iteration", ylabel="Loss" ,legend = false, )
    # display(plotLoss)

    # Data = zeros(Int64,(inDims,0))
    # Target = zeros(Float32,(1,0))

    loss_values = Float64[]
    dfAll = DataFrame()

    for i in 1:n

        @info "Running interation $i"

        # take the model and run it against itself
        raw = DataFrame(gameState = Game[], move = PlayerMove[])
        @info "Running Games with model"
        @showprogress  for i in 1:games
            game = initGame(players = 2);

            gameLive = false
            while !gameLive && game.rounds < 50
                gameLive = runRound(game = game,game_df = raw,p1 = model,p2 = model)
            end
        end

        df = transformData(raw)
        filter!(row-> row.playerScoreIncrease != 0,df) # take only the games that have a score change

        append!(dfAll,df)
        
        games2Keep = size(filter(row-> row.playerScoreIncrease > 0,df),1) / size(raw,1)
        println("Keeping $games2Keep of the games")

        inData = hcat(dfAll.vec...)
        inTarget = Float32.(hcat(transformScore.(dfAll.playerScoreIncrease))')

        # Target = hcat(Target,inTarget)
        # Data = hcat(Data,inData)

        loader = Flux.DataLoader((inData, inTarget), batchsize=batchSize, shuffle=true)
        optim = Flux.setup(Flux.Adam(learningRate), model)

        @showprogress for i in 1:epochs
            # for (x, target) in zip(X, y)
            
            for xy_cpu in loader
                x, y = xy_cpu |> device
                val, grads = Flux.withgradient(model) do m
                    y_hat = m(x)
                    Flux.mse(y_hat, y)
                    # Flux.logitbinarycrossentropy(y_hat, y)
                end
                Flux.update!(optim, model, grads[1])
                push!(loss_values, val)
            end
        end

        plotLoss = plot(loss_values, title="Training Loss at n = $i", xlabel="Iteration", ylabel="Loss" ,legend = false, )
        display(plotLoss)

    end

    return model

end

trainModel(model,5; 
    batchSize = 64,
    epochs = 5,
    learningRate = 0.01,
    games = 1000
    )

g = initGame(players = 2);
p = g.playerTurn

# playerMoves(g,p)
allMoves = pickMove(g,p,model=model,all=true)
pickMove(g,p,model=model)

g.islands.islands


raw = DataFrame(gameState = Game[], move = PlayerMove[])


game = initGame(players = 2);
gameLive = false
while !gameLive && game.rounds < 50
    gameLive = runRound(game = game,game_df = raw,p1 = model,p2 = model)
end

raw


getShortTermEffect(raw.gameState[10],raw.move[10])



transformData(raw)

game.boards[1].mosaic.grid
game.boards[1].score
game.boards[2].mosaic.grid
Ga
game.gameID
game.rounds

game.boards[1].triangle.rows
game.boards[1].discard
game.pool

raw.ID = getfield.(raw.gameState,:gameID)


g2 = filter(row-> row.ID == game.gameID,raw).gameState[end]
m2 = filter(row-> row.ID == game.gameID,raw).move[end]


g2.islands.islands
g2.pool
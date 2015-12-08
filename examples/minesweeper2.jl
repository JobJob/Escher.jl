using Compat # for Nullable
using Colors
using Lazy

#### Model ####

@defonce immutable Board{lost}
    uncovered::AbstractMatrix
    mines::AbstractMatrix
    squaresleft::Int64
end

function newboard(m, n, minefraction=0.2)
    mines = rand(m,n) .< minefraction
    Board{false}(fill(-1, (m,n)),mines,n*m-sum(mines))
end

function mines_around(board, i, j)
    m, n = size(board.mines)

    a = max(1, i-1)
    b = min(i+1, m)
    c = max(1, j-1)
    d = min(j+1, n)

    sum(board.mines[a:b, c:d])
end

### Update ###

next(board::Board{true}, move) = board
function next(board, move)
    i, j = move
    if board.mines[i, j]
        return Board{true}(board.uncovered, board.mines, board.squaresleft) # Game over
    else
        uncovered = copy(board.uncovered)
        if uncovered[i, j] == -1
            uncovered[i, j] = mines_around(board, i, j)
            return Board{false}(uncovered, board.mines, board.squaresleft-1)
        else
            return Board{false}(uncovered, board.mines, board.squaresleft)
        end
    end
end

moves_signal = Input((0, 0))
initial_board_signal = Input{Board}(newboard(10, 10))
board_signal = flatten(
    lift(initial_board_signal) do b
        foldl(next, b, moves_signal; typ=Board)
    end
)

### View ###


colors = ["#fff", colormap("reds", 7)]

box(content, color) =
    inset(Escher.middle,
        fillcolor(color, size(4em, 4em, empty)),
        Escher.fontsize(2em, content)) |> paper(1) |> Escher.pad(0.2em)

number(x) = box(x < 0 ? "" : string(x) |> fontweight(800), colors[x+2])
mine = box(icon("report"), "#e58")
block(board::Board{true}, i, j) =
    board.mines[i, j] ? mine :
        number(board.uncovered[i, j])

block(board, i, j) =
     constant((i, j), clickable(number(board.uncovered[i, j]))) >>> moves_signal

gameover = vbox(
        title(2, "Game Over!") |> Escher.pad(1em),
        addinterpreter(_ -> newboard(10, 10), button("Start again")) >>> initial_board_signal
    ) |> Escher.pad(1em) |> fillcolor("white")

gamewon = vbox(
        title(2, "Game Won!") |> Escher.pad(1em),
        addinterpreter(_ -> newboard(10, 10), button("Start again")) >>> initial_board_signal
    ) |> Escher.pad(1em) |> fillcolor("white")

function showboard{lost}(board::Board{lost})
    m, n = size(board.mines)
    b = hbox([vbox([block(board, i, j) for j in 1:m]) for i in 1:n])
    if lost
        inset(Escher.middle, b, gameover)
    else
       board.squaresleft > 0 ? b : inset(Escher.middle, b, gamewon)
   end
end

function main(window)
    push!(window.assets, "widgets")

    vbox(
       vskip(2em),
       title(3, "minesweeper"),
       vskip(2em),
       consume(showboard, board_signal, typ=Tile),
    ) |> packacross(center)
end

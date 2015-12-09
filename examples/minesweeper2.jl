using Compat # for Nullable
using Colors
using Lazy

#### Model ####

@defonce immutable Board{lost}
    uncovered::AbstractMatrix
    mines::AbstractMatrix
    squaresleft::Int64
end

Base.size(b::Board) = size(b.mines)

const BLANK = -1
const BLANKFLAG = -2

function newboard(m, n, minefraction=0.05)
    mines = rand(m,n) .< minefraction
    Board{false}(fill(BLANK, (m,n)), mines, n*m-sum(mines))
end

function squares_around(board, i, j)
    m, n = size(board)

    a = max(1, i-1)
    b = min(i+1, m)
    c = max(1, j-1)
    d = min(j+1, n)

    return (a,b,c,d)
end

function clear_square!(board, uncovered, i, j)
    ncleared = 0
    if uncovered[i,j] < 0
        a,b,c,d = squares_around(board,i,j)
        uncovered[i,j] = sum(board.mines[a:b, c:d])
        if uncovered[i,j] == 0
            for row = a:b, col = c:d
                ncleared += clear_square!(board, uncovered, row, col)
            end
        end
        ncleared += 1
    end
    ncleared
end

### Update ###

next(board::Board{true}, move) = board

toggleflag(number) = number == BLANK ? BLANKFLAG : number == BLANKFLAG ? BLANK : number

function next(board, move)
    i, j, clickinfo = move
    if clickinfo == Escher.RightButton()
        uncovered = copy(board.uncovered)
        uncovered[i,j] = toggleflag(uncovered[i,j])
        return Board{false}(uncovered, board.mines, board.squaresleft)
    else # Escher.LeftButton() was pressed
        if board.mines[i, j]
            return Board{true}(board.uncovered, board.mines, board.squaresleft) # Game over
        else
            uncovered = copy(board.uncovered)
            ncleared = clear_square!(board, uncovered, i, j)
            return Board{false}(uncovered, board.mines, board.squaresleft-ncleared)
        end
    end
end

moves_signal = Input{Tuple{Int,Int,Escher.MouseButton}}((0,0,Escher.LeftButton()))
initial_board_signal = Input{Board}(newboard(10, 10))
board_signal = lift(initial_board_signal) do b
    foldl(next, b, moves_signal; typ=Board)
end |> flatten

### View ###

colors = ["#fff"; colormap("reds", 9)]

box(content, color) =
    inset(Escher.middle,
        fillcolor(color, size(4em, 4em, empty)),
        Escher.fontsize(2em, content)) |> paper(1) |> Escher.pad(0.2em)

isflagged(x) = x == BLANKFLAG
getcolor(x) = isflagged(x) ? colors[BLANK+2] : colors[x+2]

number(x) = box(x < 0 ? isflagged(x) ? icon("flag") : "" : string(x) |> fontweight(800), getcolor(x))
mine = box(icon("report"), "#e58")

block(board::Board{true}, i, j) =
    board.mines[i, j] ? mine : number(board.uncovered[i, j])

block(board::Board{false}, i, j) =
    addinterpreter(clicktype -> (i,j,clicktype),
                   clickable([leftbutton, rightbutton],
                             number(board.uncovered[i, j]))) >>> moves_signal

gameover(message) = vbox(
        title(2, message) |> Escher.pad(1em),
        addinterpreter(_ -> newboard(10, 10), button("Start again")) >>> initial_board_signal
    ) |> Escher.pad(1em) |> fillcolor("white")

function showboard{lost}(board::Board{lost})
    m, n = size(board.mines)
    b = hbox([vbox([block(board, i, j) for j in 1:m]) for i in 1:n])
    if lost || board.squaresleft <= 0 #lost or won
        inset(Escher.middle, b, gameover(lost ? "Game Over!": "You Won!"))
    else
        b
    end
end

function main(window)
    push!(window.assets, "widgets")
    push!(window.assets, "icons")

    vbox(
       vskip(2em),
       title(3, "minesweeper2"),
       vskip(2em),
       consume(showboard, board_signal, typ=Tile),
       vskip(2em)
    ) |> packacross(center)
end

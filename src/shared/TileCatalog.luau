-- A tile's style and its two collision masks are independent.
return {
    ["."] = {style="empty"},
    P = {style="wall", body=true, shot=true},
    D = {style="platform", body=true},
    L = {style="shield", shot=true},
    G = {style="launch", launch=true, top=0.82},
    Y = {style="beacon"},
    M = {style="marker"},
}

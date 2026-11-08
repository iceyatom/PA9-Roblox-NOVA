"""Run pure game-logic cases with the official Luau CLI (not an engine/UI test).

Usage: python tools/check_logic.py --luau /path/to/luau
Only the module tree, Vector2, and seeded map selection are emulated.
"""
import argparse
import json
import subprocess
from pathlib import Path
import tempfile

ROOT = Path(__file__).resolve().parents[1]
CASES = ("Progression", "ProgressionStore", "MatchRewards", "Match", "Lobbies",
         "Movement", "Combat", "Practice", "MapRotation")
PRELUDE = r'''
local modules,cache,nodes={},{},{}
local function node(path,class)
    if nodes[path] then return nodes[path] end
    local parentPath,name=path:match("^(.*)%.([^%.]+)$")
    local n={Name=name or path,ClassName=class or "Folder",children={},attributes={}}
    nodes[path]=n
    if parentPath then
        n.Parent=node(parentPath)
        n.Parent[n.Name]=n
        table.insert(n.Parent.children,n)
    end
    function n:WaitForChild(key) return assert(self[key],key) end
    function n:FindFirstChild(key) return self[key] end
    function n:GetChildren() return self.children end
    function n:IsA(kind) return self.ClassName==kind end
    function n:GetAttribute(key) return self.attributes[key] end
    function n:SetAttribute(key,value) self.attributes[key]=value end
    return n
end
local game=node("game")
local require
require=function(n)
    assert(modules[n],"Module unavailable: "..tostring(n and n.Name))
    if cache[n]==nil then cache[n]=modules[n]() end
    return cache[n]
end
local vec={}
vec.__index=vec
vec.__eq=function(a,b) return a.X==b.X and a.Y==b.Y end
local Vector2={new=function(x,y) return setmetatable({X=x,Y=y},vec) end}
Vector2.xAxis=Vector2.new(1,0)
Vector2.yAxis=Vector2.new(0,1)
vec.__unm=function(a) return Vector2.new(-a.X,-a.Y) end
vec.__sub=function(a,b) return Vector2.new(a.X-b.X,a.Y-b.Y) end
vec.__add=function(a,b) return Vector2.new(a.X+b.X,a.Y+b.Y) end
vec.__mul=function(a,b) return Vector2.new(a.X*b,a.Y*b) end
function vec:Dot(b) return self.X*b.X+self.Y*b.Y end
local builtinTypeof=typeof
local typeof=function(value) return getmetatable(value)==vec and "Vector2" or builtinTypeof(value) end
local Random={new=function()
    return {NextInteger=function(_,a,b) return math.random(a,b) end}
end}
local warn=print
math.randomseed(1234)
'''


def run(executable):
    sources = []
    for folder, parent in (("src/shared", "game.ReplicatedStorage.NOVA"),
                           ("src/shared/maps", "game.ReplicatedStorage.NOVA.Maps"),
                           ("src/server", "game.ServerScriptService.NOVA"),
                           ("tests/unit", "game.ServerStorage.NOVAUnitTest"),
                           ("tests/cases", "game.ServerStorage.NOVAUnitTest.Cases")):
        for file in sorted((ROOT / folder).glob("*.luau")):
            if ".server." not in file.name:
                sources.append((parent + "." + file.name.split(".")[0], file))
    code = [PRELUDE]
    for path, _ in sources:
        code.append(f'node({json.dumps(path)},"ModuleScript")\n')
    for path, file in sources:
        code.append(f'modules[nodes[{json.dumps(path)}]]=function()\nlocal script=nodes[{json.dumps(path)}]\n')
        code.append(file.read_text(encoding="utf-8") + "\nend\n")
    code.append('local passed,failed=0,0\nlocal t={}\nfunction t.test(name,fn)\n'
                'local ok,err=pcall(fn)\nif ok then passed+=1; print("PASS",name)\n'
                'else failed+=1; print("FAIL",name,err) end\nend\n')
    for case in CASES:
        code.append(f'require(game.ServerStorage.NOVAUnitTest.Cases.{case}_Test)(t)\n')
    code.append('print(("%d passed; %d failed"):format(passed,failed))\nassert(failed==0,"Logic tests failed")\n')
    with tempfile.TemporaryDirectory(prefix="nova-logic-") as directory:
        script = Path(directory) / "logic.luau"
        script.write_text("".join(code), encoding="utf-8")
        subprocess.run([executable, str(script)], check=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--luau", required=True)
    run(parser.parse_args().luau)

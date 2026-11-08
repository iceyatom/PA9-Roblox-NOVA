"""Rebuild NOVA.rbxlx or emit an idempotent Studio MCP edit from the same sources."""
import argparse
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
MAPPING = {
    "src/shared": "ReplicatedStorage/NOVA",
    "src/shared/maps": "ReplicatedStorage/NOVA/Maps",
    "src/server": "ServerScriptService/NOVA",
    "src/client": "StarterPlayer/StarterPlayerScripts/NOVA",
    "tests/unit": "ServerStorage/NOVAUnitTest",
    "tests/cases": "ServerStorage/NOVAUnitTest/Cases",
    "tests/integration": "ServerStorage/NOVATesting",
}

def scripts():
    for folder, target in MAPPING.items():
        for file in sorted((ROOT / folder).glob("*.luau")):
            name = file.name.split(".")[0]
            kind = "LocalScript" if file.name.endswith(".client.luau") else "Script" if file.name.endswith(".server.luau") else "ModuleScript"
            yield target.split("/") + [name], kind, file.read_text(encoding="utf-8")

def literal(value):
    delimiter = "="
    while "]" + delimiter + "]" in value:
        delimiter += "="
    return "[" + delimiter + "[" + value + "]" + delimiter + "]"

def emit_sync(service):
    print("""local editor=game:GetService("ScriptEditorService")
local function ensure(parent,name,class)
    local object=parent:FindFirstChild(name)
    if object then
        assert(object.ClassName==class and object:GetAttribute("NOVAOwned"),"Conflicting instance: "..object:GetFullName())
    else
        object=Instance.new(class)
        object.Name=name
        object:SetAttribute("NOVAOwned",true)
        object.Parent=parent
    end
    return object
end""")
    for path, kind, source in scripts():
        if service and path[0] != service:
            continue
        print("do local parent=game:GetService(" + literal(path[0]) + ")")
        for folder in path[1:-1]:
            if folder == "StarterPlayerScripts":
                print("parent=parent.StarterPlayerScripts")
            else:
                print("parent=ensure(parent," + literal(folder) + ",'Folder')")
        print("local node=ensure(parent," + literal(path[-1]) + "," + literal(kind) + ")")
        print("local source=" + literal(source))
        print("editor:UpdateSourceAsync(node,function() return source end) end")
    print('return "NOVA sources synchronized"')

def build():
    root = ET.Element("roblox", version="4")
    nodes = {(): root}
    def item(parent, name, kind):
        obj = ET.SubElement(parent,"Item",{"class":kind})
        props = ET.SubElement(obj,"Properties")
        ET.SubElement(props,"string",name="Name").text = name
        return obj
    for key,kind,src in scripts():
        for i in range(1,len(key)):
            prefix = tuple(key[:i])
            if prefix not in nodes:
                name = key[i-1]
                cls = name if i == 1 or name == "StarterPlayerScripts" else "Folder"
                nodes[prefix] = item(nodes[prefix[:-1]],name,cls)
        obj = item(nodes[tuple(key[:-1])],key[-1],kind)
        ET.SubElement(obj.find("Properties"),"ProtectedString",name="Source").text = src
    # Preserve ownership when a generated place is opened and synchronized again.
    import base64, struct
    attr = base64.b64encode(struct.pack("<II",1,9) + b"NOVAOwned" + bytes([3,1])).decode()
    for node in root.iter("Item"):
        if node.get("class") in ("Script","LocalScript","ModuleScript","Folder"):
            ET.SubElement(node.find("Properties"),"BinaryString",name="AttributesSerialize").text = attr
    destination = ROOT / "build" / "NOVA.rbxlx"
    destination.parent.mkdir(exist_ok=True)
    ET.ElementTree(root).write(destination,encoding="utf-8",xml_declaration=True)
    print(destination)
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sync", action="store_true")
    parser.add_argument("--service", choices=sorted({p.split("/")[0] for p in MAPPING.values()}))
    args = parser.parse_args()
    emit_sync(args.service) if args.sync else build()

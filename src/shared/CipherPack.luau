local items={}
for _,variant in {{"green","Green","36ff42"},{"purple","Purple","bc63ff"},{"red","Red","ff394f"},{"blue","Blue","329cff"}} do
    for _,piece in {{"skin","skins","Shell","A square black circuit shell with a rotating wireframe core, scanning light and travelling signals."},
        {"bullet","bullets","Pulse","A circular black signal core with a rotating wireframe scanner and luminous perimeter."},
        {"tracer","tracers","Data Stream","Parallel data rails carry moving packet brackets, signal blocks and digital sparks."},
        {"card","backgrounds","Terminal","Circuit routes and flowing binary data frame a quiet black player nameplate."}} do
        local item={id=piece[1].."_cipher_"..variant[1],category=piece[2],name="Cipher "..variant[2].." "..piece[3],rarity="Epic",color=variant[3],visual="cipher",variant=variant[1],setName="Cipher "..variant[2],description=piece[4]}
        if piece[2]=="tracers" then item.length=3.5;item.lifetime=.35;item.frames=1 end
        table.insert(items,item)
    end
end
return items

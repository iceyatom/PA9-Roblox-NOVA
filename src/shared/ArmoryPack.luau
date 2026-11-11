-- Five original sets. theme selects the atlas/sprite group and motion style in ArmoryVisuals.
local sets={
    {"aetherwing","Aetherwing","35f2ff",
        {"skin_aetherwing_crest","Aetherwing Crest","A square teal crest with ice-white wing blades, gold spines and a breathing cyan core ringed by a turning gold halo."},
        {"bullet_aether_orb","Aether Orb","A circular teal lens with three rotating ice blades around a pulsing cyan orb."},
        {"tracer_featherfall","Featherfall Wake","Three flowing cyan and gold ribbons shed drifting ice feathers that tumble and fade behind the shot."},
        {"card_skyward_wings","Skyward Wings","Ice and gold wings fan in from both edges of a deep teal sky, with drifting feathers framing your nameplate."}},
    {"hexwyrm","Hexwyrm","2bffc1",
        {"skin_hexwyrm_plate","Hexwyrm Plate","A square midnight plate crossed by a rippling band of glass hex scales, slate corner armor and a mint slit eye."},
        {"bullet_scale_core","Scale Core","A circular cluster of seven breathing hex scales inside a rotating mint tick ring."},
        {"tracer_honeycomb_trail","Honeycomb Trail","Twin mint filaments leave flickering hex cells that spread into three lanes as they fade."},
        {"card_wyrm_hive","Wyrm Hive","Mint honeycomb scales brighten toward both edges of a midnight slab, with floating hex cells at the sides."}},
    {"pawpop","Pawpop","ff6fb5",
        {"skin_pawpop_charm","Pawpop Charm","A square candy-pink charm with a bouncing paw print, wobbling hearts, twirling yellow stars and twinkling sparkles."},
        {"bullet_paw_button","Paw Button","A circular pink button with a bouncing paw print and a rotating ring of hearts and stars."},
        {"tracer_pawstep_trail","Pawstep Trail","Soft pink and lilac ribbons with a trail of alternating paw prints padding along behind the shot."},
        {"card_candy_paws","Candy Paws","Paw prints, hearts and stars scatter across both sides of a candy-pink card around a clear nameplate."}},
    {"goldcoil","Goldcoil","ffd61f",
        {"skin_goldcoil_reactor","Goldcoil Reactor","A square black chassis with gold corner armor, hazard stripes, marching energy chevrons and a rotating triangle reticle."},
        {"bullet_arc_cell","Arc Cell","A circular gold-rimmed cell with a rotating reactor triangle and white-hot arcs."},
        {"tracer_volt_march","Volt March","Three straight energy rails with chevrons marching forward toward the shot."},
        {"card_gilded_bulkhead","Gilded Bulkhead","Gold hazard bulkheads and inward chevrons flank a black slab lit by white-hot rails."}},
    {"shardbound","Shardbound","9638ff",
        {"skin_shardbound_eye","Shardbound Eye","A square void plate with radiating steel crystal shards, a rotating chain and a breathing amethyst eye."},
        {"bullet_bound_gem","Bound Gem","A circular ink lens with an amethyst gem, crystal shards and a rotating chain ring."},
        {"tracer_chain_lash","Chain Lash","A taut violet filament strung with sliding chain links and amethyst charms."},
        {"card_amethyst_vault","Amethyst Vault","Crystal shard walls and hanging chains with amethyst pendants frame a quiet void nameplate."}},
}
local categories={"skins","bullets","tracers","backgrounds"}
local items={}
for _,set in sets do
    for slot,category in categories do
        local piece=set[slot+3]
        local item={id=piece[1],category=category,name=piece[2],rarity="Cosmic",color=set[3],visual="armory",theme=set[1],setName=set[2],description=piece[3]}
        if category=="tracers" then item.length=4.4;item.lifetime=.44;item.frames=1 end
        table.insert(items,item)
    end
end
return items

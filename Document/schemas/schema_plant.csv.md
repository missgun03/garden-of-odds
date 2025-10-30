# schema_plant.csv.md
name,str (uniq)
role,enum[Energy,Sap,Support,Control,Spore,Meta,Burst]
p_base,int>=1
l_rule,str (human-readable)
l_min,float>=1.0
l_max,float>=l_min
entropy_on_event,float>=0
tags,str (csv)
notes,str

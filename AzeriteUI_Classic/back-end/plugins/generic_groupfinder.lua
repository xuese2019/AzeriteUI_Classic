
-- placeholder
do 
	return 
end 

-- Register it with compatible libraries
for _,Lib in ipairs({ (Wheel("LibUnitFrame", true)), (Wheel("LibNamePlate", true)), (Wheel("LibMinimap", true)) }) do 
	Lib:RegisterElement("GroupFinder", Enable, Disable, Proxy, 1)
end 

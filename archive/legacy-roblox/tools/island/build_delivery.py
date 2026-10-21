"""Build a reviewable source-only ZIP from the two integration worktrees."""
from pathlib import Path
import subprocess,zipfile,json,hashlib
R=Path(__file__).resolve().parents[2];C=R.parent/'island-cpp';D=R/'dist';D.mkdir(exist_ok=True)
shared=['ReferenceIslandGenerator','IslandConfig','IslandPlantMigration','PlantSurfaceExport','PlantRenderer','PlantConfig','PlantProtocol','AgentPresentationConfig','AgentModelFactory']
entries={name:('ModuleScript','src/shared/'+name+'.lua') for name in shared}
entries.update({name:('LocalScript','src/client/Controllers/'+name+'.client.lua') for name in ['LiveController','AgentDetailController','PlantController']})
entries['Plants']=('Script','src/server/Plants.server.lua')
entries['IslandInstall']=('ModuleScript','tools/IslandPackageInstall.lua')
entries['PlantInstall']=('ModuleScript','tools/plants/PlantInstall.lua')
entries['AgentInstall']=('ModuleScript','tools/agents/AgentKitInstall.lua')
patch='''-- Stop Play, copy repository replacements and sync Rojo BEFORE running this.
assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
local sources={
'''+''.join('["'+name+'"]={class="'+cls+'",source=[====[\n'+(R/f).read_text()+']====]},\n' for name,(cls,f) in entries.items())+'''}
local pending={}
local function queue(target,source)
 if target.Source~=source then table.insert(pending,{target=target,source=source,original=target.Source}) end
end
local installers={ReferenceIslandPackage="IslandInstall",PlantLifePackage="PlantInstall",AgentModelPackage="AgentInstall"}
for _,service in {"ReplicatedStorage","ServerStorage","ServerScriptService","StarterPlayer"} do
 for _,item in game:GetService(service):GetDescendants() do
  if item:IsA("LuaSourceContainer") then
   local name=item.Name:gsub("%.lua$",""):gsub("%.luau$",""):gsub("%.client$",""):gsub("%.server$","")
   local key=name
   if name=="Install" and item.Parent then key=installers[item.Parent.Name] end
   local source=key and sources[key]
   local ancestor=item.Parent;local allowed=false
   while ancestor do
    if ancestor.Name=="Shared" or ancestor.Name=="Controllers" or ancestor.Name=="Server" or installers[ancestor.Name] then allowed=true;break end
    ancestor=ancestor.Parent
   end
   if source and allowed and item.ClassName==source.class then queue(item,source.source) end
   if service=="StarterPlayer" and (name=="Bootstrap" or name=="ClientBootstrap") then
    -- Correct the exact screenshot warning; preserve every other startup action.
    local text=item.Source:gsub("(\\n[ \\t]*)player%%.Name([ \\t]*,?[ \\t]*\\n)","%1tostring(player.Name)%2")
    queue(item,text)
   end
  end
 end
end
local backup=Instance.new("Folder");backup.Name="IslandIntegrationBackup_"..game:GetService("HttpService"):GenerateGUID(false);backup.Parent=game:GetService("ServerStorage")
for i,change in pending do
 local saved=Instance.new("StringValue");saved.Name=tostring(i).."_"..change.target.Name;saved.Value=change.original;saved:SetAttribute("Path",change.target:GetFullName());saved.Parent=backup
 local target=Instance.new("ObjectValue");target.Name="Target";target.Value=change.target;target.Parent=saved
end
local ok,err=pcall(function()for _,change in pending do change.target.Source=change.source end end)
if not ok then
 for _,change in pending do pcall(function()change.target.Source=change.original end) end
 error(tostring(err))
end
local island=workspace:FindFirstChild("CI_ReferenceIsland")
local woodland=island and island:FindFirstChild("Woodland")
if woodland and woodland:IsA("Folder") then woodland.Parent=backup;island:SetAttribute("Trees",0);island:SetAttribute("LivingPlantWorld",true) end
print("[Island] Updated "..#pending.." scripts. Backups/old woodland: "..backup:GetFullName()..". Save the place. Do NOT regenerate terrain.")
'''
# Lua patterns escape literal periods with a single %, not Python's doubled form.
patch=patch.replace('player%%.Name','player%.Name')
p=D/'ApplyIslandIntegration.lua';p.write_text(patch)
files=[]
for root,label in [(C,'cpp'),(R,'roblox')]:
 changed=subprocess.check_output(['git','diff','--name-only','origin/main'],cwd=root,text=True).splitlines()
 new=subprocess.check_output(['git','ls-files','--others','--exclude-standard'],cwd=root,text=True).splitlines()
 for f in sorted(set(changed+new)):
  if f.startswith(('dist/','build','__pycache__')) or '__pycache__' in f:continue
  if (root/f).is_file():files.append((root/f,label+'/'+f))
# Include the known-good renderer/controller templates even when unchanged in Git.
for _,f in entries.values():
 if not any(name=='roblox/'+f for _,name in files):files.append((R/f,'roblox/'+f))
manifest=[]
with zipfile.ZipFile(D/'Island_Unified_Ecosystem.zip','w',zipfile.ZIP_DEFLATED) as z:
 for path,name in files:
  z.write(path,name);manifest.append({'path':name,'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
 z.write(p,p.name)
 for name in ['START_HERE.md','ARCHITECTURE_AND_LIMITS.md','VALIDATION.md']:
  z.write(R/'docs/island'/name,name)
 z.writestr('FILE_MANIFEST.json',json.dumps(manifest,indent=2))
print('Packaged',len(files),'source/document files:',D/'Island_Unified_Ecosystem.zip')

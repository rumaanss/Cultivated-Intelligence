param([string]$Runtime='runtime/stage3',[string]$Output='',[int]$DayEndTick=0)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$dir=if([IO.Path]::IsPathRooted($Runtime)){$Runtime}else{Join-Path $root $Runtime}
$file=if($DayEndTick -gt 0){Join-Path $dir "food-days/$DayEndTick.json"}else{Join-Path $dir 'stage3-food-current.json'}
if(!(Test-Path $file)){throw "No food report at $file. Start Stage 3 first; completed days are saved every 600 ticks."}
$b=Get-Content -Raw $file|ConvertFrom-Json
if($b.schema -ne 1 -or $b.biologicalDays -le 0){throw 'No positive observation interval yet.'}
$names=@('Suspended producers','Attached producers','Bacteria','Bacterial grazers','Microalgal grazers','Algal habitat')
$summary=for($g=0;$g -lt 6;$g++){
 $open=0.;$close=0.;$flux=New-Object 'double[]' 10
 foreach($r in $b.rows){if([int]$r[2] -eq $g){$open+=$r[3][0];$close+=$r[4][0];for($k=0;$k -lt 10;$k++){$flux[$k]+=$r[5][$k][0]}}}
 [pscustomobject]@{Guild=$names[$g];StartTick=$b.startTick;EndTick=$b.endTick;Days=$b.biologicalDays;OpeningC=$open;RemainingC=$close;NetCPerDay=($close-$open)/$b.biologicalDays;FixationCPerDay=$flux[0]/$b.biologicalDays;NewTissueCPerDay=$flux[9]/$b.biologicalDays;NetBiologicalProductionCPerDay=($flux[0]+$flux[6]-$flux[3]-$flux[2]-$flux[7])/$b.biologicalDays;IngestedCPerDay=$flux[6]/$b.biologicalDays;RespiredCPerDay=$flux[3]/$b.biologicalDays;GrazedCPerDay=$flux[5]/$b.biologicalDays;LitterCPerDay=$flux[4]/$b.biologicalDays;EgestedCPerDay=$flux[7]/$b.biologicalDays}
}
$summary|Format-Table Guild,NetBiologicalProductionCPerDay,RespiredCPerDay,IngestedCPerDay,RemainingC -AutoSize
Write-Host "Units: mmol C; one biological day = 600 ticks. Interval: $($b.startTick)-$($b.endTick)."
Write-Host 'New tissue is gross structural synthesis; remaining stock includes founders and reserves. Subtracting respiration again from stock would double count losses.'
if(!$Output){$Output=Join-Path $dir 'food-summary.csv'}elseif(![IO.Path]::IsPathRooted($Output)){$Output=Join-Path $root $Output}
$parent=Split-Path $Output -Parent;New-Item -ItemType Directory -Force $parent|Out-Null
$summary|Export-Csv -NoTypeInformation -Encoding UTF8 $Output
$local=foreach($h in $b.habitat){
 $offset=([int]$h[0]-1)*12+[int]$h[1]*6
 $production=New-Object 'double[]' 3;$grazed=0.;$litter=0.
 for($g=0;$g -lt 3;$g++){$r=$b.rows[$offset+$g];$f=$r[5];$production[$g]=($f[0][0]+$f[6][0]-$f[3][0]-$f[2][0]-$f[7][0])/$b.biologicalDays;$grazed+=$f[5][0]/$b.biologicalDays;$litter+=$f[4][0]/$b.biologicalDays}
 [pscustomobject]@{Patch=$h[0];Layer=$h[1];X=$h[2];Y=$h[3];Z=$h[4];AreaM2=$h[5];VolumeM3=$h[6];BacteriaReachableC=$h[8][0];MicroalgaeReachableC=$h[8][1];BacterialNetProductionCPerDay=$production[2];MicroalgalNetProductionCPerDay=$production[0]+$production[1];FoodGrazedCPerDay=$grazed;FoodLitterCPerDay=$litter;AlgalCanopy=$h[9]}
}
$local|Export-Csv -NoTypeInformation -Encoding UTF8 ([IO.Path]::ChangeExtension($Output,'access.csv'))
Write-Host "Saved $Output and its access.csv companion. Reachability is a same-cell estimate with attached-film shelter; actual ingestion includes encounter and handling limits."

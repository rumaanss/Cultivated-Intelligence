--!strict
-- Fixed memory, rolling measurements. Percentiles are calculated only on export.
local M={}
export type Window={values:{number},cursor:number,capacity:number}
function M.new(capacity:number):Window
 assert(capacity>=1 and capacity%1==0,"Invalid metric capacity")
 return {values={},cursor=0,capacity=capacity}
end
function M.push(window:Window,value:number)
 if value~=value or value<0 or value==math.huge then return end
 window.cursor=window.cursor%window.capacity+1
 window.values[window.cursor]=value
end
function M.summary(window:Window): (number?,number?,number?)
 if #window.values==0 then return nil,nil,nil end
 local values=table.clone(window.values);table.sort(values)
 local n=#values
 return values[math.ceil(n*.50)],values[math.ceil(n*.95)],values[math.ceil(n*.99)]
end
return M

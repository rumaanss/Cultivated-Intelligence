--!strict
-- Public snapshots; producers replace snapshots rather than allowing cross-controller writes.
export type InputSnapshot = {x: number,z: number,sprint: boolean,jump: boolean}
export type LookIntent = {up: Vector3,forward: Vector3,flat: Vector3,gaze: Vector3,
 viewUp: Vector3,pitch: number,yaw: number,mode: string}
export type MovementSnapshot = {up: Vector3,forward: Vector3,desiredTravel: Vector3,
 grounded: boolean,hit: RaycastResult?,velocity: Vector3,mode: string,
 inputX: number,inputZ: number,contact: {[string]: any}?}
export type GameplayAim = {origin: Vector3?,direction: Vector3,allowed: boolean,time: number}
export type SpawnSite = {position: Vector3,root: Vector3,up: Vector3,forward: Vector3}
return table.freeze({Version=2})

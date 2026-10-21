#pragma once
// Pre-optimization oracle for collision and shoreline recovery equivalence.
#include "cybernet/world/geometry.hpp"
namespace cybernet {
class GeometryWorldReference {
public:
    static constexpr float Skin = 0.0001F;
    static constexpr std::size_t MaxObjects = 128;
    explicit GeometryWorldReference(std::span<const GeometryObject> objects, float bodyRadius=0.25F, std::span<const Vec3> terrainPlanes={}, const Heightfield* field=nullptr, Vec3 bounds={100,100,60})
        : field_(field),bounds_(bounds),objects_(objects.begin(),objects.end()), radius_(bodyRadius), planes_(terrainPlanes.begin(),terrainPlanes.end()) {
        if(planes_.size()>8)throw std::invalid_argument("Too many terrain planes");
        for(auto q:planes_) {
            if(!finite(q)||std::abs(q.x)>3||std::abs(q.y)>3)throw std::invalid_argument("Invalid terrain plane");
            const float length=std::sqrt(1+q.x*q.x+q.y*q.y);
            for(float x:{0.0F,100.0F})for(float y:{0.0F,100.0F})if(q.x*x+q.y*y+q.z+radius_*length>=55)throw std::invalid_argument("Terrain too high");
            normals_.push_back(Vec3{-q.x/length,-q.y/length,1/length});
            offsets_.push_back(q.z/length);
        }
        if (!std::isfinite(radius_) || radius_<=0 || radius_>1 || objects_.size()>MaxObjects)
            throw std::invalid_argument("Invalid geometry limits");
        std::sort(objects_.begin(),objects_.end(),[](const auto& a,const auto& b){return a.id<b.id;});
        std::uint32_t previous=0;
        for(std::size_t i=0;i<objects_.size();++i) {
            const auto& o=objects_[i];
            if(o.id<=previous || !finite(o.center)||!finite(o.halfSize) ||
                o.halfSize.x<=0||o.halfSize.y<=0||o.halfSize.z<=0 ||
                (o.shape!=GeometryShape::Box && o.shape!=GeometryShape::Sphere) ||
                (o.shape==GeometryShape::Sphere && (o.halfSize.x!=o.halfSize.y||o.halfSize.x!=o.halfSize.z)))
                throw std::invalid_argument("Invalid geometry object");
            previous=o.id;
            const Vec3 lo=o.center-o.halfSize, hi=o.center+o.halfSize;
            if(lo.x<2*radius_||lo.y<2*radius_||lo.z<2*radius_||hi.x>bounds_.x-2*radius_||hi.y>bounds_.y-2*radius_||hi.z>bounds_.z-2*radius_)
                throw std::invalid_argument("Obstacle must leave body clearance at basin edges");
            for(int z=cell(lo.z,5,bounds_.z);z<=cell(hi.z,5,bounds_.z);++z)
             for(int y=cell(lo.y,9,bounds_.y);y<=cell(hi.y,9,bounds_.y);++y)
              for(int x=cell(lo.x,9,bounds_.x);x<=cell(hi.x,9,bounds_.x);++x)cells_[index(x,y,z)].push_back(i);
        }
    }
    [[nodiscard]] std::span<const Vec3> terrainPlanes() const noexcept { return planes_; }
    [[nodiscard]] float floorHeight(float x,float y,float padding=0) const noexcept {
        float z=field_?field_->floor(x,y,padding):padding;
        for(std::size_t i=0;i<planes_.size();++i)z=std::max(z,planes_[i].x*x+planes_[i].y*y+planes_[i].z+padding/normals_[i].z);
        return z;
    }
    [[nodiscard]] const Heightfield* heightfield()const noexcept{return field_;}
    [[nodiscard]] Vec3 bounds()const noexcept{return bounds_;}
    [[nodiscard]] float bodyRadius() const noexcept { return radius_; }
    [[nodiscard]] std::span<const GeometryObject> objects() const noexcept { return objects_; }
    [[nodiscard]] bool blocked(Vec3 a,Vec3 b,bool light=true,float padding=0,bool includeTerrain=true) const noexcept {
        if(!finite(a)||!finite(b)||!std::isfinite(padding)||padding<0)return true;
        float f=1;Vec3 n{};if(includeTerrain&&field_&&field_->sweep(a,b,padding,f,n))return true;
        Vec3 ta=a,tb=b;
        if(includeTerrain && !planes_.empty() && clipXY(ta,tb))
            for(std::size_t i=0;i<planes_.size();++i)if(dot(normals_[i],ta)-offsets_[i]<padding-0.00005F || dot(normals_[i],tb)-offsets_[i]<padding-0.00005F)return true;
        // Boolean visibility queries need neither nearest-hit sorting nor normals.
        // Most rays miss the small obstacle set; reject their bounds first.
        const Vec3 lo{std::min(a.x,b.x)-padding,std::min(a.y,b.y)-padding,std::min(a.z,b.z)-padding};
        const Vec3 hi{std::max(a.x,b.x)+padding,std::max(a.y,b.y)+padding,std::max(a.z,b.z)+padding};
        if(objects_.size()<=8) {
            for(const auto& o:objects_)if((light?o.opaque:o.solid)&&overlap(o,lo,hi)&&intersect(o,a,b,padding).hit)return true;
        } else {
            const auto candidates=query(a,b,padding);
            for(std::size_t i=0;i<objects_.size();++i)if(candidates[i]) {
                const auto& o=objects_[i];
                if((light?o.opaque:o.solid)&&overlap(o,lo,hi)&&intersect(o,a,b,padding).hit)return true;
            }
        }
        return false;
    }
    // Precondition: both centers belong to valid bodies in this world. The water
    // legacy plane region is convex. The full pond is not: include its
    // terrain in inter-body visibility and contact queries.
    [[nodiscard]] bool blockedBetweenBodies(Vec3 a,Vec3 b,bool light) const noexcept {
        return blocked(a,b,light,0,field_!=nullptr);
    }
    [[nodiscard]] GeometryHit sweep(Vec3 a,Vec3 b,float padding,bool light=false) const noexcept {
        GeometryHit best;
        if(!finite(a)||!finite(b)||!std::isfinite(padding)||padding<0) {best.hit=true;best.fraction=0;return best;}
        // In lake mode solve basin walls in the same contact loop as slopes.
        if((!planes_.empty()||field_) && !light) {
            const Vec3 ns[]={{1,0,0},{-1,0,0},{0,1,0},{0,-1,0},{0,0,1},{0,0,-1}};
            const float cs[]={padding,padding-bounds_.x,padding,padding-bounds_.y,padding,padding-bounds_.z};
            for(int i=0;i<6;++i) {
                const float da=dot(ns[i],a)-cs[i],db=dot(ns[i],b)-cs[i];
                if(db<0 && da>=0) {const float t=da/(da-db);if(!best.hit||t<best.fraction)best={true,t,ns[i],0};}
            }
        }
        if(field_){float f=best.fraction;Vec3 n{};if(field_->sweep(a,b,padding,f,n))best={true,f,n,0};}
        for(std::size_t i=0;i<planes_.size();++i) {
            const float da=dot(normals_[i],a)-offsets_[i]-padding,db=dot(normals_[i],b)-offsets_[i]-padding;
            if(da<0 || (db<0 && da>=0)) {
                const float t=da<0?0:da/(da-db);
                if(!best.hit||t<best.fraction)best={true,t,normals_[i],0};
            }
        }
        const auto candidates=query(a,b,padding);
        for(std::size_t i=0;i<objects_.size();++i) {
            if(!candidates[i])continue;
            const auto& o=objects_[i];if(light?!o.opaque:!o.solid)continue;
            const auto h=intersect(o,a,b,padding);
            if(h.hit && (!best.hit||h.fraction<best.fraction||(h.fraction==best.fraction&&h.id<best.id)))best=h;
        }
        return best;
    }
    // Resolve founders/newborns deterministically; never consumes RNG.
    [[nodiscard]] bool projectOutside(Vec3& p) const noexcept {
        const float skin=field_?0.001F:Skin;
        if(!finite(p))return false;
        clampBody(p);
        if(!planes_.empty()||field_)p.z=std::max(p.z,floorHeight(p.x,p.y,radius_)+skin);
        if(field_&&p.z>bounds_.z-radius_){
            float distance=std::numeric_limits<float>::infinity();Vec3 nearest{};
            for(unsigned y=0;y+1<field_->ny;++y)for(unsigned x=0;x+1<field_->nx;++x){
                Vec3 q{(x+.5F)*field_->cell,(y+.5F)*field_->cell,0};
                q.z=std::max(radius_,field_->floor(q.x,q.y,radius_)+skin);
                const float d=(q.x-p.x)*(q.x-p.x)+(q.y-p.y)*(q.y-p.y);
                if(d<distance&&clear(q)){distance=d;nearest=q;}
            }
            if(!std::isfinite(distance))return false;
            p=nearest;
        }
        for(int pass=0;pass<16;++pass) {
            bool changed=false;
            for(const auto& o:objects_) {
                if(!o.solid||!inside(o,p,radius_))continue;
                changed=true;
                if(!planes_.empty()||field_) {
                    // Vertical escape is guaranteed by the scene validation contract.
                    p.z=o.center.z+o.halfSize.z+radius_+skin;
                } else if(o.shape==GeometryShape::Sphere) {
                    Vec3 direction=(p-o.center).normalized();
                    if(direction.lengthSquared()<0.5F)direction={1,0,0};
                    p=o.center+direction*(o.halfSize.x+radius_+skin);
                } else {
                    const Vec3 e=o.halfSize+Vec3{radius_,radius_,radius_};
                    const Vec3 d=p-o.center;
                    float best=e.x-std::abs(d.x);int axis=0;
                    if(e.y-std::abs(d.y)<best){best=e.y-std::abs(d.y);axis=1;}
                    if(e.z-std::abs(d.z)<best)axis=2;
                    if(axis==0)p.x=o.center.x+(d.x<0?-1:1)*(e.x+skin);
                    if(axis==1)p.y=o.center.y+(d.y<0?-1:1)*(e.y+skin);
                    if(axis==2)p.z=o.center.z+(d.z<0?-1:1)*(e.z+skin);
                }
                clampBody(p);
            }
            if(!changed)return clear(p);
        }
        return clear(p);
    }
    [[nodiscard]] bool clear(Vec3 p) const noexcept {
        if(!finite(p)||p.x<radius_||p.y<radius_||p.z<radius_||p.x>bounds_.x-radius_||p.y>bounds_.y-radius_||p.z>bounds_.z-radius_)return false;
        if(p.z<floorHeight(p.x,p.y,radius_))return false;
        for(const auto& o:objects_)if(o.solid&&inside(o,p,radius_))return false;
        return true;
    }
    // Swept movement and tangential sliding, fixed iteration cap and stable ID ties.
    // Return false if the starting position cannot be resolved; caller must abort.
    [[nodiscard]] bool move(Vec3 start,Vec3& target,Vec3& velocity) const noexcept {
        const float skin=field_?0.001F:Skin;
        if(!finite(target)||!finite(velocity)||!projectOutside(start))return false;
        Vec3 remaining=target-start,p=start;
        for(int iteration=0;iteration<4 && remaining.lengthSquared()>1e-12F;++iteration) {
            auto hit=sweep(p,p+remaining,radius_);
            if(!hit.hit){p+=remaining;remaining={};break;}
            const float length=std::sqrt(remaining.lengthSquared());
            const float travel=std::max(0.0F,hit.fraction-skin/std::max(length,skin));
            p+=remaining*travel;
            remaining=remaining*(1-hit.fraction);
            const float inward=dot(remaining,hit.normal);
            if(inward<0)remaining=remaining-hit.normal*inward;
            const float speed=dot(velocity,hit.normal);
            if(speed<0)velocity=velocity-hit.normal*speed;
        }
        // Stop remaining movement at the contact cap instead of tunneling.
        target=p;
        bound(target.x,velocity.x,bounds_.x);bound(target.y,velocity.y,bounds_.y);bound(target.z,velocity.z,bounds_.z);
        if(field_){
            const float ground=floorHeight(target.x,target.y,radius_);
            // Roundoff at steep facets must not turn a valid contact into a
            // failed move. This is bounded to two skin widths, never a teleport.
            if(target.z<ground+skin && target.z>=ground-2*skin && ground+skin<=bounds_.z-radius_)
                target.z=ground+skin;
        }
        if(!clear(target)){
            // At a shoreline cusp the floor and water ceiling can converge.
            // Reject this displacement; retain the resolved start, never warp.
            target=start;velocity={};
        }
        return clear(target);
    }
private:
    const Heightfield* field_{nullptr};Vec3 bounds_{100,100,60};
    bool clipXY(Vec3& a,Vec3& b)const noexcept{
        const Vec3 d=b-a;float enter=0,exit=1;
        const float origin[]{a.x,a.y},direction[]{d.x,d.y};
        for(int i=0;i<2;++i){
            if(std::abs(direction[i])<1e-12F){if(origin[i]<0||origin[i]>(i==0?bounds_.x:bounds_.y))return false;continue;}
            float t1=-origin[i]/direction[i],t2=((i==0?bounds_.x:bounds_.y)-origin[i])/direction[i];if(t1>t2)std::swap(t1,t2);
            enter=std::max(enter,t1);exit=std::min(exit,t2);if(enter>exit)return false;
        }
        b=a+d*exit;a=a+d*enter;return true;
    }
    static bool finite(Vec3 p)noexcept{return std::isfinite(p.x)&&std::isfinite(p.y)&&std::isfinite(p.z);}
    static float dot(Vec3 a,Vec3 b)noexcept{return a.x*b.x+a.y*b.y+a.z*b.z;}
    static int cell(float v,int max,float extent)noexcept{return static_cast<int>(std::clamp(std::floor(v*(max+1)/extent),0.0F,static_cast<float>(max)));}
    static int index(int x,int y,int z)noexcept{return (z*10+y)*10+x;}
    void clampBody(Vec3& p)const noexcept{p.x=std::clamp(p.x,radius_,bounds_.x-radius_);p.y=std::clamp(p.y,radius_,bounds_.y-radius_);p.z=std::clamp(p.z,radius_,bounds_.z-radius_);}
    void bound(float& p,float& v,float limit)const noexcept{
        if(p<radius_){p=radius_;if(v<0)v=0;}else if(p>limit-radius_){p=limit-radius_;if(v>0)v=0;}
    }
    std::array<bool,MaxObjects> query(Vec3 a,Vec3 b,float pad)const noexcept{
        std::array<bool,MaxObjects> seen{};
        if(objects_.size()<=8){for(std::size_t i=0;i<objects_.size();++i)seen[i]=true;return seen;}
        const Vec3 lo{std::min(a.x,b.x)-pad,std::min(a.y,b.y)-pad,std::min(a.z,b.z)-pad};
        const Vec3 hi{std::max(a.x,b.x)+pad,std::max(a.y,b.y)+pad,std::max(a.z,b.z)+pad};
        for(int z=cell(lo.z,5,bounds_.z);z<=cell(hi.z,5,bounds_.z);++z)for(int y=cell(lo.y,9,bounds_.y);y<=cell(hi.y,9,bounds_.y);++y)for(int x=cell(lo.x,9,bounds_.x);x<=cell(hi.x,9,bounds_.x);++x)
            for(auto i:cells_[index(x,y,z)])seen[i]=true;
        return seen;
    }
    static bool overlap(const GeometryObject& o,Vec3 lo,Vec3 hi)noexcept{
        return hi.x>=o.center.x-o.halfSize.x&&lo.x<=o.center.x+o.halfSize.x
            &&hi.y>=o.center.y-o.halfSize.y&&lo.y<=o.center.y+o.halfSize.y
            &&hi.z>=o.center.z-o.halfSize.z&&lo.z<=o.center.z+o.halfSize.z;
    }
    static bool inside(const GeometryObject& o,Vec3 p,float pad)noexcept{
        Vec3 d=p-o.center;
        if(o.shape==GeometryShape::Sphere){const float r=o.halfSize.x+pad;return d.lengthSquared()<r*r;}
        return std::abs(d.x)<o.halfSize.x+pad&&std::abs(d.y)<o.halfSize.y+pad&&std::abs(d.z)<o.halfSize.z+pad;
    }
    static GeometryHit intersect(const GeometryObject& o,Vec3 a,Vec3 b,float pad)noexcept{
        GeometryHit h;h.id=o.id;const Vec3 d=b-a;
        if(inside(o,a,pad)){h.hit=true;h.fraction=0;return h;}
        if(o.shape==GeometryShape::Sphere){
            Vec3 m=a-o.center;float r=o.halfSize.x+pad,A=dot(d,d),B=dot(m,d),C=dot(m,m)-r*r;
            if(A<1e-16F||B>=0)return h;
            float disc=B*B-A*C;if(disc<0)return h;
            float t=(-B-std::sqrt(disc))/A;
            if(t>=0&&t<=1){h.hit=true;h.fraction=t;h.normal=(a+d*t-o.center).normalized();}return h;
        }
        Vec3 e=o.halfSize+Vec3{pad,pad,pad},low=o.center-e,high=o.center+e;
        const float origins[]{a.x,a.y,a.z},dirs[]{d.x,d.y,d.z},lo[]{low.x,low.y,low.z},hi[]{high.x,high.y,high.z};
        float enter=-std::numeric_limits<float>::infinity(),exit=1;Vec3 normal{};
        for(int axis=0;axis<3;++axis){
            if(std::abs(dirs[axis])<1e-12F){if(origins[axis]<=lo[axis]||origins[axis]>=hi[axis])return h;continue;}
            float t1=(lo[axis]-origins[axis])/dirs[axis],t2=(hi[axis]-origins[axis])/dirs[axis];
            float sign=-1;if(t1>t2){std::swap(t1,t2);sign=1;}
            if(t1>enter){enter=t1;normal={};if(axis==0)normal.x=sign;if(axis==1)normal.y=sign;if(axis==2)normal.z=sign;}
            exit=std::min(exit,t2);if(enter>exit)return h;
        }
        if(enter>=0&&enter<=1){h.hit=true;h.fraction=enter;h.normal=normal;}return h;
    }
    std::vector<GeometryObject> objects_;
    std::array<std::vector<std::size_t>,600> cells_{};
    float radius_;
    std::vector<Vec3> planes_,normals_;
    std::vector<float> offsets_;
};
} // namespace cybernet

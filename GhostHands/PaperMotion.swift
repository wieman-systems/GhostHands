import Foundation
import simd

/// Authored explanatory paper surfaces, not a physical paper solver.
enum PaperMotion {
    static func p(_ v: SIMD2<Float>, width: Float) -> SIMD3<Float> { [v.x*width/2,0,v.y*LetterPaper.height/2] }
    static func folded(_ point: SIMD3<Float>, step: PaperStep, progress: Float, width: Float) -> SIMD3<Float> {
        let a=p(step.crease.0,width:width),b=p(step.crease.1,width:width)
        let axis=simd_normalize(b-a), from=p(step.action == .unfold ? SIMD2<Float>(-1,0) : step.from,width:width)
        let sign: Float=simd_cross(axis,from-a).y >= 0 ? 1 : -1
        let amount=step.action == .unfold ? 1-progress : progress
        return a+simd_act(simd_quatf(angle:sign * .pi * amount,axis:axis),point-a)
    }
    static func contact(step: PaperStep, progress: Float, width: Float) -> SIMD3<Float> {
        if step.action == .fold || step.action == .unfold {
            return folded(p(step.action == .unfold ? SIMD2<Float>(-1,0) : step.from,width:width),step:step,progress:progress,width:width)
        }
        if step.action == .flip {
            let source=vertices(step:PaperStep.all[step.id-1],progress:1,width:width)
            return flipped(p(step.from,width:width),source:source,progress:progress)
        }
        let point=step.from+(step.to-step.from)*progress
        return p(point,width:width)+SIMD3<Float>(0,sin(progress * .pi)*0.05,0)
    }
    static func smooth(_ value:Float)->Float {let t=min(1,max(0,value));return t*t*(3-2*t)}
    static func flipped(_ point:SIMD3<Float>,source:[SIMD3<Float>],progress:Float)->SIMD3<Float> {
        let minX=source.map(\.x).min() ?? 0,maxX=source.map(\.x).max() ?? 0
        let center=SIMD3<Float>((minX+maxX)/2,0,0)
        let radius=(maxX-minX)/2
        let angle=Float.pi*progress
        // The grip lifts the whole paper before its edge can pass through the table.
        let lift=sin(angle)*(radius+0.018)
        return center+simd_act(simd_quatf(angle:angle,axis:[0,0,1]),point-center)+SIMD3(0,lift,0)
    }
    /// A deliberately staged explanatory transition. Repeating complete triangles
    /// preserves the previous silhouette at t=0 and the destination at t=1.
    static func transition(_ source:[SIMD3<Float>],_ destination:[SIMD3<Float>],amount:Float)->[SIMD3<Float>] {
        if amount<=0 {return source};if amount>=1 {return destination}
        let count=max(source.count,destination.count)
        return (0..<count).map {i in source[i % source.count]+(destination[i % destination.count]-source[i % source.count])*amount}
    }
    static func handContacts(step:PaperStep,progress:Float,width:Float)->(SIMD3<Float>,SIMD3<Float>)? {
        let t=min(1,max(0,progress))
        if step.action == .flip {
            let source=vertices(step:PaperStep.all[step.id-1],progress:1,width:width)
            let z:Float=step.id==6 ? 0.45 : 0
            let left=flipped(p([-0.5,z],width:width),source:source,progress:t)
            let right=flipped(p([0.5,z],width:width),source:source,progress:t)
            return (left+SIMD3(0,0.012,0),right+SIMD3(0,0.012,0))
        }
        if step.action == .open {
            let opening=smooth((t-0.4)/0.6)
            let c=pocketCorners(step:step.id,open:opening,flatten:0,width:width)
            let start=p(step.id==9 ? [0,0.7] : [0,-0.03],width:width)
            let lift=smooth(t/0.4)
            // Distinct hands approach opposite sides of the mouth.
            return (start+(c[3]-start)*lift+SIMD3(-0.014,0.012,0),start+(c[2]-start)*lift+SIMD3(0.014,0.012,0))
        }
        if step.action == .flatten {
            let c=pocketCorners(step:step.id,open:1,flatten:t,width:width)
            // Stop the grips either side of the crease instead of intersecting hands.
            return (c[0]+SIMD3(-0.018,0.012,0),c[1]+SIMD3(0.018,0.012,0))
        }
        if step.action == .finish {
            let spread:Float=0.008+0.027*t
            return (SIMD3(-0.03,0.012,-spread),SIMD3(0.03,0.012,spread))
        }
        if step.action == .tidy {
            let left=tidyPoint(p([-1,0.773],width:width),left:true,amount:min(1,t*2),width:width)
            let right=tidyPoint(p([1,0.773],width:width),left:false,amount:max(0,t*2-1),width:width)
            return (left+SIMD3(0,0.012,0),right+SIMD3(0,0.012,0))
        }
        return nil
    }
    static func tidyPoint(_ point:SIMD3<Float>,left:Bool,amount:Float,width:Float)->SIMD3<Float> {
        let x:Float=(left ? -0.82 : 0.82)*width/2
        let hinge=SIMD3<Float>(x,0,point.z)
        return hinge+simd_act(simd_quatf(angle:(left ? -1 : 1)*Float.pi*amount,axis:[0,0,1]),point-hinge)
    }
    static func triangles(_ polygon: [SIMD3<Float>]) -> [SIMD3<Float>] {
        guard polygon.count>=3 else{return []}
        return (1..<(polygon.count-1)).flatMap { [polygon[0],polygon[$0],polygon[$0+1]] }
    }
    static func clipped(_ points:[SIMD3<Float>],a:SIMD3<Float>,b:SIMD3<Float>,sign:Float)->[SIMD3<Float>] {
        func distance(_ v:SIMD3<Float>)->Float { ((b.x-a.x)*(v.z-a.z)-(b.z-a.z)*(v.x-a.x))*sign }
        var result:[SIMD3<Float>]=[]
        for i in points.indices {
            let start=points[i],end=points[(i+1)%points.count],d0=distance(start),d1=distance(end)
            if d0 >= -0.000001 {result.append(start)}
            if (d0>=0) != (d1>=0),abs(d0-d1)>0.000001 {result.append(start+(end-start)*(d0/(d0-d1)))}
        }
        return result
    }
    // Four connected panels keep their identity as the mouth opens and the
    // original side corners meet. No arbitrary triangle-to-diamond morph.
    static func pocketCorners(step:Int,open:Float,flatten:Float,width:Float)->[SIMD3<Float>] {
        let small=step>=14
        let r:Float=small ? 0.4 : 0.65
        let extent=width*r/2
        let depth=LetterPaper.height*r/2
        let opening=open * (0.35+0.65*flatten)
        let left=SIMD3<Float>(-extent*(1-flatten),depth*(1-flatten),0)
        let right=SIMD3<Float>(extent*(1-flatten),depth*(1-flatten),0)
        let front=SIMD3<Float>(0,0,depth*opening)
        let back=SIMD3<Float>(0,0,-depth*opening)
        let far=SIMD3<Float>(-extent,0,0)
        let near=SIMD3<Float>(extent,0,0)
        return [left,right,front,back,far,near]
    }
    static func pocket(step:Int,amount:Float,width:Float,flatten:Float=0)->[SIMD3<Float>] {
        let c=pocketCorners(step:step,open:amount,flatten:flatten,width:width)
        return [c[4],c[2],c[0],c[4],c[0],c[3],c[5],c[1],c[2],c[5],c[3],c[1]]
    }
    static func vertices(step:PaperStep,progress:Float,width:Float)->[SIMD3<Float>] {
        let t=min(1,max(0,progress)),points=step.outline.map {p($0,width:width)}
        if step.action == .fold || step.action == .unfold {
            let a=p(step.crease.0,width:width),b=p(step.crease.1,width:width)
            let from=p(step.action == .unfold ? [-1,0] : step.from,width:width)
            let signed=(b.x-a.x)*(from.z-a.z)-(b.z-a.z)*(from.x-a.x)
            let sign:Float=signed>=0 ? 1 : -1
            let still=clipped(points,a:a,b:b,sign:-sign)
            let moving=clipped(points,a:a,b:b,sign:sign).map { folded($0,step:step,progress:t,width:width) }
            let front=triangles(still)+triangles(moving)
            // Front-only folds leave a complete back layer on the table.
            if step.id==5 || step.id==11 {return triangles(points)+front}
            return front
        }
        if step.action == .flip {
            let source=vertices(step:PaperStep.all[step.id-1],progress:1,width:width)
            return source.map {flipped($0,source:source,progress:t)}
        }
        if step.action == .tidy {
            let a=p([-0.82,-1],width:width),b=p([-0.82,1],width:width)
            let left=clipped(points,a:a,b:b,sign:1)
            let remainder=clipped(points,a:a,b:b,sign:-1)
            let c=p([0.82,-1],width:width),d=p([0.82,1],width:width)
            let right=clipped(remainder,a:c,b:d,sign:-1)
            let center=clipped(remainder,a:c,b:d,sign:1)
            return triangles(center)+triangles(left.map {tidyPoint($0,left:true,amount:min(1,t*2),width:width)})+triangles(right.map {tidyPoint($0,left:false,amount:max(0,t*2-1),width:width)})
        }
        if step.action == .open {
            let source=vertices(step:PaperStep.all[step.id-1],progress:1,width:width)
            if t<0.4 {return transition(source,pocket(step:step.id,amount:0,width:width),amount:smooth(t/0.4))}
            return pocket(step:step.id,amount:smooth((t-0.4)/0.6),width:width)
        }
        if step.action == .flatten {
            return pocket(step:step.id,amount:1,width:width,flatten:t)
        }
        if step.action == .pull || step.action == .finish {
            let amount=step.action == .finish ? 1 : t
            let hullDepth:Float=step.action == .finish ? 0.008+0.027*t : 0.008
            let left=SIMD3<Float>(-width*0.45,0,0),right=SIMD3<Float>(width*0.45,0,0)
            let peak=SIMD3<Float>(0,0.065,0),front=SIMD3<Float>(0,0.005,hullDepth),back=SIMD3<Float>(0,0.005,-hullDepth)
            let target=[left,peak,right,left,front,right,left,right,back,front,back,right]
            let diamond=triangles(PaperStep.smallDiamond.map {p($0,width:width)})
            return target.enumerated().map {i,v in let origin=diamond[i % diamond.count];return origin+(v-origin)*amount}
        }
        return triangles(points)
    }
}

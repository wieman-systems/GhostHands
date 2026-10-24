import RealityKit
import UIKit
import simd

/// Opaque physically based metals in color mode; original monochrome hologram otherwise.
enum ModelSurface {
    static func material(colored:Bool,color:UIColor = .systemGray,alpha:Float=0.8,metal:Float=0.75)->any Material {
        if colored && alpha>0.3 {
            var m=PhysicallyBasedMaterial()
            m.baseColor = .init(tint:color);m.metallic = .init(floatLiteral:metal);m.roughness = .init(floatLiteral:0.32)
            return m
        }
        var m=UnlitMaterial(color:colored ? color : .white)
        m.blending = .transparent(opacity:.init(floatLiteral:alpha));return m
    }
    static func color(_ part:LabPart?)->UIColor {
        switch part {
        case .fan,.disc,.driver:return UIColor(red:0.65,green:0.72,blue:0.78,alpha:1)
        case .compressor,.outlet,.volute:return UIColor(red:0.12,green:0.42,blue:0.55,alpha:1)
        case .combustor,.caliper:return UIColor(red:0.8,green:0.15,blue:0.08,alpha:1)
        case .turbine,.impeller,.driven:return UIColor(red:0.77,green:0.52,blue:0.18,alpha:1)
        case .pads:return UIColor(white:0.16,alpha:1)
        default:return UIColor(white:0.58,alpha:1)
        }
    }
    /// Closed annular solid, oriented along Z; suitable for rotors and flange openings.
    static func ring(inner:Float,outer:Float,depth:Float)->MeshResource {
        var points:[SIMD3<Float>]=[],normals:[SIMD3<Float>]=[],indices:[UInt32]=[]
        func quad(_ a:SIMD3<Float>,_ b:SIMD3<Float>,_ c:SIMD3<Float>,_ d:SIMD3<Float>) {
            let n=simd_normalize(simd_cross(b-a,c-a)),base=UInt32(points.count)
            points += [a,b,c,d];normals += [n,n,n,n];indices += [base,base+1,base+2,base,base+2,base+3]
        }
        for i in 0..<64 {
            let a=Float(i)*2*Float.pi/64,b=Float(i+1)*2*Float.pi/64
            func p(_ r:Float,_ t:Float,_ z:Float)->SIMD3<Float> {[r*cos(t),r*sin(t),z]}
            let z=depth/2
            quad(p(inner,a,z),p(outer,a,z),p(outer,b,z),p(inner,b,z))
            quad(p(inner,b,-z),p(outer,b,-z),p(outer,a,-z),p(inner,a,-z))
            quad(p(outer,a,z),p(outer,a,-z),p(outer,b,-z),p(outer,b,z))
            quad(p(inner,b,z),p(inner,b,-z),p(inner,a,-z),p(inner,a,z))
        }
        var d=MeshDescriptor();d.positions=MeshBuffers.Positions(points);d.normals=MeshBuffers.Normals(normals);d.primitives = .triangles(indices)
        return (try? MeshResource.generate(from:[d])) ?? .generateSphere(radius:outer)
    }
    /// Tapered, swept blade with camber instead of a rectangular finger-like slab.
    static func blade(span:Float,chord:Float)->MeshResource {
        var points:[SIMD3<Float>]=[],indices:[UInt32]=[]
        for side in 0..<2 {for row in 0...8 {for col in 0...4 {
            let t=Float(row)/8,u=Float(col)/4-0.5
            points.append([u*chord*(1-0.45*t)+0.012*t*t,t*span,0.003*sin((u+0.5)*Float.pi)+t*u*0.012+Float(side)*0.0008])
        }}}
        for side in 0..<2 {for row in 0..<8 {for col in 0..<4 {
            let a=UInt32(side*45+row*5+col),b=a+1,c=a+5,d=c+1
            indices += side==0 ? [a,b,c,b,d,c] : [a,c,b,b,c,d]
        }}}
        var d=MeshDescriptor();d.positions=MeshBuffers.Positions(points);d.primitives = .triangles(indices)
        return (try? MeshResource.generate(from:[d])) ?? .generateBox(width:chord,height:span,depth:0.002)
    }
}

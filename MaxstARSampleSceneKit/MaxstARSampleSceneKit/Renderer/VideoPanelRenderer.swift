//
//  VideoPanelRenderer.swift
//  MaxstARSampleSwiftMetal
//
//  Created by Kimseunglee on 2018. 3. 15..
//  Copyright © 2018년 Maxst. All rights reserved.
//

import UIKit
import MetalKit
import Metal
import MaxstARSDKFramework

class VideoPanelRenderer: BaseModel {
    var vertexData:[Vertex]?
    var vertexBuffer: MTLBuffer?
    var uniformBuffer: MTLBuffer!
    
    var width:Int = 0
    var height:Int = 0

    var samplerState:MTLSamplerState!
    
    let A = Vertex(x: -0.5, y:   0.5, z:   0.0, r:  1.0, g:  1.0, b:  1.0, a:  1.0, s: 0, t: 1)
    let B = Vertex(x: -0.5, y:  -0.5, z:   0.0, r:  1.0, g:  1.0, b:  1.0, a:  1.0, s: 0, t: 0)
    let C = Vertex(x:  0.5, y:  -0.5, z:   0.0, r:  1.0, g:  1.0, b:  1.0, a:  1.0, s: 1, t: 0)
    let D = Vertex(x:  0.5, y:   0.5, z:   0.0, r:  1.0, g:  1.0, b:  1.0, a:  1.0, s: 1, t: 1)
    
    var verticesArray:Array<Vertex>?
    
    required init(device:MTLDevice!, pixelFormat:MTLPixelFormat) {
        super.init()
        self.device = device
        
        verticesArray = [
            A,B,C,C,D,A,
        ]
        setup(pixelFormat: pixelFormat)
    }
    
    func setVideoSize(width:Int, height:Int) {
        self.width = width
        self.height = height
    }
    
    func setup(pixelFormat:MTLPixelFormat) {
        let dataSize = verticesArray!.count * MemoryLayout<Vertex>.size
        vertexBuffer = device!.makeBuffer(bytes: verticesArray!, length: dataSize, options: [])
        uniformBuffer = device!.makeBuffer(length: MemoryLayout<matrix_float4x4>.size, options: [])

        let library = device!.makeDefaultLibrary()!
        let vertex_func = library.makeFunction(name: "texture_vertex_func")
        let frag_func = library.makeFunction(name: "texture_fragment_func")
        
        let rpld = MTLRenderPipelineDescriptor()
        rpld.vertexFunction = vertex_func
        rpld.fragmentFunction = frag_func
        rpld.colorAttachments[0].pixelFormat = pixelFormat
        rpld.depthAttachmentPixelFormat = MTLPixelFormat.depth32Float
        
        do {
            try rps = device!.makeRenderPipelineState(descriptor: rpld)
        } catch let error {
            NSLog("fail")
            print("\(error)")
        }
        
        let samplerDescriptor = MTLSamplerDescriptor()
        samplerDescriptor.minFilter = .linear
        samplerDescriptor.magFilter = .linear
        samplerDescriptor.mipFilter = .linear
        samplerDescriptor.sAddressMode = .clampToEdge
        samplerDescriptor.rAddressMode = .clampToEdge
        samplerDescriptor.tAddressMode = .clampToEdge
        samplerDescriptor.normalizedCoordinates = true
        
        samplerState = device!.makeSamplerState(descriptor: samplerDescriptor)
    }
    
    func draw(commandEncoder:MTLRenderCommandEncoder, videoTextureId:MTLTexture!)
    {
        if self.width == 0 || self.height == 0 || videoTextureId == nil
        {
            return;
        }
        
        commandEncoder.setRenderPipelineState(self.rps!)
        commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        commandEncoder.setVertexBuffer(uniformBuffer, offset: 0, index: 1)
        commandEncoder.setFragmentTexture(videoTextureId, index: 0)
        
        self.localMVPMatrix = matrix_multiply(self.projectionMatrix, self.modelMatrix)
        
        let bufferPointer = uniformBuffer.contents()
        var uniforms = Uniforms(modelViewProjectionMatrix: localMVPMatrix)
        memcpy(bufferPointer, &uniforms, MemoryLayout<Uniforms>.size)
        
        if let samplerState = samplerState {
            commandEncoder.setFragmentSamplerState(samplerState, index: 0)
        }
        let vertexCount = verticesArray!.count
        
        commandEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: vertexCount, instanceCount: 1)
    }
}


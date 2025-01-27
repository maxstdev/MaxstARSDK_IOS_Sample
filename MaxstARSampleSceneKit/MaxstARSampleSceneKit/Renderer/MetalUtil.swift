/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Top level utility functions.
 */


import Foundation
import Metal
import simd

func getPerpectiveProjectionMatrix(_ FieldOfView : Float, aspectRatio : Float, zFar : Float, zNear : Float) -> matrix_float4x4
{
    var m : matrix_float4x4 = matrix_float4x4()
    
    let f : Float = 1.0 / tan(FieldOfView / 2.0)
    
    m.columns.0.x = f / aspectRatio
    m.columns.1.y = f
    
    m.columns.2.z = zFar / (zFar - zNear)
    m.columns.2.w = 1.0
    
    m.columns.3.z = -(zNear*zFar)/(zFar-zNear)
    
    return m
}

func getLHOrthoMatrix(_ width : Float, height : Float, zFar : Float, zNear : Float) -> matrix_float4x4
{
    var m = matrix_float4x4()
    
    m.columns.0.x = 2.0 / width
    
    m.columns.1.y = 2.0 / height
    
    m.columns.2.z = 1.0 / (zFar-zNear)
    
    m.columns.3.z = -zNear / (zFar-zNear)
    m.columns.3.w = 1.0
    
    return m
}

func getRotationAroundZ(_ radians : Float) -> matrix_float4x4
{
    var m : matrix_float4x4 = matrix_identity_float4x4;
    
    m.columns.0.x = cos(radians);
    m.columns.0.y = sin(radians);
    
    m.columns.1.x = -sin(radians);
    m.columns.1.y = cos(radians);
    
    return m;
}

func getRotationAroundY(_ radians : Float) -> matrix_float4x4
{
    var m : matrix_float4x4 = matrix_identity_float4x4;
    
    m.columns.0.x =  cos(radians);
    m.columns.0.z = -sin(radians);
    
    m.columns.2.x = sin(radians);
    m.columns.2.z = cos(radians);
    
    return m;
}

func getRotationAroundX(_ radians : Float) -> matrix_float4x4
{
    var m : matrix_float4x4 = matrix_identity_float4x4;
    
    m.columns.1.y = cos(radians);
    m.columns.1.z = sin(radians);
    
    m.columns.2.y = -sin(radians);
    m.columns.2.z =  cos(radians);
    
    return m;
}

func getTranslationMatrix(_ translation : vector_float4) -> matrix_float4x4
{
    var m : matrix_float4x4 = matrix_identity_float4x4
    
    m.columns.3 = translation
    
    return m
}

func getScaleMatrix(_ x : Float, y : Float, z : Float) -> matrix_float4x4
{
    var m = matrix_identity_float4x4
    
    m.columns.0.x = x
    m.columns.1.y = y
    m.columns.2.z = z
    
    return m
}

//Returns a value from -max to max
func getRandomValue(_ max : Double) -> Double
{
    let r : Int32 = Int32(Int64(arc4random()) - Int64(RAND_MAX))
    let v = (Double(r) / Double(RAND_MAX)) * max
    
    return v
}

func crossProduct(_ a : vector_float3, b : vector_float3) -> vector_float3
{
    var r : vector_float3 = vector_float3()
    
    r.x = a.y*b.z - a.z*b.y
    r.y = a.z*b.x - a.x*b.z
    r.z = a.x*b.y - a.y*b.x
    
    return r
}

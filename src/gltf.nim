import
  json,
  macros,
  
  ./gltfpkg/private/koppehschema

# https://github.com/KhronosGroup/glTF/tree/master/specification/2.0/schema

jsonschema:
  
  GltfId: Natural
  
  GltfProperty:
    extensions: JsonNode
    extras:     JsonNode
  
  GltfAsset extends GltfProperty:
    version:     string ## The glTF version that this asset targets.
    minVersion?: string ## The minimum glTF version that this asset targets.
    copyright?:  string ## A copyright message suitable for display to credit the content creator.
    generator?:  string ## Tool that generated this glTF model. Useful for debugging.
  
  GltfRoot extends GltfProperty:
    asset:  GltfAsset
    scene?: GltfId (dependsOn=scenes)
    
    extensionsUsed?:     seq[string] (unique, min=1) ## Names of glTF extensions used somewhere in this asset.
    extensionsRequired?: seq[string] (unique, min=1) ## Names of glTF extensions required to properly load this asset.
    
    accessors?:   seq[GltfAccessor]   (min=1) ## An array of accessors. An accessor is a typed view into a bufferView.
    animations?:  seq[GltfAnimation]  (min=1) ## An array of keyframe animations.
    buffers?:     seq[GltfBuffer]     (min=1) ## An array of buffers. A buffer points to binary geometry, animation, or skins.
    bufferViews?: seq[GltfBufferView] (min=1) ## An array of bufferViews. A bufferView is a view into a buffer generally representing a subset of the buffer.
    cameras?:     seq[GltfCamera]     (min=1) ## An array of cameras. A camera defines a projection matrix.
    images?:      seq[GltfImage]      (min=1) ## An array of images. An image defines data used to create a texture.
    materials?:   seq[GltfMaterial]   (min=1) ## An array of materials. A material defines the appearance of a primitive.
    meshes?:      seq[GltfMesh]       (min=1) ## An array of meshes. A mesh is a set of primitives to be rendered.
    nodes?:       seq[GltfNode]       (min=1) ## An array of nodes.
    samplers?:    seq[GltfSampler]    (min=1) ## An array of samplers. A sampler contains properties for texture filtering and wrapping modes.
    scenes?:      seq[GltfScene]      (min=1) ## An array of scenes.
    skins?:       seq[GltfSkin]       (min=1) ## An array of skins. A skin is defined by joints and matrices.
    textures?:    seq[GltfTexture]    (min=1) ## An array of textures.
  
  GltfAccessor: JsonNode
  GltfAnimation: JsonNode
  GltfBuffer: JsonNode
  GltfBufferView: JsonNode
  GltfCamera: JsonNode
  GltfImage: JsonNode
  GltfMaterial: JsonNode
  GltfMesh: JsonNode
  GltfNode: JsonNode
  GltfSampler: JsonNode
  GltfScene: JsonNode
  GltfSkin: JsonNode
  GltfTexture: JsonNode

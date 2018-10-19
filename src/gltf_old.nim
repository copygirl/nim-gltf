import
  future,
  glm,
  json,
  opengl,
  options,
  streams,
  strutils,
  tables,
  
  ./gltf/private/results

type
  GltfLoadError* = object of ValueError
  
  ObjectIndex = Natural
  BufferTarget* = uint32
  ComponentType* = uint32
  PrimitiveMode* = uint32
  
  AccessorType* = enum
    atScalar = "SCALAR"
    atVec2   = "VEC2"
    atVec3   = "VEC3"
    atVec4   = "VEC4"
    atMat2   = "MAT2"
    atMat3   = "MAT3"
    atMat4   = "MAT4"


const
  ARRAY_BUFFER*              = 0x8892.BufferTarget
  ELEMENT_ARRAY_BUFFER*      = 0x8893.BufferTarget
  PIXEL_PACK_BUFFER*         = 0x88EB.BufferTarget
  PIXEL_UNPACK_BUFFER*       = 0x88EC.BufferTarget
  UNIFORM_BUFFER*            = 0x8A11.BufferTarget
  TEXTURE_BUFFER*            = 0x8C2A.BufferTarget
  TRANSFORM_FEEDBACK_BUFFER* = 0x8C8E.BufferTarget
  COPY_READ_BUFFER*          = 0x8F36.BufferTarget
  COPY_WRITE_BUFFER*         = 0x8F37.BufferTarget
  DRAW_INDIRECT_BUFFER*      = 0x8F3F.BufferTarget
  SHADER_STORAGE_BUFFER*     = 0x90D2.BufferTarget
  DISPATCH_INDIRECT_BUFFER*  = 0x90EE.BufferTarget
  QUERY_BUFFER*              = 0x9192.BufferTarget
  ATOMIC_COUNTER_BUFFER*     = 0x92C0.BufferTarget

const
  BYTE*           = 5120.ComponentType
  UNSIGNED_BYTE*  = 5121.ComponentType
  SHORT*          = 5122.ComponentType
  UNSIGNED_SHORT* = 5123.ComponentType
  UNSIGNED_INT*   = 5125.ComponentType
  FLOAT*          = 5126.ComponentType

const
  POINTS*         = 0x0000.PrimitiveMode
  LINES*          = 0x0001.PrimitiveMode
  LINE_LOOP*      = 0x0002.PrimitiveMode
  LINE_STRIP*     = 0x0003.PrimitiveMode
  TRIANGLES*      = 0x0004.PrimitiveMode
  TRIANGLE_STRIP* = 0x0005.PrimitiveMode
  TRIANGLE_FAN*   = 0x0006.PrimitiveMode


type
  Asset* = object
    version*: Version
    minVersion*: Option[Version]
    copyright*: Option[string]
    generator*: Option[string]
    
    scene: Option[ObjectIndex]
    scenes: seq[Scene]
    nodes: seq[Node]
    buffers: seq[Buffer]
    bufferViews: seq[BufferView]
    accessor: seq[AccessorObj]
    meshes: seq[Mesh]
  
  Version* = object
    major*, minor*: int
  
  Scene* = ref object
    name: Option[string]
    nodes: seq[ObjectIndex]
  
  Node* = ref object
    name: Option[string]
    children: seq[ObjectIndex]
    matrix: Mat4x4d
    mesh: Option[ObjectIndex]
  
  Buffer* = ref object
    byteLength: int
    uri: Option[string]
    data: seq[byte]
  
  BufferView* = ref object
    buffer: ObjectIndex
    byteLength: int
    byteOffset: int
    byteStride: int
    target: BufferTarget
  
  AccessorObj* = ref object of RootObj
    bufferView: Option[ObjectIndex]
    byteOffset: int
    count: int
    sparse: Option[SparseAccessor]
  
  Accessor*[T] = ref object of AccessorObj
    max, min: Option[T]
  
  SparseAccessor* = object
    count: int
    indices_bufferView: ObjectIndex
    indices_byteOffset: int
    indices_componentType: ComponentType
    values_bufferView: ObjectIndex
    values_byteOffset: int
  
  Mesh* = ref object
    primitives: seq[Primitive]
  
  Primitive* = ref object
    attributes: Table[string, ObjectIndex]
    indices: ObjectIndex
    material: Option[ObjectIndex]
    mode: PrimitiveMode

proc version*(major, minor: int): Version =
  Version(major: major, minor: minor)

proc `$`*(self: Version): string =
  "$#.$#" % [$self.major, $self.minor]


const GLTF_VERSION* = version(2, 0)


type JsonWrap = object
  node: JsonNode
  name: string

proc `[]`(node: JsonNode, key: string): JsonWrap =
  JsonWrap(node: node.getOrDefault(key), name: key)

proc `[]`(wrap: JsonWrap, key: string): JsonWrap =
  assert(not wrap.node.isNil)
  JsonWrap(node: wrap.node.getOrDefault(key), name: "$#.$#" % [wrap.name, key])

proc throwIfNil(wrap: JsonWrap): JsonWrap =
  if wrap.node.isNil: raise newException(GltfLoadError, wrap.name & " is missing")
  wrap

proc map[T](wrap: JsonWrap, mapFunc: JsonNode -> Result[T,string]): T =
  mapFunc(wrap.throwIfNil().node).
    mapError(err => newException(GltfLoadError, wrap.name & ": " & err))


proc checkType(node: JsonNode, kind: JsonNodeKind): Result[JsonNode,string] =
  if node.kind == kind: success[JsonNode,string](node)
  else: error[JsonNode,string]("$# expected, but is of type $#" % [$kind, $node.kind])

proc string(node: JsonNode): Result[string,string] = node.checkType(JString).map(n => n.getStr())


proc version(str: string): Result[Version,string] = discard
  # error[Version,string]("'$#' is not a valid version")
  # var s = str.split({'.'})
  # if s.len != 2: return error[Version,string]("'$#' is not a valid version" % $s))
  # try: success[Version,string](version(parseInt(s[0]), parseInt(s[1])))
  # except ValueError: error[Version,string]("'$#' is not a valid version" % $s))


proc loadGltfAsset*(json: JsonNode): Asset =
  let asset = json["asset"].throwIfNil()
  
  result.version    = asset["version"].map(n => n.string.map(version)).orRaise()
  result.minVersion = asset["minVersion"]
  
  # Version support checking
  if result.minVersion.isSome:
    let v = result.minVersion.get()
    if (GLTF_VERSION.major != v.major) or (GLTF_VERSION.minor < v.minor):
      raise newException(GltfLoadError, "asset.minVersion ($#) is not supported, only up to $#" % [$v, $GLTF_VERSION])
  elif (GLTF_VERSION.major != result.version.major):
    raise newException(GltfLoadError, "asset.version ($#) is not supported, expected $#.X" % [$result.version, $GLTF_VERSION.major])
  
  

when true:
  let filename = "examples/2.0/Box/glTF-Draco/Box.gltf"
  var gltf = loadGltfAsset(parseFile(filename))
  
  

import
  future,
  json,
  macros,
  options,
  sequtils,
  strutils,
  
  ./either

export
  json,
  options,
  either

type
  SchemaParseContext = object
    aliases: seq[AliasEntry]
    typeDefs: seq[SchemaTypeDef]
  
  SchemaNode = object {.inheritable.}
    source: NimNode
  
  SchemaTypeDef = object of SchemaNode
    name: string
    extends: Option[string]
    properties: seq[SchemaProperty]
  
  SchemaProperty = object of SchemaNode
    name: string
    optional: bool
    validTypes: seq[ValidType]
    options: seq[OptionEntry]
  
  ValidType = object of SchemaNode
  AliasEntry = object of SchemaNode
    name: string
    validTypes: seq[ValidType]
  OptionEntry = object of SchemaNode
    name: string
    value: NimNode


proc expect(n: NimNode, k: set[NimNodeKind]): NimNode {.discardable.} =
  if not (n.kind in k): error("Expected one of $#, got $#" % [$k, $n.kind], n)
  n

proc expect(n: NimNode, k: NimNodeKind): NimNode {.discardable.} =
  if n.kind != k: error("Expected $#, got $#" % [$k, $n.kind], n)
  n

proc expectLen(n: NimNode, l: int): NimNode {.discardable.} =
  if n.len != l: error("Expected $# children, got $#" % [$l, $n.len], n)
  n

proc ident(n: NimNode): string =
  $macros.ident(n.expect(nnkIdent))

proc expectIdent(n: NimNode, i: string) =
  if $n.ident != i: error("Expected '$#', got '$#'" % [$i, $n.ident], n)


proc parseValidTypes(node: NimNode): seq[ValidType] =
  result = newSeq[ValidType]()
  var remaining = node
  while remaining != nil:
    remaining.expect({ nnkIdent, nnkBracketExpr, nnkInfix })
    
    var current: NimNode
    if remaining.kind == nnkInfix:
      remaining[0].expectIdent("|")
      current = remaining[2]
      remaining = remaining[1]
    else:
      current = remaining
      remaining = nil
    
    result.add(ValidType(source: current))

proc parseProperties(context: var SchemaParseContext,
                     typeDef: var SchemaTypeDef, statements: NimNode) =
  for node in statements:
    node.expect({ nnkCall, nnkInfix, nnkCommand })
    var property = SchemaProperty(source: node, validTypes: @[], options: @[])
    var validTypesNode: NimNode
    var optionsNode: NimNode
    case node.kind:
      # Call
      #   Ident <property>
      #   StmtList (len=1)
      #     <validTypesNode>
      #   [or]
      #     Command
      #       <validTypesNode>
      #       Par <paramsNode>
      of nnkCall:
        property.name = node[0].ident
        if node[1].expectLen(1)[0].kind == nnkCommand:
          validTypesNode = node[1][0][0]
          optionsNode    = node[1][0][1].expect(nnkPar)
        else:
          validTypesNode = node[1][0]
      
      # Infix
      #   Ident ident"?:"
      #   Ident <property>
      #   <validTypesNode>
      of nnkInfix:
        node[0].expectIdent("?:")
        property.name     = node[1].ident
        property.optional = true
        validTypesNode    = node[2]
      
      # Command
      #   Infix
      #     Ident ident"?:"
      #     Ident <property>
      #     <validTypesNode>
      #   Par <paramsNode>
      of nnkCommand:
        node[0][0].expectIdent("?:")
        property.name     = node[0][1].ident
        property.optional = true
        validTypesNode    = node[0][2]
        optionsNode       = node[1].expect(nnkPar)
      
      else: discard
    
    property.validTypes = parseValidTypes(validTypesNode)
    
    for option in optionsNode:
      option.expect({ nnkIdent, nnkAsgn, nnkExprEqExpr })
      property.options.add:
        if option.kind == nnkIdent: OptionEntry(source: option, name: $option.ident)
        else: OptionEntry(source: option, name: $option[0].ident, value: option[1])
    
    typeDef.properties.add(property)

proc parseRootEntry(context: var SchemaParseContext, node: NimNode) =
  node.expect({ nnkCall, nnkCommand })
  let name = node[0].ident
  var statements: NimNode
  var extends: Option[string]
  
  if node.kind == nnkCall:
    # Parse a Call with single Ident, BracketExpr or Infix as an alias.
    if node[1].len == 1 and node[1][0].kind in { nnkIdent, nnkBracketExpr, nnkInfix }:
      context.aliases.add(AliasEntry(source: node[1][0], name: name,
                                     validTypes: parseValidTypes(node[1][0])))
      return
    
    statements = node[1].expect(nnkStmtList)
  else:
    node[1][0].expectIdent("extends")
    statements = node[2].expect(nnkStmtList)
    extends = node[1][1].ident.some
  
  var typeDef = SchemaTypeDef(source: node, name: name, extends: extends, properties: @[])
  context.parseProperties(typeDef, statements)
  context.typeDefs.add(typeDef)


proc makeTypes(context: SchemaParseContext): NimNode =
  result = nnkTypeSection.newTree()
  
  proc makeType(validTypes: seq[ValidType], optional = false): NimNode =
    ## Turns a sequence of types into either just that type if it's a
    ## single one, or an Either, optionally wrapping them in an Option type.
    result = if validTypes.len > 1:
        let typeIdent = ("Either" & $validTypes.len).ident
        nnkBracketExpr.newTree(@[ typeIdent ].concat(validTypes.map(t => t.source)))
      else: validTypes[0].source
    if optional: result = nnkBracketExpr.newTree("Option".ident, result)
  
  proc exportIdent(s: string): NimNode =
    nnkPostfix.newTree("*".ident, s.ident)
  
  for alias in context.aliases:
    var params = makeType(alias.validTypes)
    
    result.add(nnkTypeDef.newTree(
      exportIdent(alias.name), # Type name
      newEmptyNode(),          # No generic params
      params))                 # Object parameters
  
  for typeDef in context.typeDefs:
    let pragmas = nnkPragma.newTree("inheritable".ident)
    
    let extends = typeDef.extends.
      map(x => nnkOfInherit.newTree(x.ident)).
      get(newEmptyNode())
    
    var params = newNimNode(nnkRecList)
    for prop in typeDef.properties:
      params.add(nnkIdentDefs.newTree(
        exportIdent(prop.name),
        makeType(prop.validTypes, prop.optional),
        newEmptyNode()))
    
    result.add(nnkTypeDef.newTree(
      exportIdent(typeDef.name), # Type name
      newEmptyNode(),            # No generic params
      nnkObjectTy.newTree(       # Object parameters
        pragmas, extends, params)))


macro jsonschema*(pattern: untyped): untyped =
  var context = SchemaParseContext(aliases: @[], typeDefs: @[])
  for node in pattern: context.parseRootEntry(node)
  result = newStmtList(context.makeTypes())
  # echo $repr(result)

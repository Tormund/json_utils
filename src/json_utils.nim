import json, strformat, strutils, algorithm

type Pair = tuple
  key: string
  node: JsonNode

proc dot(k1, k2: string): string =
  if k1.len == 0:
    result = k2
  else:
    result = k1 & "." & k2

proc flat*(j: JsonNode, prefix = "", flatArrays: bool = false, objDepth: int = -1): JsonNode =
  var rPairs: seq[Pair]
  var nodesToProcess: seq[Pair]
  nodesToProcess.add((key: prefix, node: j))
  var nextNodes: seq[Pair]
  var depth: int
  while nodesToProcess.len > 0:
    nextNodes.setLen(0)
    for pair in nodesToProcess:
      var (key, n) = pair
      if n.kind == JObject and (objDepth == -1 or depth < objDepth):
        for k, v in n:
          nextNodes.add((key: key.dot(k), node: v))
      elif n.kind == JArray and flatArrays:
        var idx = 0
        for v in n:
          nextNodes.add((key: key.dot(fmt"[{idx}]"), node: v))
          inc idx
      else:
        rPairs.add((key, n))
    nodesToProcess = nextNodes
    inc depth

  # rPairs.sort do(p1, p2: Pair) -> int:
  #   result = cmp(p1.key, p2.key)

  result = newJObject()
  for pair in rPairs:
    result[pair.key] = pair.node.copy

proc unflat*(j: JsonNode): JsonNode =
  result = newJObject()
  for keys, v in j:
    let sk = keys.split(".")
    var r = result
    for i, k in sk:
      if i == sk.len - 1:
        r[k] = v
      else:
        if k notin r:
          r[k] = newJObject()
        r = r[k]

proc genPatchFrom*(sourceJ, fromJ: JsonNode): JsonNode =
  var flat1 = fromJ.flat()
  var flat2 = sourceJ.flat()
  var r = newJObject()

  for k, v in flat1:
    if k notin flat2:
      r[k] = v.copy
    elif v != flat2[k]:
      r[k] = v.copy

  for k, v in flat2:
    if k notin flat1:
      r[k] = v.copy
  result = r.unflat()

proc patch*(j, patch: JsonNode): JsonNode =
  var flat1 = j.flat()
  var flat2 = patch.flat()
  for k, v in flat2:
    flat1[k] = v.copy

  result = flat1.unflat()

proc exclude*(j: JsonNode, keys: openarray[string]): JsonNode =
  result = newJObject()
  for k, v in j:
    if k notin keys:
      result[k] = v.copy


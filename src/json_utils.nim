import json, strformat, strutils, algorithm

type Pair = tuple
  key: string
  node: JsonNode

proc dot(k1, k2: string): string =
  if k1.len == 0:
    result = k2
  else:
    result = k1 & "." & k2

type PairsResult = proc(pairs: openarray[Pair]): JsonNode

proc defaultFlatResult(pairs: openarray[Pair]): JsonNode =
  result = newJObject()
  for pair in pairs:
    result[pair.key] = pair.node.copy

proc flatAUX(j: JsonNode, prefix = "", flatArrays: bool = false, objDepth: int = -1, pairsResult: PairsResult): JsonNode =
  var rPairs: seq[Pair]
  var nodesToProcess: seq[Pair]
  nodesToProcess.add((key: prefix, node: j))
  var nextNodes: seq[Pair]
  var depth: int
  while nodesToProcess.len > 0:
    nextNodes.setLen(0)
    for pair in nodesToProcess:
      if pair.node.kind == JObject and (objDepth == -1 or depth < objDepth):
        for k, v in pair.node:
          nextNodes.add((key: pair.key.dot(k), node: v))
      elif pair.node.kind == JArray and flatArrays:
        var idx = 0
        for v in pair.node:
          nextNodes.add((key: pair.key.dot(fmt"[{idx}]"), node: v))
          inc idx
      else:
        rPairs.add(pair)
    nodesToProcess = nextNodes
    inc depth

  result = pairsResult(rPairs)

proc flat*(j: JsonNode, prefix = "", flatArrays: bool = false, objDepth: int = -1, flatResult = defaultFlatResult): JsonNode =
  result = j.flatAUX(prefix, flatArrays, objDepth, flatResult)

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

proc patch*(j, patch: JsonNode): JsonNode =
  var flat1 = j.flat()
  var flat2 = patch.flat()
  for k, v in flat2:
    flat1[k] = v.copy

  result = flat1.unflat()

proc getDiff*(j1,j2: JsonNode): JsonNode =
  if j1 == j2: return nil

  if j1.kind != j2.kind:
    return j2

  if j1.kind != JObject:
    return j2

  for k, v in j2:
    if k notin j1:
      if result.isNil:
        result = newJObject()
      result[k] = v
    else:
      let d = getDiff(j1[k], v)
      if not d.isNil:
        if result.isNil:
          result = newJObject()
        result[k] = d

proc getPatchFrom*(sourceJ, fromJ: JsonNode): JsonNode =
  result = getDiff(sourceJ, fromJ)
  if result.isNil:
    return newJObject()

proc excludeAUX(j: JsonNode, k: openarray[string]) =
  if k.len == 0: return
  if j.kind != JObject: return
  if k[0] notin j: return
  if k.len == 1:
    j.delete(k[0])
  elif k[0] == "*":
    for _, v in j:
      v.excludeAUX(k[1 .. ^1])
  else:
    j[k[0]].excludeAUX(k[1 .. ^1])

proc exclude*(j: JsonNode, keys: openarray[string]) =
  for k in keys:
    j.excludeAUX(k.split("."))

import times

proc excludeCopy*(j: JsonNode, keys: openarray[string]): JsonNode =
  result = j.copy()
  result.exclude(keys)

proc flatSorted*(j: JsonNode, prefix = "", flatArrays: bool = false, objDepth: int = -1, cmp: proc(k1,k2: string):int = system.cmp): JsonNode =
  result = j.flatAUX(prefix, flatArrays, objDepth) do(pairs: openarray[Pair])->JsonNode:
    var pairs = @pairs
    pairs.sort do(p1, p2: Pair) -> int:
      result = cmp(p1.key, p2.key)
    result = newJObject()
    for pair in pairs:
      result[pair.key] = pair.node.copy

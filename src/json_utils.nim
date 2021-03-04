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

proc match(k, mask: string): bool =
  if mask.len > k.len: return false
  var ki, mi: int
  result = true
  while mi < mask.len:
    if mask[mi] == '*':
      while ki < k.len and k[ki] != '.':
        inc ki
      inc mi
    if mask[mi] != k[ki]:
      result = false
    if ki >= k.len - 1: break
    inc ki
    inc mi

proc matchAny(k: string, masks: openarray[string]): bool =
  for mask in masks:
    if k.match(mask):
      return true

proc flatWithExclude(j: JsonNode, keys: openarray[string]): JsonNode =
  let keys = @keys
  result = j.flatAUX("", true, -1) do(pairs: openarray[Pair])->JsonNode:
    result = newJObject()
    for pair in pairs:
      if not pair.key.matchAny(keys):
        result[pair.key] = pair.node.copy

proc excludeEx*(j: JsonNode, keys: openarray[string]): JsonNode =
  var fj = j.flatWithExclude(keys)
  result = fj.unflat()

proc flatSorted*(j: JsonNode, prefix = "", flatArrays: bool = false, objDepth: int = -1, cmp: proc(k1,k2: string):int = system.cmp): JsonNode =
  result = j.flatAUX(prefix, flatArrays, objDepth) do(pairs: openarray[Pair])->JsonNode:
    var pairs = @pairs
    pairs.sort do(p1, p2: Pair) -> int:
      result = cmp(p1.key, p2.key)
    result = newJObject()
    for pair in pairs:
      result[pair.key] = pair.node.copy

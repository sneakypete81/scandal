_ = require("underscore")
fs = require("fs")
{EventEmitter} = require("events")
readFile = require("./read-file")

MAX_LINE_LENGTH = 100
WORD_BREAK_REGEX = /[ \n\t;:?=&\/]/

module.exports =
class PathSearcher extends EventEmitter

  constructor: ({@maxLineLength, @wordBreakRegex}={}) ->
    @maxLineLength ?= MAX_LINE_LENGTH
    @wordBreakRegex ?= WORD_BREAK_REGEX

  searchPaths: (regex, paths, doneCallback) ->
    results = null
    searches = 0

    for filePath in paths
      @searchPath regex, filePath, (pathResult) ->
        if pathResult
          results ?= []
          results.push(pathResult)

        doneCallback(results) if ++searches == paths.length

  searchPath: (regex, path, doneCallback) ->
    matches = null

    readFile path, (lines, lineNumber) =>
      for line in lines
        lineMatches = @searchLine(regex, line, lineNumber)

        if lineMatches?
          matches ?= []
          matches.push(match) for match in lineMatches

        lineNumber++

    if matches?.length
      output = {path, matches}
      @emit('results-found', output)

    doneCallback(output)

  searchLine: (regex, line, lineNumber) ->
    matches = null
    lineTextOffset = 0

    while(regex.test(line))
      lineTextOffset = 0
      lineTextLength = line.length
      matchLength = RegExp.lastMatch.length
      matchIndex = regex.lastIndex - matchLength
      matchEndIndex = regex.lastIndex

      if lineTextLength < @maxLineLength
        lineText = line
      else
        lineTextOffset = Math.round(matchIndex - (@maxLineLength - matchLength) / 2)
        lineTextEndOffset = lineTextOffset + @maxLineLength

        if lineTextOffset <= 0
          lineTextOffset = 0
          lineTextEndOffset = @maxLineLength
        else if lineTextEndOffset > lineTextLength - 2
          lineTextEndOffset = lineTextLength - 1
          lineTextOffset = lineTextEndOffset - @maxLineLength

        lineTextOffset = @findWordBreak(line, lineTextOffset, -1)
        lineTextEndOffset = @findWordBreak(line, lineTextEndOffset, 1) + 1

        lineTextLength = lineTextEndOffset - lineTextOffset
        lineText = line.substr(lineTextOffset, lineTextLength)

      matches ?= []
      matches.push
        matchText: RegExp.lastMatch
        lineText: lineText
        lineTextOffset: lineTextOffset
        range: [[lineNumber, matchIndex], [lineNumber, matchEndIndex]]

    regex.lastIndex = 0
    matches

  findWordBreak: (line, offset, increment) ->
    i = offset
    len = line.length
    maxIndex = len - 1

    while i < len and i >= 0
      checkIndex = i + increment
      return i if @wordBreakRegex.test(line[checkIndex])
      i = checkIndex

    return 0 if i < 0
    return maxIndex if i > maxIndex

"use strict"

###
Meaty bits yanked from: https://github.com/eknkc/typescript-require/
With a tip of the hat to: https://github.com/joshheyse/typescript-brunch/
###

fs = require "fs"
path = require "path"

logger = require "logmimosa"

io = require "./assets/io"
TypeScript = require "./assets/tsc.js"
JSCompiler = require "./javascript"

module.exports = class TypeScriptCompiler extends JSCompiler

  @prettyName        = "TypeScript - http://www.typescriptlang.org"
  @defaultExtensions = ["ts"]

  constructor: (config, @extensions) ->
    super()
    @sourceUnitPath = path.join __dirname, "assets", "lib.d.ts"
    @sourceUnitText = fs.readFileSync @sourceUnitPath, "utf-8"

    TypeScript.codeGenTarget = TypeScript.CodeGenTarget.ES5
    if config.typescript?.module?
      if config.typescript.module is "commonjs"
        TypeScript.moduleGenTarget = TypeScript.ModuleGenTarget.Synchronous
      else if config.typescript.module is "amd"
        TypeScript.moduleGenTarget = TypeScript.ModuleGenTarget.Asynchronous

  compile: (file, cb) ->
    outText = ""
    outTextAssembler =
      Write: (str) -> outText += str
      WriteLine: (str) -> outText += str + '\r\n'
      Close: ->

    errorMessage = ""
    stderr =
      Write: (str) -> errorMessage += str
      WriteLine: (str) -> errorMessage += str
      Close: ->

    compiler = new TypeScript.TypeScriptCompiler(outTextAssembler, outTextAssembler, new TypeScript.NullLogger())
    compiler.setErrorOutput stderr
    compiler.parser.errorRecovery = true
    env = new TypeScript.CompilationEnvironment({resolve:true}, io)
    resolver = new TypeScript.CodeResolver(env)
    compiler.addUnit @sourceUnitText, @sourceUnitPath, false
    compiler.addUnit file.inputFileText, file.inputFileName, false

    units = []

    inputFile = TypeScript.switchToForwardSlashes file.inputFileName
    resolver.resolveCode inputFile, "", false,
      postResolution: (f, code) =>
        depPath = TypeScript.switchToForwardSlashes code.path
        if(!(units.some (u) -> u.fileName is depPath))
          units.push {fileName: depPath, code: code.content}
      postResolutionError: (f, message) ->
        errorMessage += "TypeScript Error: " + message + "\n File: " + f

    units.forEach (u) =>
      unless u.fileName is inputFile
        u.code = fs.readFileSync(u.fileName, "utf8") unless u.code
        compiler.addUnit u.code, u.fileName, false

    compiler.setErrorOutput stderr
    compiler.typeCheck()
    compiler.emit false

    error = if errorMessage.length > 0
      new Error(errorMessage)
    else
      null

    if /.d.ts$/.test(file.inputFileName) and outText is ""
      outText = undefined
      unless error
        logger.success "Compiled [[ #{file.inputFileName} ]]"

    cb(error, outText)
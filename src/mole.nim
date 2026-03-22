import std/[strutils, re, syncio]


var variableCharacters = re"^[a-zA-Z]"

var keywords = [
    "fn",
    "loop",
    "print",
    "true",
    "false",
    "return"
]

type
    TokenType = enum
        rootProgram,
        blockNodeDef,
        paramBlockNodeDef,
        varDefinitionNodeDef,
        leftBracket,
        rightBracket,
        identifier,
        literal,
        boolLiteral,
        numberLiteral
        stringLiteral,
        funcDef,
        varDef,
        funcIdentifierDef,
        loopDef,
        printDef,
        operator,
        returnBlock
    SourcePos = object
        line: int
        col:  int
    Token = object
        value:     string
        tokenType: TokenType
        pos:       SourcePos
    NodeRef = ref Node
    Node = object
        id: NodeRef
        parent: NodeRef
        value: string
        valueType: string
        nodeType: TokenType
        params: seq[NodeRef]
        children: seq[NodeRef]

var tokens: seq[Token]
var errors: seq[string]
var
    id = ""
    strLiteral = ""
    numLiteral = ""
    stringStack: seq[string]
    bracesStack: seq[string]
    flowerStack: seq[string]

proc debug(msg: string) =
    # echo "[debug]"&msg
    return

proc isKeyword(identifier: string): bool =
    for keywd in keywords:
        if identifier == keywd:
            return true
    return false

proc handleKeywordIdentifiers(identifier: string, pos: SourcePos) =
    case identifier:
        of "loop":
            tokens.add(
                Token(
                    value: id,
                    tokenType: loopDef,
                    pos: pos
                )
            )
        of "print":
            tokens.add(
                Token(
                    value: id,
                    tokenType: printDef,
                    pos: pos
                )
            )
        of "fn":
            tokens.add(
                Token(
                    value: id,
                    tokenType: funcDef,
                    pos: pos
                )
            )
        of "true","false":
            tokens.add(
                Token(
                    value: identifier,
                    tokenType: boolLiteral,
                    pos: pos
                )
            )
        of "return":
            tokens.add(
                Token(
                    value: "",
                    tokenType: returnBlock,
                    pos: pos
                )
            )
        else:
            return

proc characterAnalyse(line: string, lineNum: int) =
    if len(line) == 0:
        return

    var tokenStartCol = 0

    for i, chr in line:
        case chr:
            of '+','-','/','*','%':
                 tokens.add(
                        Token(
                            value: $chr,
                            tokenType: operator,
                            pos: SourcePos(line: lineNum, col: i)
                        )
                    )
            of '"':
                debug "found string declaration"
                if stringStack.len > 0:
                    discard stringStack.pop()
                    tokens.add(
                        Token(
                            value: strLiteral,
                            tokenType: stringLiteral,
                            pos: SourcePos(line: lineNum, col: tokenStartCol)
                        )
                    )
                    strLiteral = ""
                else:
                    tokenStartCol = i
                    stringStack.add($chr)
            of '(':
                debug "adding to braces"
                bracesStack.add($chr)
                tokens.add(
                    Token(
                        value: $chr,
                        tokenType: leftBracket,
                        pos: SourcePos(line: lineNum, col: i)
                    )
                )

            of '{':
                debug "adding flower brace"
                flowerStack.add($chr)
                debug $flowerStack.len
                tokens.add(
                    Token(
                        value: $chr,
                        tokenType: leftBracket,
                        pos: SourcePos(line: lineNum, col: i)
                    )
                )

            of ')':
                debug "found ending brace,popping"
                if bracesStack.len == 0:
                    errors.add("error: line " & $lineNum & ", col " & $i & ": unmatched ')'")
                else:
                    discard bracesStack.pop()
                tokens.add(
                    Token(
                        value: $chr,
                        tokenType: rightBracket,
                        pos: SourcePos(line: lineNum, col: i)
                    )
                )

            of '}':
                debug "found ending flower brace,popping"
                debug $flowerStack
                if flowerStack.len == 0:
                    errors.add("error: line " & $lineNum & ", col " & $i & ": unmatched '}'")
                else:
                    discard flowerStack.pop()
                tokens.add(
                    Token(
                        value: $chr,
                        tokenType: rightBracket,
                        pos: SourcePos(line: lineNum, col: i)
                    )
                )
            of ':':
                if i+1 <= line.len-1 and line[i+1] == '=':
                    tokens.add(
                        Token(
                            value: ":=",
                            tokenType: varDef,
                            pos: SourcePos(line: lineNum, col: i)
                        )
                    )
            else:
                # possibly inside a string, let it take up
                # everything till the end of string
                if stringStack.len > 0:
                    strLiteral = strLiteral & $chr
                    debug "strLiteral:" & strLiteral
                elif match($chr, re"\d"):
                    if numLiteral.len == 0:
                        tokenStartCol = i
                    numLiteral = numLiteral & $chr
                    if i+1 > line.len-1:
                        tokens.add(
                                Token(
                                    value: numLiteral,
                                    tokenType: numberLiteral,
                                    pos: SourcePos(line: lineNum, col: tokenStartCol)
                                )
                            )
                        numLiteral = ""
                    elif i+1 < line.len and not match($line[i+1], re"\d"):
                        tokens.add(
                                Token(
                                    value: numLiteral,
                                    tokenType: numberLiteral,
                                    pos: SourcePos(line: lineNum, col: tokenStartCol)
                                )
                            )
                        numLiteral = ""

                # if not then check if it's a variable that's
                # being used, mark as an identifier
                elif match($chr, variableCharacters):
                    if id.len == 0:
                        tokenStartCol = i
                    id = id & chr
                    if i+1 > line.len-1:
                        if isKeyword(id):
                            handleKeywordIdentifiers(id, SourcePos(line: lineNum, col: tokenStartCol))
                            id = ""
                        else:
                            tokens.add(
                                Token(
                                    value: id,
                                    tokenType: identifier,
                                    pos: SourcePos(line: lineNum, col: tokenStartCol)
                                )
                            )
                            id = ""
                    elif not match($line[i+1], variableCharacters):
                        if isKeyword(id):
                            handleKeywordIdentifiers(id, SourcePos(line: lineNum, col: tokenStartCol))
                            id = ""
                        else:
                            tokens.add(
                                Token(
                                    value: id,
                                    tokenType: identifier,
                                    pos: SourcePos(line: lineNum, col: tokenStartCol)
                                )
                            )
                            id = ""





proc printAST(ast: NodeRef, prefix: string = "-") =
    var printable = ""
    printable = printable & prefix & " " & $ast.nodeType
    if len(ast.value) > 0:
        printable = printable & " : " & ast.value
    echo printable
    for child in ast.children:
        printAST(child, prefix & "-")

proc constructAST():NodeRef =
    var program: NodeRef
    new(program)
    program.nodeType = rootProgram

    var nodeStack: seq[NodeRef]
    nodeStack.add(program)

    for i, tok in tokens:

        # cases where a bracket might remove the root node as well
        if nodeStack.len == 0:
            nodeStack.add(program)


        case tok.tokenType:
            of operator:
                var operatorNode: NodeRef
                new(operatorNode)
                operatorNode.value = tok.value
                operatorNode.nodeType = operator
                operatorNode.parent = nodeStack[nodeStack.high]
                operatorNode.parent.children.add(operatorNode)
                nodeStack.add(operatorNode)
            of leftBracket:
                var blockNode: NodeRef
                new(blockNode)

                if tok.value == "(":
                    blockNode.nodeType = paramBlockNodeDef
                if tok.value == "{":
                    blockNode.nodeType = blockNodeDef

                blockNode.parent = nodeStack[nodeStack.high]
                blockNode.parent.children.add(blockNode)
                nodeStack.add(blockNode)

            of rightBracket:
                if nodeStack.len < 2:
                    errors.add(
                        "error: line " & $tok.pos.line & ", col " & $tok.pos.col &
                        ": unexpected '" & tok.value & "'"
                    )
                else:
                    discard nodeStack.pop()
                    discard nodeStack.pop()

            of loopDef:
                var loopNode: NodeRef
                new(loopNode)
                loopNode.nodeType = loopDef
                loopNode.parent = nodeStack[nodeStack.high]
                loopNode.parent.children.add(
                    loopNode
                )
                nodeStack.add(loopNode)
            of returnBlock:
                var returnNode: NodeRef
                new(returnNode)
                returnNode.nodeType = returnBlock
                returnNode.parent = nodeStack[nodeStack.high]
                returnNode.parent.children.add(
                    returnNode
                )
                nodeStack.add(returnNode)
            of printDef:
                var printNode: NodeRef
                new(printNode)
                printNode.nodeType = printDef
                printNode.parent = nodeStack[nodeStack.high]
                printNode.parent.children.add(
                    printNode
                )
                nodeStack.add(printNode)
            of funcDef:
                var funcNode: NodeRef
                new(funcNode)
                funcNode.nodeType = funcDef
                funcNode.parent = nodeStack[nodeStack.high]
                funcNode.parent.children.add(
                    funcNode
                )
                nodeStack.add(funcNode)
            of varDef:
                var varDefNode: NodeRef
                new(varDefNode)
                varDefNode.nodeType = varDef
                varDefNode.parent = nodeStack[nodeStack.high]
                varDefNode.parent.children.add(
                    varDefNode
                )
                nodeStack.add(varDefNode)

                var varDefinitionNode: NodeRef
                new(varDefinitionNode)
                varDefinitionNode.nodeType = varDefinitionNodeDef
                varDefinitionNode.parent = nodeStack[nodeStack.high]
                varDefinitionNode.parent.children.add(
                    varDefinitionNode
                )
                nodeStack.add(varDefinitionNode)
            of identifier:
                var idNode: NodeRef
                new(idNode)
                idNode.nodeType = identifier
                idNode.value = tok.value
                idNode.parent = nodeStack[nodeStack.high]

                if idNode.parent.nodeType == funcDef:
                    idNode.nodeType = funcIdentifierDef

                idNode.parent.children.add(
                    idNode
                )

            of stringLiteral:
                var sLiteralNode: NodeRef
                new(sLiteralNode)
                sLiteralNode.nodeType = stringLiteral
                sLiteralNode.value = tok.value
                sLiteralNode.parent = nodeStack[nodeStack.high]

                if sLiteralNode.parent.nodeType == varDef:
                    discard nodeStack.pop()
                if sLiteralNode.parent.nodeType == varDefinitionNodeDef:
                    discard nodeStack.pop()
                    discard nodeStack.pop()

                sLiteralNode.parent.children.add(
                    sLiteralNode
                )
            of numberLiteral:
                var nLiteralNode: NodeRef
                new(nLiteralNode)
                nLiteralNode.nodeType = numberLiteral
                nLiteralNode.value = tok.value
                nLiteralNode.parent = nodeStack[nodeStack.high]
                nLiteralNode.parent.children.add(
                    nLiteralNode
                )
            of boolLiteral:
                var boolLiteralNode: NodeRef
                new(boolLiteralNode)
                boolLiteralNode.nodeType = boolLiteral
                boolLiteralNode.value = tok.value
                boolLiteralNode.parent = nodeStack[nodeStack.high]
                boolLiteralNode.parent.children.add(
                    boolLiteralNode
                )
            else:
                continue
                # echo "dancing"

    return program


proc nodeToLanguage(ast:NodeRef):string=
    var prog = ""
    case ast.nodeType:
        of operator:
            prog = "("
            for child in ast.children:
                var paramAdditions:seq[string]
                for paramChild in child.children:
                    if paramChild.nodeType == operator:
                        paramAdditions.add(nodeToLanguage(paramChild))
                    else:    
                        paramAdditions.add(paramChild.value)
                prog = prog & paramAdditions.join(ast.value)
            prog = prog & ")"
        of identifier:
            prog = ast.value
        of numberLiteral:
            prog = ast.value
        of stringLiteral:
            prog = "\""&ast.value&"\""
        of funcDef:
            prog = "function "
            for ch in ast.children:
                prog = prog & nodeToLanguage(ch)
        of printDef:
            prog = "console.log("
            for ch in ast.children:
                prog = prog & nodeToLanguage(ch)
            prog = prog & ");"
        of blockNodeDef:
            prog = "{"
            for ch in ast.children:
                prog = prog & nodeToLanguage(ch)
            prog = prog & "}"
        of paramBlockNodeDef:
            prog = "("
            var toAdd:seq[string] 
            for ch in ast.children:
                toAdd.add( nodeToLanguage(ch))
            prog = prog & toAdd.join(",") &  ")"
        of returnBlock:
            prog = "return "
            for ch in ast.children:
                prog = prog & nodeToLanguage(ch)
            prog = prog
        of funcIdentifierDef:
            prog = ast.value
        else:
            return prog        
    return prog

proc astToLanguage(ast:NodeRef):string=
    var program = ""
    
    for child in ast.children:
        program = program & nodeToLanguage(child)

    
    return program
                



proc main() =
    var
        fname = "./example/main.mole"
        output = "./example/main.js"

    var lineNum = 1
    for line in lines fname:
        if line.isEmptyOrWhitespace():
            inc lineNum
            continue

        if line.startsWith("--"):
            # ignore comment parsing for now
            inc lineNum
            continue
        else:
            characterAnalyse(line, lineNum)

        inc lineNum

    var ast = constructAST()

    if errors.len > 0:
        for err in errors:
            stderr.writeLine(err)
        quit 1

    var langOut = astToLanguage(ast)
    var file_handle = syncio.open(output, FileMode.fmReadWrite)
    syncio.write(file_handle, langOut)


main()

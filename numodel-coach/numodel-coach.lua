-- ====================================================================
-- numodel-coach.lua --- write numodel models as CMA Coach 7 files
-- numodel-coach.lua  v0.10.0  2026/10/08
-- ====================================================================
--
-- Copyright (C) 2026 Paul Zuurbier <mail@paulzuurbier.nl>
--
-- This work may be distributed and/or modified under the conditions
-- of the LaTeX Project Public License, either version 1.3c of this
-- license or (at your option) any later version.  The latest version
-- of this license is in https://www.latex-project.org/lppl.txt
--
-- This work has the LPPL maintenance status 'maintained'.
-- The Current Maintainer of this work is Paul Zuurbier.
--
-- This work consists of the files numodel-coach.dtx,
-- numodel-coach.ins, the derived file numodel-coach.sty, and the
-- companion Lua files numodel-coach.lua and numodel-coach-template.lua.
-- ====================================================================
-- Turns a numodel model into a Coach 7 modelling activity (.cma7) in
-- text mode.  The model text comes from numodel.plaintext (Coachtaal),
-- the model data from numodel.get_model; this file only knows the
-- Coach file format.
--
-- The format is not documented by CMA.  What is known (reverse
-- engineered from files saved by Coach 7.0):
--   * a 16-byte header starting with "CMA ", then records;
--   * container: u64 length, 0e 00 00 00 00, u8 name length, name,
--     children (length counts the whole record);
--   * leaf: u32 length, u32 0x0b, u8 name length, u8 flag, u8 type,
--     name, value.  Types: 0 byte, 2 int32, 3 80-bit extended,
--     4 ANSI (cp1252) text, 6 UTF-16LE text.  Every text is stored
--     twice: as name (ANSI) and name_uuuu (UTF-16).  Flag 1 marks an
--     unnamed long text, preceded by four zero bytes;
--   * no checksums.
-- Model-relevant records:
--   Description/CanSwitchModelModes  1 = pupil may switch between the
--       graphical and the text view.  The text view is derived from
--       the graphical model (ModelXML), so switching loses a text-only
--       model: numodel-coach switches it off by default.
--   GrModMain/Mode                   1 = text view
--   ModelXML                         graphical model; its <start>,
--       <stop> and <step> set the iteration count:
--       (stop - start)/step + 1
--   ModelBody, ModelInit             model rules, initial values
--   VarList                          variables shown in table/graphs
-- ====================================================================

local C = {}
numodelcoach = C

-- The template is found through kpse inside LuaTeX; standalone texlua
-- (the unit tests) sets C.template itself.
local ok, template_file = pcall(function()
    return kpse.find_file("numodel-coach-template.lua", "tex")
end)
C.template = ok and template_file and dofile(template_file) or nil

-- --- encoding ---------------------------------------------------------

-- UTF-8 -> UTF-16LE.
local function utf16le(s)
    local out = {}
    for _, cp in utf8.codes(s) do
        if cp >= 0x10000 then
            cp = cp - 0x10000
            local hi, lo = 0xD800 + (cp >> 10), 0xDC00 + (cp & 0x3FF)
            out[#out + 1] = string.pack("<I2I2", hi, lo)
        else
            out[#out + 1] = string.pack("<I2", cp)
        end
    end
    return table.concat(out)
end

-- UTF-8 -> cp1252 (Windows-1252), '?' for what it cannot hold -- the
-- same as Coach writes in its ANSI copies (Δt -> ?t).
local cp1252_high = {
    [0x20AC] = 0x80, [0x201A] = 0x82, [0x0192] = 0x83, [0x201E] = 0x84,
    [0x2026] = 0x85, [0x2020] = 0x86, [0x2021] = 0x87, [0x02C6] = 0x88,
    [0x2030] = 0x89, [0x0160] = 0x8A, [0x2039] = 0x8B, [0x0152] = 0x8C,
    [0x017D] = 0x8E, [0x2018] = 0x91, [0x2019] = 0x92, [0x201C] = 0x93,
    [0x201D] = 0x94, [0x2022] = 0x95, [0x2013] = 0x96, [0x2014] = 0x97,
    [0x02DC] = 0x98, [0x2122] = 0x99, [0x0161] = 0x9A, [0x203A] = 0x9B,
    [0x0153] = 0x9C, [0x017E] = 0x9E, [0x0178] = 0x9F,
}
local function cp1252(s)
    local out = {}
    for _, cp in utf8.codes(s) do
        if cp < 0x80 or (cp >= 0xA0 and cp <= 0xFF) then
            out[#out + 1] = string.char(cp)
        else
            out[#out + 1] = string.char(cp1252_high[cp] or 0x3F)
        end
    end
    return table.concat(out)
end

-- Number -> 80-bit x87 extended, little endian (Delphi "Extended").
local function ext80(x)
    if x == 0 then return string.rep("\0", 10) end
    local sign = x < 0 and 0x8000 or 0
    local m, e = math.frexp(math.abs(x))      -- x = m * 2^e, 0.5 <= m < 1
    local hi = math.floor(m * 2^32)            -- top 32 mantissa bits
    local lo = math.floor((m * 2^32 - hi) * 2^32)
    return string.pack("<I4I4I2", lo, hi, sign | (e - 1 + 16383))
end
C._ext80, C._utf16le, C._cp1252 = ext80, utf16le, cp1252

-- --- record tree ------------------------------------------------------

local function leaf(name, typ, value, flag)
    return { "l", name, flag or 0, typ, value }
end

-- A named text, stored as ANSI + _uuuu copies.
local function text_pair(name, s)
    return leaf(name, 4, cp1252(s)), leaf(name .. "_uuuu", 6, utf16le(s))
end

-- The unnamed long text that fills ModelBody, ModelInit, ModelXML.
local function long_text(s)
    return { leaf("", 4, "\0\0\0\0" .. cp1252(s), 1),
             leaf("_uuuu", 6, "\0\0\0\0" .. utf16le(s), 1) }
end

local function deep_copy(t)
    if type(t) ~= "table" then return t end
    local c = {}
    for k, v in pairs(t) do c[k] = deep_copy(v) end
    return c
end

local function find(items, name)
    for _, it in ipairs(items) do
        if it[1] == "c" and it[2] == name then return it end
    end
    error("numodel-coach: template has no record '" .. name .. "'")
end

local function find_leaf(items, name)
    for _, it in ipairs(items) do
        if it[1] == "l" and it[2] == name then return it end
    end
    error("numodel-coach: template has no field '" .. name .. "'")
end

local function serialise_items(items)
    local out = {}
    for _, it in ipairs(items) do
        local body
        if it[1] == "l" then
            local name = it[2]
            body = string.pack("<I4", 0x0b)
                .. string.char(#name, it[3], it[4]) .. name .. it[5]
            out[#out + 1] = string.pack("<I4", #body + 4) .. body
        else
            local name = it[2]
            local payload = it.raw or serialise_items(it[4])
            body = it[3] .. string.char(#name) .. name .. payload
            out[#out + 1] = string.pack("<I8", #body + 8) .. body
        end
    end
    return table.concat(out)
end

function C.serialise(tree)
    return tree.magic .. serialise_items(tree.items)
end

-- Parse a CMA file (bytes) into the same tree form; used by the tests
-- to read written files back.
local function parse_items(d, i, stop)
    local items = {}
    while i < stop do
        local len, kind = string.unpack("<I4I4", d, i)
        if kind == 0x0b then
            local nlen, flag, typ = d:byte(i + 8, i + 10)
            local name = d:sub(i + 11, i + 10 + nlen)
            items[#items + 1] = leaf(name, typ, d:sub(i + 11 + nlen, i + len - 1), flag)
            i = i + len
        else
            len = string.unpack("<I8", d, i)
            local hdr = d:sub(i + 8, i + 12)
            local nlen = d:byte(i + 13)
            local name = d:sub(i + 14, i + 13 + nlen)
            local first, last = i + 14 + nlen, i + len - 1
            local ok, kids = pcall(parse_items, d, first, last + 1)
            if ok then
                items[#items + 1] = { "c", name, hdr, kids }
            else
                items[#items + 1] = { "c", name, hdr, raw = d:sub(first, last) }
            end
            i = i + len
        end
    end
    if i ~= stop then error("record overrun") end
    return items
end

function C.parse(d)
    return { magic = d:sub(1, 16), items = parse_items(d, 17, #d + 1) }
end

-- --- instruction text --------------------------------------------------
-- The coachinstruction environment typesets its body in the PDF and
-- hands the same source (detokenized) to set_instruction, so the PDF
-- and Coach's instruction window share one source.  to_html converts a
-- deliberate subset of LaTeX into the HTML Coach shows (the tags CMA's
-- own activities use: p, b, i, u, sub, sup, br, plus ul/ol/li).
-- Anything else is reported; its argument text is kept.

local html_escape = { ["&"] = "&amp;", ["<"] = "&lt;", [">"] = "&gt;" }
local function esc(s) return (s:gsub("[&<>]", html_escape)) end

local text_symbols = {
    ldots = "…", dots = "…", textellipsis = "…", cdot = "·",
    times = "×", degree = "°", celsius = "°C", degreeCelsius = "°C",
    pm = "±", approx = "≈", leq = "≤", leqslant = "≤", geq = "≥",
    geqslant = "≥", neq = "≠", ne = "≠", to = "→", rightarrow = "→",
    infty = "∞", textendash = "–", textemdash = "—", euro = "€",
    percent = "%", quad = " ", qquad = "  ", space = " ",
}
-- Relations in math, set with spaces around them.
local math_relations = { leq = "≤", leqslant = "≤", geq = "≥",
    geqslant = "≥", neq = "≠", ne = "≠", approx = "≈", to = "→",
    rightarrow = "→", propto = "∝" }
local ignored = { noindent = true, medskip = true, smallskip = true,
    bigskip = true, centering = true, relax = true, ignorespaces = true,
    displaystyle = true, left = true, right = true }
local wrap_tags = { textbf = "b", bfseries = nil, emph = "i", textit = "i",
    textsl = "i", underline = "u", textsuperscript = "sup",
    textsubscript = "sub" }
local plain_groups = { text = true, textrm = true, textnormal = true,
    mbox = true, textsf = true, texttt = true, mathrm = true,
    mathit = true, mathbf = true, operatorname = true, textup = true }

-- Read one argument at s[i]: a braced group (returns its content) or a
-- single token.  Returns content and the index after it.
local function read_arg(s, i)
    i = s:find("%S", i) or #s + 1
    local c = s:sub(i, i)
    if c == "{" then
        local depth, j = 0, i
        while j <= #s do
            local d = s:sub(j, j)
            if d == "\\" then j = j + 1
            elseif d == "{" then depth = depth + 1
            elseif d == "}" then
                depth = depth - 1
                if depth == 0 then return s:sub(i + 1, j - 1), j + 1 end
            end
            j = j + 1
        end
        return s:sub(i + 1), #s + 1
    elseif c == "\\" then
        local cs = s:match("^\\%a+", i) or s:sub(i, i + 1)
        return cs, i + #cs
    end
    return c, i + 1
end

local function fmt_num(s, ctx)
    s = s:gsub("%s", "")
    return (s:gsub("(%d)%.(%d)", "%1" .. ctx.decimal .. "%2"))
end

-- Unit for display: m/s^2 -> m/s<sup>2</sup>.
local function unit_html(u)
    local p = numodel.plain_unit(u)
    return (esc(p):gsub("%^(%-?%d+)", "<sup>%1</sup>"))
end

local convert, convert_cmd

-- Math: letters italic, _ and ^ as sub/sup, \frac as a/b.
local function convert_math(s, ctx)
    local out, i = {}, 1
    local function emit(x) out[#out + 1] = x end
    while i <= #s do
        local c = s:sub(i, i)
        if c:match("%a") then
            local run = s:match("^%a+", i)
            emit("<i>" .. run .. "</i>"); i = i + #run
        elseif c == "_" or c == "^" then
            local a; a, i = read_arg(s, i + 1)
            local tag = c == "_" and "sub" or "sup"
            emit("<" .. tag .. ">" .. convert_math(a, ctx) .. "</" .. tag .. ">")
        elseif c == "{" then
            local a; a, i = read_arg(s, i)
            emit(convert_math(a, ctx))
        elseif c == "\\" then
            local cs = s:match("^\\(%a+)", i)
            if cs then
                i = i + 1 + #cs
                if plain_groups[cs] then
                    local a; a, i = read_arg(s, i)
                    emit(convert(a, ctx, false))
                elseif cs == "frac" or cs == "tfrac" or cs == "dfrac" then
                    local a, b; a, i = read_arg(s, i); b, i = read_arg(s, i)
                    local A, B = convert_math(a, ctx), convert_math(b, ctx)
                    if a:find("[%+%-%s]") then A = "(" .. A .. ")" end
                    if b:find("[%+%-%s]") then B = "(" .. B .. ")" end
                    emit(A .. "/" .. B .. " ")     -- 1/2 mv, not 1/2mv
                elseif cs == "sqrt" then
                    local a; a, i = read_arg(s, i)
                    emit("√(" .. convert_math(a, ctx) .. ")")
                elseif numodel.greek[cs] then emit(numodel.greek[cs])
                elseif math_relations[cs] then
                    emit(" " .. math_relations[cs] .. " ")
                elseif text_symbols[cs] then emit(text_symbols[cs])
                elseif cs == "qty" or cs == "SI" or cs == "num"
                    or cs == "unit" or cs == "si" then
                    i = i - 1 - #cs
                    local a; a, i = convert_cmd(s, i, ctx)
                    emit(a)
                elseif not ignored[cs] then
                    ctx.warn("instruction: unknown math command \\" .. cs)
                end
            else
                local sym = s:sub(i + 1, i + 1)
                i = i + 2
                if sym == "," or sym == ";" or sym == ":" then emit(" ")
                elseif sym ~= "!" then emit(esc(sym)) end
            end
        elseif c:match("%s") then
            i = i + 1                  -- TeX ignores spaces in math
        elseif c == "=" or c == "<" or c == ">" then
            emit(" " .. esc(c) .. " "); i = i + 1
        elseif c == "+" or c == "-" then
            -- Binary (spaced) after an operand, unary otherwise.
            local sym = c == "-" and "−" or "+"
            local prev = out[#out]
            if prev and not prev:match("[%s(]$") then
                emit(" " .. sym .. " ")
            else
                emit(sym)
            end
            i = i + 1
        else
            emit(esc(c)); i = i + 1
        end
    end
    return (table.concat(out):gsub("</i><i>", ""):gsub(" +", " "))
end

-- One control sequence at s[i] (the backslash).  Returns HTML and the
-- index after the command and its arguments.
convert_cmd = function(s, i, ctx)
    local cs = s:match("^\\(%a+)", i)
    if not cs then
        local sym = s:sub(i + 1, i + 1)
        if sym == "\\" then return "<br>", i + 2 end
        if sym == "," then return " ", i + 2 end
        if sym == "-" or sym == "/" then return "", i + 2 end
        return esc(sym), i + 2
    end
    i = i + 1 + #cs
    if s:sub(i, i) == " " then i = i + 1 end     -- detokenize space
    local a
    if wrap_tags[cs] then
        a, i = read_arg(s, i)
        local t = wrap_tags[cs]
        return "<" .. t .. ">" .. convert(a, ctx, false) .. "</" .. t .. ">", i
    elseif plain_groups[cs] then
        a, i = read_arg(s, i)
        return convert(a, ctx, false), i
    elseif cs == "qty" or cs == "SI" then
        local b
        a, i = read_arg(s, i); b, i = read_arg(s, i)
        return fmt_num(a, ctx) .. " " .. unit_html(b), i
    elseif cs == "num" then
        a, i = read_arg(s, i)
        return fmt_num(a, ctx), i
    elseif cs == "unit" or cs == "si" then
        a, i = read_arg(s, i)
        return unit_html(a), i
    elseif cs == "par" then return "\0P", i
    elseif cs == "newline" or cs == "linebreak" then return "<br>", i
    elseif cs == "item" then
        if s:match("^%s*%[", i) then
            local j = s:find("]", i, true) or i
            i = j + 1
        end
        return "\0I", i
    elseif cs == "begin" or cs == "end" then
        a, i = read_arg(s, i)
        local tag = (a == "itemize" and "ul") or (a == "enumerate" and "ol")
        if not tag then
            ctx.warn("instruction: environment " .. a .. " is not converted")
            return "", i
        end
        if cs == "begin" then return "\0P<" .. tag .. ">\0L", i end
        return "</li></" .. tag .. ">\0P", i
    elseif numodel.greek[cs] then return numodel.greek[cs], i
    elseif text_symbols[cs] then return text_symbols[cs], i
    elseif ignored[cs] then return "", i
    end
    ctx.warn("instruction: unknown command \\" .. cs .. "; its text is kept")
    if s:match("^%s*{", i) then
        a, i = read_arg(s, i)
        return convert(a, ctx, false), i
    end
    return "", i
end

-- Text mode.
convert = function(s, ctx)
    local out, i = {}, 1
    local function emit(x) out[#out + 1] = x end
    while i <= #s do
        local c = s:sub(i, i)
        if c == "\\" then
            if s:sub(i, i + 1) == "\\(" then
                local j = s:find("\\)", i + 2, true) or #s + 1
                emit(convert_math(s:sub(i + 2, j - 1), ctx)); i = j + 2
            else
                local h; h, i = convert_cmd(s, i, ctx); emit(h)
            end
        elseif c == "$" then
            local j = s:find("$", i + 1, true) or #s + 1
            emit(convert_math(s:sub(i + 1, j - 1), ctx)); i = j + 1
        elseif c == "{" then
            local a; a, i = read_arg(s, i); emit(convert(a, ctx, false))
        elseif c == "}" then i = i + 1
        elseif c == "~" then emit(" "); i = i + 1
        elseif s:sub(i, i + 2) == "---" then emit("—"); i = i + 3
        elseif s:sub(i, i + 1) == "--" then emit("–"); i = i + 2
        elseif s:sub(i, i + 1) == "``" then emit("“"); i = i + 2
        elseif s:sub(i, i + 1) == "''" then emit("”"); i = i + 2
        elseif c == "%" then
            i = (s:find("\n", i, true) or #s) + 1     -- comment
        else
            emit(esc(c)); i = i + 1
        end
    end
    return table.concat(out)
end

-- LaTeX source (detokenized) -> { html = ..., text = ... }.  decimal is
-- the decimal mark for \num/\qty (default ",").
function C.instruction_html(src, decimal, warn)
    local ctx = { decimal = decimal or ",", warn = warn or function() end }
    local raw = convert(src, ctx)
    -- \item markers: first one after <ul>/<ol> opens the item.
    raw = raw:gsub("\0L%s*\0I", "<li>"):gsub("\0I", "</li><li>")
        :gsub("\0L", "<li>")
    local blocks = {}
    for chunk in (raw .. "\0P"):gmatch("(.-)\0P") do
        chunk = chunk:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
        chunk = chunk:gsub("<li> ", "<li>"):gsub(" </li>", "</li>")
        if chunk ~= "" then
            if chunk:match("^<[uo]l>") then blocks[#blocks + 1] = chunk
            else blocks[#blocks + 1] = "<p>" .. chunk .. "</p>" end
        end
    end
    local html = "<body>" .. table.concat(blocks) .. "</body>"
    local text = html:gsub("<li>", "- "):gsub("</p>", "\n")
        :gsub("</li>", "\n"):gsub("<br>", "\n"):gsub("<[^>]+>", "")
        :gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&")
    return { html = html, text = (text:gsub("\n+$", "")) }
end

-- Instructions stored per model prefix by the coachinstruction
-- environment, used by the next \coachmodel for that prefix.
C.instructions = {}

function C.set_instruction(p, src)
    C.instructions[p] = src
end

-- --- building an activity ---------------------------------------------

-- spec = {
--   body, init        model rules / initial values (UTF-8 text),
--   variables = { { name, unit, min, max, decimals }, ... },
--   iterations        number of iterations (>= 1),
--   allow_switch      true: pupils may switch to the graphical view
--   instruction       optional { html = ..., text = ... } for Coach's
--                     instruction window (see instruction_html)
-- }
function C.build(spec)
    if not C.template then
        error("numodel-coach: cannot find numodel-coach-template.lua")
    end
    local tree = deep_copy(C.template)
    local items = tree.items

    local desc = find(items, "Description")[4]
    find_leaf(desc, "CanSwitchModelModes")[5] =
        string.char(spec.allow_switch and 1 or 0)
    find_leaf(find(items, "GrModMain")[4], "Mode")[5] = "\1"

    if spec.instruction then
        find(items, "NewText\0Instructie")[4] = long_text(spec.instruction.text)
        find(items, "HTMLText\0Instructie")[4] = long_text(spec.instruction.html)
    end

    find(items, "ModelBody")[4] = long_text(spec.body)
    find(items, "ModelInit")[4] = long_text(spec.init)

    local vl = { leaf("Number", 2, string.pack("<i4", #spec.variables)) }
    for n, v in ipairs(spec.variables) do
        local a, b = text_pair("Name" .. n, v.name)
        local c, d = text_pair("Label" .. n, v.name)
        local e, f = text_pair("Unit" .. n, v.unit or "")
        for _, x in ipairs({ a, b, c, d, e, f }) do vl[#vl + 1] = x end
        vl[#vl + 1] = leaf("Min" .. n, 3, ext80(v.min or 0))
        vl[#vl + 1] = leaf("Max" .. n, 3, ext80(v.max or 10))
        vl[#vl + 1] = leaf("Decimals" .. n, 0, string.char(v.decimals or 2))
    end
    find(items, "VarList")[4] = vl

    -- Iteration count: (stop - start)/step + 1 with start 0, step 1.
    -- A text model sets its own time step in the initial values, so
    -- <step> has no other role.
    local xml_rec = find(items, "ModelXML")
    local xml = xml_rec[4][1][5]:sub(5)            -- ANSI copy, CRLF
    local n = math.max(1, math.floor(spec.iterations or 101))
    local function set(tag, val)
        xml = xml:gsub("<" .. tag .. ">[^<]*</" .. tag .. ">",
            "<" .. tag .. ">" .. val .. "</" .. tag .. ">", 1)
    end
    set("start", "0"); set("stop", tostring(n - 1)); set("step", "1")
    xml_rec[4] = long_text(xml)

    return C.serialise(tree)
end

-- --- from a numodel model ----------------------------------------------

-- Build the activity for numodel prefix p.  Returns the file contents
-- and the list of warnings (things that could not be exported
-- exactly).  opts.allow_switch as in build.
function C.from_model(p, opts)
    opts = opts or {}
    local g = numodel.get_model(p)
    if not g then error("numodel-coach: unknown model prefix '" .. p .. "'") end
    local r = numodel.plaintext(p, { dialect = "NL" })
    local W = {}
    for _, w in ipairs(r.warnings) do W[#W + 1] = w end
    local vars = {}
    for _, v in ipairs(g.vars) do
        local unit, w = numodel.plain_unit(v.unit)
        -- Units of variables with a start value were already checked
        -- by plaintext (they appear as comments there).
        if w and not v.has_start then W[#W + 1] = w end
        -- Coach's axis range for the variable: the range of its
        -- graph in the document (\diagrammodel), else Coach's 0..10.
        vars[#vars + 1] = { name = r.names[v.name], unit = unit,
            min = v.axis_min, max = v.axis_max }
    end
    local instruction
    if C.instructions[p] then
        instruction = C.instruction_html(C.instructions[p], ",",
            function(w) W[#W + 1] = w end)
    end
    local data = C.build({
        body = r.body, init = r.init, variables = vars,
        iterations = g.maxiter, allow_switch = opts.allow_switch,
        instruction = instruction,
    })
    return data, W
end

-- Write the activity for prefix p to path, creating the directory if
-- needed.  Returns the list of warnings.
function C.write(p, path, opts)
    local data, W = C.from_model(p, opts)
    local dir = path:match("^(.*)/[^/]*$")
    if dir and dir ~= "" and lfs and not lfs.isdir(dir) then
        local acc = path:sub(1, 1) == "/" and "" or nil
        for part in dir:gmatch("[^/]+") do
            acc = acc and (acc .. "/" .. part) or part
            if not lfs.isdir(acc) then lfs.mkdir(acc) end
        end
    end
    local f, err = io.open(path, "wb")
    if not f then error("numodel-coach: cannot write " .. path .. ": " .. tostring(err)) end
    f:write(data)
    f:close()
    return W
end

-- Called by \coachmodel: write the file and hand every warning to
-- TeX as \numodelcoachwarn{prefix}{path}{text}.  The text is passed
-- with catcode "other" (tex.sprint -2), so braces or backslashes in it
-- are harmless.
function C.tex_write(p, path, allow_switch)
    if not numodel.get_model(p) then
        tex.sprint("\\numodelcoachnomodel{")
        tex.sprint(-2, p)
        tex.sprint("}")
        return
    end
    local W = C.write(p, path, { allow_switch = allow_switch })
    for _, w in ipairs(W) do
        tex.sprint("\\numodelcoachwarn{")
        tex.sprint(-2, p)
        tex.sprint("}{")
        tex.sprint(-2, path)
        tex.sprint("}{")
        tex.sprint(-2, w)
        tex.sprint("}")
    end
    tex.sprint("\\numodelcoachwritten{")
    tex.sprint(-2, path)
    tex.sprint("}")
end

-- Readable summary of a written file (tests, debugging): the parts
-- numodel-coach fills in.
function C.dump(data)
    local tree = C.parse(data)
    local items, out = tree.items, {}
    local function utf16(s)
        local cps, i = {}, 1
        while i + 1 <= #s do
            cps[#cps + 1] = string.unpack("<I2", s, i); i = i + 2
        end
        return utf8.char(table.unpack(cps))
    end
    local desc = find(items, "Description")[4]
    out[#out + 1] = "CanSwitchModelModes=" .. find_leaf(desc, "CanSwitchModelModes")[5]:byte()
    out[#out + 1] = "Mode=" .. find_leaf(find(items, "GrModMain")[4], "Mode")[5]:byte()
    local xml = find(items, "ModelXML")[4][1][5]:sub(5)
    for _, tag in ipairs({ "start", "stop", "step" }) do
        out[#out + 1] = tag .. "=" .. xml:match("<" .. tag .. ">([^<]*)<")
    end
    out[#out + 1] = "Instruction text:"
    out[#out + 1] = utf16(find(items, "NewText\0Instructie")[4][2][5]:sub(5))
    out[#out + 1] = "Instruction HTML:"
    out[#out + 1] = utf16(find(items, "HTMLText\0Instructie")[4][2][5]:sub(5))
    out[#out + 1] = "ModelBody:"
    out[#out + 1] = utf16(find(items, "ModelBody")[4][2][5]:sub(5))
    out[#out + 1] = "ModelInit:"
    out[#out + 1] = utf16(find(items, "ModelInit")[4][2][5]:sub(5))
    out[#out + 1] = "VarList:"
    for _, it in ipairs(find(items, "VarList")[4]) do
        local name, typ, v = it[2], it[4], it[5]
        if not name:find("_uuuu$") then
            local s
            if typ == 6 then s = utf16(v)
            elseif typ == 4 then s = v
            elseif typ == 2 then s = tostring(string.unpack("<i4", v))
            elseif typ == 0 then s = tostring(v:byte())
            else
                local lo, hi, se = string.unpack("<I4I4I2", v)
                local e = (se & 0x7FFF) - 16383
                local x = (hi * 2^32 + lo) / 2^63 * 2^e
                s = tostring((se & 0x8000) ~= 0 and -x or x)
            end
            out[#out + 1] = "  " .. name .. "=" .. s
        end
    end
    return table.concat(out, "\n") .. "\n"
end

return C

-- ====================================================================
-- numodel-coach.lua --- write numodel models as CMA Coach 7 files
-- numodel-coach.lua  v0.12.0  2026/10/28
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
-- LaTeX accents and special letters (\"u, \'e, \c{c}, \ss).
local accents = {
    ['"'] = { a = "ä", e = "ë", i = "ï", o = "ö", u = "ü", y = "ÿ",
              A = "Ä", E = "Ë", I = "Ï", O = "Ö", U = "Ü" },
    ["'"] = { a = "á", e = "é", i = "í", o = "ó", u = "ú", y = "ý",
              A = "Á", E = "É", I = "Í", O = "Ó", U = "Ú", c = "ć",
              n = "ń", s = "ś", z = "ź" },
    ["`"] = { a = "à", e = "è", i = "ì", o = "ò", u = "ù",
              A = "À", E = "È", I = "Ì", O = "Ò", U = "Ù" },
    ["^"] = { a = "â", e = "ê", i = "î", o = "ô", u = "û",
              A = "Â", E = "Ê", I = "Î", O = "Ô", U = "Û" },
    ["~"] = { a = "ã", n = "ñ", o = "õ", A = "Ã", N = "Ñ", O = "Õ" },
    c     = { c = "ç", C = "Ç", s = "ş", S = "Ş" },
}
local letters = { ss = "ß", o = "ø", O = "Ø", ae = "æ", AE = "Æ",
    oe = "œ", OE = "Œ", aa = "å", AA = "Å", l = "ł", L = "Ł", i = "ı",
    j = "ȷ" }

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

-- Accent command at s[i] applied to its argument (\"u, \"{u}, \"{\i}).
local function apply_accent(acc, s, i, ctx)
    local a; a, i = read_arg(s, i)
    -- \"\i: the space after a control word belongs to it, as in TeX.
    if a:match("^\\%a+$") and s:sub(i, i) == " " then i = i + 1 end
    a = a:gsub("^\\([ij])%s*$", "%1")
    local ch = accents[acc][a]
    if ch then return ch, i end
    ctx.warn("instruction: accent \\" .. acc .. " on '" .. a .. "' is not converted")
    return esc(a), i
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
        if accents[sym] then return apply_accent(sym, s, i + 2, ctx) end
        return esc(sym), i + 2
    end
    i = i + 1 + #cs
    if s:sub(i, i) == " " then i = i + 1 end     -- detokenize space
    local a
    if cs == "c" then return apply_accent("c", s, i, ctx)
    elseif letters[cs] then
        if s:sub(i, i + 1) == "{}" then i = i + 2 end   -- \ss{}
        return letters[cs], i
    elseif wrap_tags[cs] then
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
--   allow_switch      true/false: pupils may switch between the text
--                     and the graphical view; nil: only for a
--                     graphical model
--   degrees           true: Coach's angle unit is degrees (Sin(x)
--                     takes x in degrees), else radians
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
    -- Switching between text and graphical view: by default on for a
    -- graphical model, off for a text model (Coach derives the text
    -- from the graphical model, so a text-only model would be lost).
    local switch = spec.allow_switch
    if switch == nil then switch = spec.graphic_xml ~= nil end
    find_leaf(desc, "CanSwitchModelModes")[5] = string.char(switch and 1 or 0)
    find_leaf(desc, "AngleUnits")[5] = spec.degrees and "\1" or "\0"
    -- Mode: 1 text, 0 graphical.
    if spec.graphic_xml then
        find_leaf(find(items, "GrModMain")[4], "Mode")[5] = "\0"
    else
        find_leaf(find(items, "GrModMain")[4], "Mode")[5] = "\1"
    end

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
    if spec.graphic_xml then
        -- Graphical: the objects carry the model; Coach derives the
        -- variable list from them, as in CMA's own activities.
        find(items, "VarList")[4] =
            { leaf("Number", 2, string.pack("<i4", 0)) }
        xml_rec[4] = long_text(spec.graphic_xml)
        return C.serialise(tree)
    end
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

-- --- graphical model (mode=graphic) -----------------------------------
-- Coach keeps a graphical model as XML in ModelXML: one <modelobject>
-- per object -- Independent (the time), Constant, Aux, State (a stock),
-- Flow (between two states, or a state and a cloud) and Relation (an
-- arrow from a variable to a formula that uses it) -- with its
-- formula, unit and position.  CMA's activities (and Coach on
-- switching) derive the text model from it.  The XML below follows
-- what Coach 7.0 itself writes.

local function xml_esc(s)
    return (tostring(s or ""):gsub("[&<>]", { ["&"] = "&amp;",
        ["<"] = "&lt;", [">"] = "&gt;" }))
end

-- The fields every object has, in Coach's order.
local function object_xml(tag, o)
    local open = tag == "Aux"
        and '<Aux locked="false" external_var="" external_indvar="" external_table="">'
        or '<' .. tag .. ' locked="false">'
    local L = {
        "  <modelobject>", "    " .. open,
        "      <label>" .. xml_esc(o.label) .. "</label>",
        "      <color>" .. (o.color or 16711680) .. "</color>",
        "      <x>" .. math.floor(o.x + 0.5) .. "</x>",
        "      <y>" .. math.floor(o.y + 0.5) .. "</y>",
        "      <font>Segoe UI</font>",
        "      <fontsize>12</fontsize>",
        "      <unit>" .. xml_esc(o.unit) .. "</unit>",
        "      <description></description>",
        "      <decimals>2</decimals>",
        "      <showdisplay>" .. tostring(o.showdisplay ~= false) .. "</showdisplay>",
        "      <showlabel>" .. tostring(o.showlabel ~= false) .. "</showlabel>",
        "      <labelpos>south</labelpos>",
        "      <usecondition>" .. tostring(o.condition ~= nil) .. "</usecondition>",
        "      <condition>" .. xml_esc(o.condition) .. "</condition>",
        "      <conditiontrue>" .. xml_esc(o.condtrue) .. "</conditiontrue>",
        "      <conditionfalse>" .. xml_esc(o.condfalse) .. "</conditionfalse>",
        "      <useinit>" .. tostring(o.init ~= nil) .. "</useinit>",
        "      <expr>" .. xml_esc(o.expr) .. "</expr>",
        "      <initexpr>" .. xml_esc(o.init) .. "</initexpr>",
        "      <fontbold>false</fontbold>",
        "      <fontitalic>false</fontitalic>",
        "      <fontunderline>false</fontunderline>",
        "      <fontstrikeout>false</fontstrikeout>",
        "      <fontcolor>16711680</fontcolor>",
        "      <conobject></conobject>",
        "      <minvalue>" .. xml_esc(o.min or 0) .. "</minvalue>",
        "      <maxvalue>" .. xml_esc(o.max or 10) .. "</maxvalue>",
        "      <easydisplay>true</easydisplay>",
        "      <scientificnotation>false</scientificnotation>",
    }
    for _, e in ipairs(o.extra or {}) do L[#L + 1] = "      " .. e end
    L[#L + 1] = "    </" .. tag .. ">"
    L[#L + 1] = "  </modelobject>"
    return table.concat(L, "\r\n")
end

-- Where a line from the centre of object o towards (tx, ty) leaves
-- it: a state is a 42 x 26 rectangle, a valve a small circle, the
-- others a circle of radius 11.
local function edge(o, tx, ty)
    local dx, dy = tx - o.x, ty - o.y
    local d = math.sqrt(dx * dx + dy * dy)
    if d == 0 then return o.x, o.y end
    if o.tag == "State" then
        local f = math.min(21 / math.max(math.abs(dx), 1e-9),
                           13 / math.max(math.abs(dy), 1e-9))
        return o.x + dx * f, o.y + dy * f
    end
    local r = o.tag == "Flow" and 6 or 11
    return o.x + dx * r / d, o.y + dy * r / d
end

local function num_text(x)
    -- A number in Coach's notation: decimal comma, no binary noise.
    local s = numodel.tex_number(x)
    return (s:gsub("%.", ","))
end

-- Build the XML for numodel prefix p.  r = numodel.plaintext's result
-- (names), g = numodel.get_model(p).  Returns the XML, or nil and the
-- reasons why the model cannot be drawn.
function C.graphic_xml(p, r, g, opts, note)
    local names = r.names
    local open = (opts.blanks or numodel.settings.blanks) ~= "filled"
    local D = numodel.dialects.NL
    local function pe(e)
        local s, ws = numodel.plain_expr(e, names, D)
        for _, w in ipairs(ws) do note(w) end
        return s
    end
    local var = {}
    for _, v in ipairs(g.vars) do var[v.name] = v end
    local problems = {}
    local function problem(s) problems[#problems + 1] = s end

    -- Rules per target, and the stop condition.
    local rules, stop = {}, nil
    for _, row in ipairs(g.program) do
        if row.kind == "calc" or row.kind == "ternary" then
            if rules[row.target] then
                problem(names[row.target] .. " has more than one rule")
            end
            rules[row.target] = row
        elseif row.kind == "stop" then stop = row
        elseif row.kind == "text" then
            note("free-text row left out of the graphical model")
        end
    end

    -- The time: t := t + dt.
    local time, dt
    for name, row in pairs(rules) do
        local refs = numodel.expr_refs(row.expr)
        if row.kind == "calc" and var[name].type == "system" then
            for other in pairs(refs) do
                if other ~= name then
                    local terms = numodel.plain_flow_terms(row.expr, name,
                        other, names, D)
                    if terms and #terms == 1 and terms[1].sign == 1
                       and terms[1].expr == "1" then
                        time, dt = name, other
                    end
                end
            end
        end
    end
    if not time then
        return nil, { "no time rule t := t + dt (a system variable)" }
    end

    -- Classify: State (stock rule with flows), Aux (other rule),
    -- Constant (no rule).
    local kind, flows_of = {}, {}
    for _, v in ipairs(g.vars) do
        local n, row = v.name, rules[v.name]
        if n == time or n == dt then
        elseif not row then kind[n] = "Constant"
        elseif row.kind == "ternary" then
            if numodel.expr_refs(row.expr)[dt] then
                problem("the conditional rule for " .. names[n]
                    .. " uses dt (a conditional stock is not drawn)")
            end
            kind[n] = "Aux"
        else
            local terms = numodel.plain_flow_terms(row.expr, n, dt, names, D)
            if terms then
                kind[n] = "State"; flows_of[n] = terms
            elseif numodel.expr_refs(row.expr)[n] then
                local _, why = numodel.plain_flow_terms(row.expr, n, dt, names, D)
                problem("the rule for " .. names[n] .. " uses " .. names[n]
                    .. " itself but is no stock rule: " .. why)
            else
                kind[n] = "Aux"
            end
        end
    end
    if #problems > 0 then return nil, problems end
    -- edu: every variable an object of its own, the flows Stroom_1, ...
    -- with the variable as formula (\graphicmodel's edu style);
    -- tight: a flow that is one variable takes its name and formula,
    -- as \graphicmodel's tight style draws it as the valve.
    local tight = opts.graphic_style == "tight"

    -- How many formulas use each variable (tight: a variable used only
    -- in its flow becomes the flow).
    local uses = {}
    local function count(e)
        for x in pairs(numodel.expr_refs(e)) do uses[x] = (uses[x] or 0) + 1 end
    end
    for n, row in pairs(rules) do if n ~= time then count(row.expr) end end
    for _, v in ipairs(g.vars) do
        if v.has_start and v.value_expr then count(v.value_expr) end
    end
    if stop then count(stop.expr) end

    -- Flows: a term -X of stock A and +X of stock B is one flow A -> B.
    local flows = {}
    local pending = {}
    for _, v in ipairs(g.vars) do
        for _, t in ipairs(flows_of[v.name] or {}) do
            local hit
            for i, f in ipairs(pending) do
                if f.expr == t.expr and f.sign == -t.sign and f.stock ~= v.name then
                    hit = i; break
                end
            end
            if hit then
                local f = table.remove(pending, hit)
                local from = f.sign < 0 and f.stock or v.name
                local to = f.sign < 0 and v.name or f.stock
                flows[#flows + 1] = { from = from, to = to, expr = t.expr,
                    refs = t.refs }
            else
                pending[#pending + 1] = { stock = v.name, sign = t.sign,
                    expr = t.expr, refs = t.refs }
            end
        end
    end
    for _, f in ipairs(pending) do
        flows[#flows + 1] = { from = f.sign < 0 and f.stock or nil,
            to = f.sign > 0 and f.stock or nil, expr = f.expr, refs = f.refs }
    end

    -- Compact: a flow that is one variable used nowhere else -- an
    -- auxiliary (also a conditional one) or a constant -- takes its
    -- name and formula (or value).
    local absorbed = {}
    for _, f in ipairs(tight and flows or {}) do
        local only, nrefs = nil, 0
        for x in pairs(f.refs) do only, nrefs = x, nrefs + 1 end
        -- used in the stock rule(s) of this flow only: one, or two for
        -- a flow between two stocks
        local n_rules = (f.from and f.to) and 2 or 1
        if nrefs == 1 and uses[only] == n_rules and names[only] == f.expr then
            local v, row = var[only], rules[only]
            if kind[only] == "Aux" and not v.has_start then
                f.var = only
                f.refs = numodel.expr_refs(row.expr)
                if row.kind == "ternary" then
                    local c, a, b, ws = numodel.plain_ternary(row.expr, names, D)
                    for _, w in ipairs(ws) do note(w) end
                    f.cond = { c, a, b }
                    f.expr = ""
                else
                    f.expr = pe(row.expr)
                end
            elseif kind[only] == "Constant" and v.has_start then
                f.var, f.const = only, true
                f.refs = numodel.expr_refs(v.value_expr)
                f.expr = pe(v.value_expr)
            end
            if f.var then absorbed[only] = f end
        end
    end

    -- Positions: the grid of \graphicmodel in the same style -- edu:
    -- every variable a node of its own, the valve of a flow variable
    -- beside it; tight: the flow variable is the valve -- turned into
    -- Coach's pixels.
    numodel.compute_layout(p, tight and "tight" or "edu")
    local M = numodel.models[p]
    local maxgy = 0
    for _, L in pairs(M.layout or {}) do
        if (L.gridy or -1) > maxgy then maxgy = L.gridy end
    end
    local function px(gx, gy)
        return 90 + gx * 110, 80 + (maxgy - gy) * 90
    end

    local objs, by_var = {}, {}
    local function add(o)
        objs[#objs + 1] = o
        if o.var then by_var[o.var] = o end
        return o
    end
    local function blank_rule(n) return open and rules[n] and rules[n].blank end
    local function blank_start(n) return open and var[n].blank end
    local function base(n)
        local v = var[n]
        local u = numodel.plain_unit(v.unit)
        return { var = n, label = names[n], unit = u,
            min = v.axis_min and num_text(v.axis_min),
            max = v.axis_max and num_text(v.axis_max) }
    end

    local tv = var[time]
    local ind = base(time)
    ind.tag, ind.x, ind.y, ind.expr, ind.showdisplay = "Independent", 20, 20,
        tv.has_start and pe(tv.value_expr) or "0", false
    ind.extra = { "<placed>false</placed>" }
    add(ind)

    -- dt as a constant when a formula still uses it once the factors
    -- dt of the stock rules have gone into the flows.
    local need_dt = stop and numodel.expr_refs(stop.expr)[dt]
    for n, row in pairs(rules) do
        if n ~= time and kind[n] ~= "State"
           and numodel.expr_refs(row.expr)[dt] then need_dt = true end
    end
    for _, v in ipairs(g.vars) do
        if v.has_start and v.value_expr
           and numodel.expr_refs(v.value_expr)[dt] then need_dt = true end
    end
    for _, f in ipairs(flows) do if f.refs[dt] then need_dt = true end end
    if need_dt then
        local o = base(dt)
        o.tag, o.expr = "Constant", pe(var[dt].value_expr)
        o.x, o.y = 20, 60
        add(o)
    end

    for _, v in ipairs(g.vars) do
        local n = v.name
        if kind[n] and not absorbed[n] then
            local L = M.layout and M.layout[n] or {}
            local o = base(n)
            o.tag = kind[n]
            o.x, o.y = px(L.gridx or 0, L.gridy or 0)
            -- Compact: a valve of \graphicmodel that stays an object of
            -- its own goes to the row above when that cell is free, else
            -- half a row up.
            if tight and L.role and L.role:find("valve") then
                local up = string.format("%d,%d", L.gridx, L.gridy + 1)
                o.y = o.y - ((M.occupied or {})[up] and 45 or 90)
            end
            if kind[n] == "Constant" or kind[n] == "State" then
                o.expr = blank_start(n) and "" or
                    (v.has_start and pe(v.value_expr) or "0")
                if not v.has_start then
                    note(names[n] .. " has no start value; 0 in Coach")
                end
            elseif rules[n].kind == "ternary" then
                local c, a, b, ws = numodel.plain_ternary(rules[n].expr, names, D)
                for _, w in ipairs(ws) do note(w) end
                if blank_rule(n) then c, a, b = "", "", "" end
                o.condition, o.condtrue, o.condfalse, o.expr = c, a, b, ""
            else
                o.expr = blank_rule(n) and "" or pe(rules[n].expr)
            end
            if kind[n] == "Aux" and v.has_start then
                o.init = blank_start(n) and "" or pe(v.value_expr)
            end
            add(o)
        end
    end

    -- Flows: the valve beside its stock, or between two stocks.
    local side = {}
    for k, f in ipairs(flows) do
        local o
        if f.var then
            -- tight: the flow is the variable, its name shown
            o = base(f.var)
            o.showlabel = true
            o.expr = f.expr
            if f.cond then
                o.condition, o.condtrue, o.condfalse =
                    f.cond[1], f.cond[2], f.cond[3]
            end
            if f.const and blank_start(f.var)
               or not f.const and blank_rule(f.var) then
                o.expr = ""
                if f.cond then o.condition, o.condtrue, o.condfalse = "", "", "" end
            end
        else
            o = { label = "Stroom_" .. k, unit = "", showlabel = false,
                expr = f.expr }
        end
        o.tag = "Flow"
        local A, B = f.from and by_var[f.from], f.to and by_var[f.to]
        if f.from and blank_rule(f.from) or f.to and blank_rule(f.to) then
            o.expr = ""
        end
        local S = B or A
        local key = S.var .. (B and "in" or "out")
        side[key] = (side[key] or 0) + 1
        local dy = (side[key] - 1) * 30
        -- The valve of \graphicmodel, when the flow is one variable.
        local only
        for x in pairs(f.var and {} or f.refs) do
            only = only == nil and x or false
        end
        local VL = M.layout and M.layout[f.var or only or ""]
        if not tight and VL and VL.vpos_x then
            o.x, o.y = px(VL.vpos_x, VL.vpos_y or 0)
        elseif tight and VL and VL.role and VL.role:find("valve")
               and VL.gridx then
            o.x, o.y = px(VL.gridx, VL.gridy)
        elseif A and B then
            o.x, o.y = (A.x + B.x) / 2, (A.y + B.y) / 2 + dy
        elseif B then
            -- the cell numodel keeps free for the valve of a stock
            o.x, o.y = B.x - 110, B.y + dy
        else
            o.x, o.y = A.x + 110, A.y + dy
        end
        local x1, y1, x2, y2
        if A then x1, y1 = edge(A, o.x, o.y) else x1, y1 = o.x - 40, o.y end
        if B then x2, y2 = edge(B, o.x, o.y) else x2, y2 = o.x + 40, o.y end
        o.extra = {
            "<fig1>" .. xml_esc(A and A.label or "") .. "</fig1>",
            "<fig1x>" .. math.floor(x1 + 0.5) .. "</fig1x>",
            "<fig1y>" .. math.floor(y1 + 0.5) .. "</fig1y>",
            "<fig2>" .. xml_esc(B and B.label or "") .. "</fig2>",
            "<fig2x>" .. math.floor(x2 + 0.5) .. "</fig2x>",
            "<fig2y>" .. math.floor(y2 + 0.5) .. "</fig2y>",
            "<FlowType>0</FlowType>",
            "<flowctrlx>" .. math.floor(o.x + 0.5) .. "</flowctrlx>",
            "<flowctrly>" .. math.floor(o.y + 0.5) .. "</flowctrly>",
        }
        o.refs = f.refs
        o.ends = { [A or 0] = true, [B or 0] = true }
        add(o)
        if f.var then by_var[f.var] = o end
    end

    -- Relations: from every variable a formula uses to its object.
    local rel = 0
    local relations = {}
    -- A straight arrow that would pass close by another object is bent
    -- (above it, or to its left for a vertical arrow), as the curved
    -- causal arrows of \graphicmodel.
    local function blocked(src, dst)
        -- from a stock to its own flow: along the pipe
        if dst.ends and dst.ends[src] then return true end
        local ax, ay, bx, by = src.x, src.y, dst.x, dst.y
        local lx, ly = bx - ax, by - ay
        local l2 = lx * lx + ly * ly
        if l2 == 0 then return false end
        for _, o in ipairs(objs) do
            if o ~= src and o ~= dst then
                local t = ((o.x - ax) * lx + (o.y - ay) * ly) / l2
                if t > 0.05 and t < 0.95 then
                    local qx, qy = ax + t * lx - o.x, ay + t * ly - o.y
                    if qx * qx + qy * qy < 18 * 18 then return true end
                end
            end
        end
        return false
    end
    local function relate(src, dst)
        if not src or not dst or src == dst then return end
        rel = rel + 1
        local ox, oy = 0, 0
        if blocked(src, dst) then
            local lx, ly = dst.x - src.x, dst.y - src.y
            local l = math.sqrt(lx * lx + ly * ly)
            ox, oy = ly / l * 45, -lx / l * 45      -- a normal
            if oy > 0 or (oy == 0 and ox > 0) then ox, oy = -ox, -oy end
        end
        local c1x = src.x + (dst.x - src.x) / 3 + ox
        local c1y = src.y + (dst.y - src.y) / 3 + oy
        local c2x = src.x + 2 * (dst.x - src.x) / 3 + ox
        local c2y = src.y + 2 * (dst.y - src.y) / 3 + oy
        local x1, y1 = edge(src, c1x, c1y)
        local x2, y2 = edge(dst, c2x, c2y)
        if ox == 0 and oy == 0 then
            c1x, c1y = x1 + (x2 - x1) / 3, y1 + (y2 - y1) / 3
            c2x, c2y = x1 + 2 * (x2 - x1) / 3, y1 + 2 * (y2 - y1) / 3
        end
        relations[#relations + 1] = {
            tag = "Relation", label = "Relatie_" .. rel, color = 255,
            x = (x1 + x2) / 2 + 0.75 * ox, y = (y1 + y2) / 2 + 0.75 * oy,
            showlabel = false, unit = "", expr = "",
            extra = {
                "<fig1>" .. xml_esc(src.label) .. "</fig1>",
                "<fig1x>" .. math.floor(x1 + 0.5) .. "</fig1x>",
                "<fig1y>" .. math.floor(y1 + 0.5) .. "</fig1y>",
                "<fig2>" .. xml_esc(dst.label) .. "</fig2>",
                "<fig2x>" .. math.floor(x2 + 0.5) .. "</fig2x>",
                "<fig2y>" .. math.floor(y2 + 0.5) .. "</fig2y>",
                "<ctrlpoint>", "  <x>" .. math.floor(c1x + 0.5) .. "</x>",
                "  <y>" .. math.floor(c1y + 0.5) .. "</y>", "</ctrlpoint>",
                "<ctrlpoint>", "  <x>" .. math.floor(c2x + 0.5) .. "</x>",
                "  <y>" .. math.floor(c2y + 0.5) .. "</y>", "</ctrlpoint>",
            },
        }
    end
    for _, o in ipairs(objs) do
        local refs = {}
        local function merge(e)
            if e then for x in pairs(numodel.expr_refs(e)) do refs[x] = true end end
        end
        if o.tag == "Flow" then
            for x in pairs(o.refs or {}) do refs[x] = true end
        elseif o.var and o.var ~= time then
            if rules[o.var] and kind[o.var] == "Aux" then merge(rules[o.var].expr) end
            if var[o.var].has_start then merge(var[o.var].value_expr) end
        end
        local list = {}
        for x in pairs(refs) do list[#list + 1] = x end
        table.sort(list)
        for _, x in ipairs(list) do
            if x ~= o.var then relate(by_var[x], o) end
        end
    end

    -- Settings: time from the start of t, step dt, at most maxiter
    -- steps; the stop condition ends the run.
    local t0 = tv.value or 0
    local step = var[dt].value or 1
    local L = {
        '<model rowindex="1" xmlversion="7.1">',
        "  <start>" .. num_text(t0) .. "</start>",
        "  <stop>" .. num_text(t0 + step * g.maxiter) .. "</stop>",
        "  <step>" .. num_text(step) .. "</step>",
        "  <method>Euler</method>",
        "  <notation>difference</notation>",
        "  <usestopcondition>" .. tostring(stop ~= nil) .. "</usestopcondition>",
        "  <stopcondition>" .. xml_esc(stop and not (open and stop.blank)
            and pe(stop.expr) or "") .. "</stopcondition>",
        "  <savedataevery>1</savedataevery>",
        "  <autocreaterelations>false</autocreaterelations>",
    }
    for _, o in ipairs(objs) do L[#L + 1] = object_xml(o.tag, o) end
    for _, o in ipairs(relations) do L[#L + 1] = object_xml("Relation", o) end
    L[#L + 1] = "</model>"
    return table.concat(L, "\r\n") .. "\r\n"
end

-- --- from a numodel model ----------------------------------------------

-- Build the activity for numodel prefix p.  Returns the file contents
-- and the list of warnings (things that could not be exported
-- exactly).  opts.allow_switch as in build.
function C.from_model(p, opts)
    opts = opts or {}
    local g = numodel.get_model(p)
    if not g then error("numodel-coach: unknown model prefix '" .. p .. "'") end
    -- opts.blanks: "open"/"filled", or nil to follow numodel's setting.
    local r = numodel.plaintext(p, { dialect = "NL", blanks = opts.blanks })
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
    local graphic_xml
    if opts.mode == "graphic" then
        local why
        graphic_xml, why = C.graphic_xml(p, r, g, opts,
            function(w) W[#W + 1] = w end)
        if not graphic_xml then
            W[#W + 1] = "no graphical model: " .. table.concat(why, "; ")
                .. "; written as a text model"
        end
    end
    local instruction
    if C.instructions[p] then
        instruction = C.instruction_html(C.instructions[p], ",",
            function(w) W[#W + 1] = w end)
    end
    local data = C.build({
        body = r.body, init = r.init, variables = vars,
        iterations = g.maxiter, allow_switch = opts.allow_switch,
        degrees = numodel.settings.angles == "degrees",
        instruction = instruction, graphic_xml = graphic_xml,
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
function C.tex_write(p, path, allow_switch, blanks, mode, graphic_style)
    if not numodel.get_model(p) then
        tex.sprint("\\numodelcoachnomodel{")
        tex.sprint(-2, p)
        tex.sprint("}")
        return
    end
    if blanks == "" then blanks = nil end
    -- "true", "false", or "" for the default of the mode
    if allow_switch == "" then allow_switch = nil
    elseif type(allow_switch) == "string" then
        allow_switch = allow_switch == "true"
    end
    local W = C.write(p, path, { allow_switch = allow_switch, blanks = blanks,
        mode = mode, graphic_style = graphic_style })
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
    out[#out + 1] = "AngleUnits=" .. find_leaf(desc, "AngleUnits")[5]:byte()
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

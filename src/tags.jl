@enum LocTag begin
    O_Tag = 0
    B_Tag = 1
    I_Tag = 2
    E_Tag = 3
    S_Tag = 4
end

function toSym(t::LocTag)
    if t == O_Tag
        return :O
    elseif t == B_Tag
        return :B
    elseif t == I_Tag
        return :I
    elseif t == E_Tag
        return :E
    elseif t == S_Tag
        return :S
    end
end

function LocTag(s::AbstractString)
    if s == "O"
        return O_Tag
    elseif s == "B"
        return B_Tag
    elseif s == "I"
        return I_Tag
    elseif s == "E"
        return E_Tag
    elseif s == "S"
        return S_Tag
    else
        error("unknown loc tag: $s")
    end
end

struct NEType
    sym::Symbol
end

NEType(s::AbstractString="") = NEType(Symbol(s))

Base.isempty(t::NEType) = t.sym === Symbol()

Base.show(io::IO, t::NEType) = print(io, t.sym)

struct NETag
    loc::LocTag
    type::NEType
end

const prefix_form = Ref(r"^([BIES])-([^-]+)$")
const suffix_form = Ref(r"^([^-]+)-([BIES])$")

function parse_form(label::AbstractString)
    global prefix_form, suffix_form
    m = match(prefix_form[], label)
    if !isnothing(m)
        tag, type = m.captures
        return tag, type
    end

    m = match(suffix_form[], label)
    if !isnothing(m)
        type, tag = m.captures
        return tag, type
    end

    return nothing
end

get_tags(x::AbstractVector{<:AbstractString}) = map(NETag, x)
get_tags(x::AbstractVector{<:AbstractVector{<:AbstractString}}) = map(get_tags, x)

NETag() = NETag(O_Tag, NEType())

const nulltag = NETag()

function NETag(label::AbstractString)
    if length(label) == 1
        return NETag(LocTag(label), NEType())
    else
        p = parse_form(label)
        isnothing(p) && error("unknown ne tag: $label")
        tag, type = p
        return NETag(LocTag(tag), NEType(type))
    end
end

function Base.show(io::IO, t::NETag)
    print(io, toSym(t.loc))
    if !isempty(t.type)
        print(io, '-', t.type.sym)
    end
end

module Seqeval

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

get_tags(x::Vector{<:AbstractString}) = map(NETag, x)
get_tags(x::Vector{<:Vector{<:AbstractString}}) = map(get_tags, x)

NETag() = NETag(O_Tag, NEType())

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

function isstart(prev::NETag, curr::NETag)
    (curr.loc == B_Tag || curr.loc == S_Tag) && return true
    (curr.loc == E_Tag || curr.loc == I_Tag) &&
        (prev.loc == E_Tag || prev.loc == S_Tag || prev.loc == O_Tag) && return true
    curr.loc != O_Tag && prev.type != curr.type && return true
    return false
end

function isend(prev::NETag, curr::NETag)
    (prev.loc == E_Tag || prev.loc == S_Tag) && return true
    (prev.loc == B_Tag || prev.loc == I_Tag) &&
        (curr.loc == B_Tag || curr.loc == S_Tag || curr.loc == O_Tag) && return true
    prev.loc != O_Tag && prev.type != curr.type && return true
    return false
end

function entity_ranges(tags::Vector{NETag})
    result = Array{Tuple{NEType, UnitRange}}(undef, 0)
    sizehint!(result, length(tags))
    entity_ranges!(result, tags)
    sizehint!(result, length(result))
    return result
end

function entity_ranges!(result, tags::Vector{NETag})
    len = length(tags)

    @assert len > 0
    prev = first(tags)
    base, i = 1, 2
    @inbounds while i <= len
        tag = tags[i]

        isend(prev, tag) && push!(result, (prev.type, base:i-1))
        isstart(prev, tag) && (base = i)

        prev = tag
        i += 1
    end
    isend(prev, NETag()) && push!(result, (prev.type, base:i-1))
    return result
end

function compute_correct(types, p_entity, gt_entity)
    len = length(types)
    p_sum = zeros(Int32, len)
    gt_sum = zeros(Int32, len)
    correct_sum = zeros(Int32, len)
    @inbounds for (i, type) in enumerate(types)
        p_has = haskey(p_entity, type)
        gt_has = haskey(gt_entity, type)

        p_has && (p_sum[i] = length(p_entity[type]))
        gt_has && (gt_sum[i] = length(gt_entity[type]))
        p_has && gt_has && (correct_sum[i] = length(p_entity[type] ∩ gt_entity[type]))
    end
    return (type=types, correct=correct_sum, p=p_sum, gt=gt_sum)
end

function entity_stat(p, gt)
    p_entity = Dict{NEType, Set{Tuple{Int, UnitRange}}}()
    gt_entity = Dict{NEType, Set{Tuple{Int, UnitRange}}}()
    types = Set{NEType}()
    return entity_stat!(types, p_entity, gt_entity, p, gt)
end

function entity_stat!(types, p_entity, gt_entity, p::Vector{Vector{NETag}}, gt::Vector{Vector{NETag}})
    for (i, (pi, gti)) in enumerate(zip(p, gt))
        entity_stat!(types, p_entity, gt_entity, pi, gti, i)
    end
    return (types, p_entity, gt_entity)
end

function entity_stat!(types, p_entity, gt_entity, p::Vector{NETag}, gt::Vector{NETag}, i = 1)
    for (type, rang) in entity_ranges(p)
        !haskey(p_entity, type) && (p_entity[type] = Set{UnitRange}())
        push!(p_entity[type], (i, rang))
        push!(types, type)
    end
    for (type, rang) in entity_ranges(gt)
        !haskey(gt_entity, type) && (gt_entity[type] = Set{UnitRange}())
        push!(gt_entity[type], (i, rang))
        push!(types, type)
    end
    return (types, p_entity, gt_entity)
end

function extract_correct(p, gt)
    types, p_entity, gt_entity = entity_stat(p, gt)
    return compute_correct(types, p_entity, gt_entity)
end

function micro_average(result, β)
    p = sum(result.p)
    gt = sum(result.gt)
    correct = sum(result.correct)

    precision = iszero(p) ? 0 : correct / p
    recall = iszero(gt) ? 0 : correct / gt

    if isinf(β) && β > 0
        f1 = recall
    else
        denominator = iszero(precision) && iszero(recall) ? one(recall) : recall + precision * β^2
        f1 = (1 + β^2) * recall * precision / denominator
    end
    return precision, recall, f1, gt
end


function precision_recall_f1score_support(p, gt; β = true)
    result = extract_correct(p, gt)
    micro_average(result, β)
end

precision(p, gt) = precision_recall_f1score_support(p, gt)[1]
recall(p, gt) = precision_recall_f1score_support(p, gt)[2]
f1(p, gt) = precision_recall_f1score_support(p, gt)[3]

                  
# y_true = [["O", "O", "O", "B-MISC", "I-MISC", "I-MISC", "O"], ["B-PER", "I-PER", "O"]]
# y_pred = [["O", "O", "B-MISC", "I-MISC", "I-MISC", "I-MISC", "O"], ["B-PER", "I-PER", "O"]]
# y_true = [["O", "O", "B-MISC", "I-MISC", "B-MISC", "O", "O"], ["B-PER", "I-PER", "O"]]
# y_pred = [["O", "O", "B-MISC", "I-MISC", "B-MISC", "I-MISC", "O"], ["B-PER", "I-PER", "O"]]

end

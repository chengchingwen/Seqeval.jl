module Seqeval

export NETag, get_tags, f1score

include("./tags.jl")

function curr_isstart(prev::NETag, curr::NETag)
    (curr.loc == B_Tag || curr.loc == S_Tag) && return true
    (curr.loc == E_Tag || curr.loc == I_Tag) &&
        (prev.loc == E_Tag || prev.loc == S_Tag || prev.loc == O_Tag) && return true
    curr.loc != O_Tag && prev.type != curr.type && return true
    return false
end

function prev_isend(prev::NETag, curr::NETag)
    (prev.loc == E_Tag || prev.loc == S_Tag) && return true
    (prev.loc == B_Tag || prev.loc == I_Tag) &&
        (curr.loc == B_Tag || curr.loc == S_Tag || curr.loc == O_Tag) && return true
    prev.loc != O_Tag && prev.type != curr.type && return true
    return false
end

function entity_ranges(tags::AbstractVector{NETag})
    result = Array{Tuple{NEType, UnitRange}}(undef, 0)
    sizehint!(result, length(tags))
    entity_ranges!(result, tags)
    sizehint!(result, length(result))
    return result
end

function entity_ranges!(result, tags::AbstractVector{NETag})
    len = length(tags)

    @assert len > 0
    prev = first(tags)
    base, i = 1, 2
    @inbounds while i <= len
        tag = tags[i]

        prev_isend(prev, tag) && push!(result, (prev.type, base:i-1))
        curr_isstart(prev, tag) && (base = i)

        prev = tag
        i += 1
    end
    prev_isend(prev, nulltag) && push!(result, (prev.type, base:i-1))
    return result
end

function plus1!(d::Dict, key)
    d[key] = get(d, key, 0) + 1
end

function compute_correct(p::AbstractVector{<:AbstractVector{NETag}}, gt::AbstractVector{<:AbstractVector{NETag}})
    result = SeqEval()
    for (pi, gti) in zip(p, gt)
        compute_correct!(result, pi, gti)
    end
    return result
end

compute_correct(p::AbstractVector{NETag}, gt::AbstractVector{NETag}) = compute_correct!(SeqEval(), p, gt)
function compute_correct!(result, p::AbstractVector{NETag}, gt::AbstractVector{NETag})
    plen = length(p)
    gtlen = length(gt)
    maxlen = max(plen, gtlen)

    @assert plen > 0 && gtlen > 0
    p_prev = first(p)
    gt_prev = first(gt)
    pbase = gtbase = 1
    i = 2
    c = p_prev == gt_prev
    @inbounds while i <= maxlen
        ptag = i > plen ? nulltag : p[i]
        gttag = i > gtlen ? nulltag : gt[i]

        ptag == gttag && (c += 1)

        p_isend = prev_isend(p_prev, ptag)
        gt_isend = prev_isend(gt_prev, gttag)

        p_isstart = curr_isstart(p_prev, ptag)
        gt_isstart = curr_isstart(gt_prev, gttag)

        p_isend && plus1!(result.p, p_prev.type)
        gt_isend && plus1!(result.gt, gt_prev.type)

        if p_isend && gt_isend && pbase == gtbase && p_prev.type == gt_prev.type
            plus1!(result.correct, gt_prev.type)
        end

        p_isstart && (pbase = i)
        gt_isstart && (gtbase =  i)

        p_prev = ptag
        gt_prev = gttag
        i += 1
    end

    p_isend = prev_isend(p_prev, nulltag)
    gt_isend = prev_isend(gt_prev, nulltag)

    p_isend && plus1!(result.p, p_prev.type)
    gt_isend && plus1!(result.gt, gt_prev.type)

    if p_isend && gt_isend && pbase == gtbase && p_prev.type == gt_prev.type
        plus1!(result.correct, gt_prev.type)
    end

    result.count[] += c
    result.total[] += maxlen

    return result
end

function micro_average(result, β)
    p = sum(values(result.p))
    gt = sum(values(result.gt))
    correct = sum(values(result.correct))

    precision = iszero(p) ? 0 : correct / p
    recall = iszero(gt) ? 0 : correct / gt
    acc = result.count[] / result.total[]

    if isinf(β) && β > 0
        f1 = recall
    else
        denominator = iszero(precision) && iszero(recall) ? one(recall) : recall + precision * β^2
        f1 = (1 + β^2) * recall * precision / denominator
    end
    return (accuracy = acc, precision = precision, recall = recall, f1score = f1)
end

function precision_recall_f1score_support(p, gt; β = true)
    result = compute_correct(p, gt)
    micro_average(result, β)
end

accuracy(p, gt) = precision_recall_f1score_support(p, gt).accuracy
precision(p, gt) = precision_recall_f1score_support(p, gt).precision
recall(p, gt) = precision_recall_f1score_support(p, gt).recall
f1score(p, gt; β = true) = precision_recall_f1score_support(p, gt; β).f1score

struct SeqEval
    correct::Dict{NEType,Int}
    p::Dict{NEType, Int}
    gt::Dict{NEType, Int}
    count::Ref{Int}
    total::Ref{Int}
end

SeqEval() = SeqEval(Dict{NEType,Int}(), Dict{NEType, Int}(), Dict{NEType, Int}(), Ref(0), Ref(0))

Base.push!(s::SeqEval, p, gt) = compute_correct!(s, p, gt)

precision_recall_f1score_support(s::SeqEval; β = true) = micro_average(s, β)
accuracy(s::SeqEval) = precision_recall_f1score_support(s).accuracy
precision(s::SeqEval) = precision_recall_f1score_support(s).precision
recall(s::SeqEval) = precision_recall_f1score_support(s).recall
f1score(s::SeqEval; β = true) = precision_recall_f1score_support(s; β).f1score

# y_true = [["O", "O", "O", "B-MISC", "I-MISC", "I-MISC", "O"], ["B-PER", "I-PER", "O"]]
# y_pred = [["O", "O", "B-MISC", "I-MISC", "I-MISC", "I-MISC", "O"], ["B-PER", "I-PER", "O"]]
# y_true = [["O", "O", "B-MISC", "I-MISC", "B-MISC", "O", "O"], ["B-PER", "I-PER", "O"]]
# y_pred = [["O", "O", "B-MISC", "I-MISC", "B-MISC", "I-MISC", "O"], ["B-PER", "I-PER", "O"]]

end

## AlmostBandedMatrix



struct AlmostBandedMatrix{T,B<:BandedMatrix{T}} <: AbstractMatrix{T}
    bands::B
    fill::LowRankMatrix{T}
    function AlmostBandedMatrix{T}(bands::BandedMatrix{T}, fill::LowRankMatrix{T}) where T
        if size(bands) ≠ size(fill)
            error("Data and fill must be compatible size")
        end
        new{T,typeof(bands)}(bands,fill)
    end
end

AlmostBandedMatrix(bands::BandedMatrix, fill::LowRankMatrix) =
    AlmostBandedMatrix{promote_type(eltype(bands),eltype(fill))}(bands,fill)

AlmostBandedMatrix{T}(nm::NTuple{2,Integer}, lu::NTuple{2,Integer}, r::Integer) where {T} =
    AlmostBandedMatrix(BandedMatrix{T}(nm,lu), LowRankMatrix{T}(nm,r))


AlmostBandedMatrix{T}(Z::Zeros, lu::NTuple{2,Integer}, r::Integer) where {T} =
    AlmostBandedMatrix(BandedMatrix{T}(Z, lu), LowRankMatrix{T}(Z, r))

AlmostBandedMatrix(Z::AbstractMatrix, lu::NTuple{2,Integer}, r::Integer) =
    AlmostBandedMatrix{eltype(Z)}(Z, lu, r)

for MAT in (:AlmostBandedMatrix, :AbstractMatrix)
    @eval convert(::Type{$MAT{T}}, A::AlmostBandedMatrix) where {T} =
        AlmostBandedMatrix(convert(AbstractMatrix{T}, A.bands), convert(AbstractMatrix{T}, A.fill))
end


size(A::AlmostBandedMatrix) = size(A.bands)


function getindex(B::AlmostBandedMatrix,k::Integer,j::Integer)
    if j > k + bandwidth(B.bands,2)
        B.fill[k,j]
    else
        B.bands[k,j]
    end
end

# can only change the bands, not the fill
function setindex!(B::AlmostBandedMatrix,v,k::Integer,j::Integer)
        B.bands[k,j] = v
end


function pad(B::AlmostBandedMatrix,n::Integer,m::Integer)
    bands = pad(B.bands,n,m)
    fill = pad(B.fill,n,m)
    AlmostBandedMatrix(bands, fill)
end

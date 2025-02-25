## Sequence space defintions

# A Fun for SequenceSpace can be an iterator
iterate(::Fun{SequenceSpace}) = 1
iterate(f::Fun{SequenceSpace}, st) = f[st], st+1

getindex(f::Fun{SequenceSpace}, k::Integer) =
    k ≤ ncoefficients(f) ? f.coefficients[k] : zero(cfstype(f))
getindex(f::Fun{SequenceSpace},K::CartesianIndex{0}) = f[1]
getindex(f::Fun{SequenceSpace},K) = cfstype(f)[f[k] for k in K]

length(f::Fun{SequenceSpace}) = ℵ₀


dotu(f::Fun{SequenceSpace},g::Fun{SequenceSpace}) =
    mindotu(f.coefficients,g.coefficients)
dotu(f::Fun{SequenceSpace},g::AbstractVector) =
    mindotu(f.coefficients,g)
dotu(f::AbstractVector,g::Fun{SequenceSpace}) =
    mindotu(f,g.coefficients)

norm(f::Fun{SequenceSpace}) = norm(f.coefficients)
norm(f::Fun{SequenceSpace},k::Int) = norm(f.coefficients,k)
norm(f::Fun{SequenceSpace},k::Number) = norm(f.coefficients,k)


Fun(cfs::AbstractVector,S::SequenceSpace) = Fun(S,cfs)
coefficients(cfs::AbstractVector,::SequenceSpace) = cfs  # all vectors are convertible to SequenceSpace



## Constant space defintions

containsconstant(A::Space) = containsconstant(typeof(A))
containsconstant(@nospecialize(_)) = Val(false)

# setup conversions for spaces that contain constants
macro containsconstants(SP)
    esc(quote
        ApproxFunBase.containsconstant(::Type{<:$SP}) = Val(true)
    end)
end

function promote_rule(TS1::Type{<:ConstantSpace}, ::Type{TS2}) where {TS2<:Space}
    constspace_promote_rule(TS1, TS2, containsconstant(TS2))
end
constspace_promote_rule(::Type{<:ConstantSpace}, ::Type{<:Space}, ::Val{false}) = Union{}
constspace_promote_rule(::Type{<:ConstantSpace}, ::Type{B}, ::Val{true}) where {B<:Space} = B

union_rule(A::ConstantSpace, B::Space) = constspace_union_rule(A, B, containsconstant(B))
# TODO: this seems like it needs more thought
function constspace_union_rule(@nospecialize(_::ConstantSpace), B::Space, ::Val{false})
    ConstantSpace(domain(B)) ⊕ B
end
constspace_union_rule(@nospecialize(_::ConstantSpace), B::Space, ::Val{true}) = B

function promote_rule(TF::Type{<:Fun{S}}, TN::Type{<:Number}) where {S}
    fun_promote_rule(TF, TN, containsconstant(S))
end
fun_promote_rule(::Type{<:Fun}, ::Type{<:Number}, ::Val{false}) = Fun
function fun_promote_rule(::Type{<:Fun{S,CT}}, ::Type{T}, ::Val{true}) where {T<:Number,CT,S}
    ApproxFunBase.VFun{S,promote_type(CT,T)}
end
function fun_promote_rule(::Type{<:Fun{S}}, ::Type{T}, ::Val{true}) where {T<:Number,S}
    ApproxFunBase.VFun{S,T}
end

Fun(c::Number) = Fun(ConstantSpace(typeof(c)),[c])
Fun(c::Number,d::ConstantSpace) = Fun(d,[c])

dimension(::ConstantSpace) = 1

#TODO: Change
setdomain(f::Fun{CS},d::Domain) where {CS<:AnyDomain} = Number(f)*ones(d)

canonicalspace(C::ConstantSpace) = C
spacescompatible(a::ConstantSpace,b::ConstantSpace)=domainscompatible(a,b)

ones(S::ConstantSpace) = Fun(S,fill(1.0,1))
ones(S::Union{AnyDomain,UnsetSpace}) = ones(ConstantSpace())
zeros(S::AnyDomain) = zero(ConstantSpace())
zero(S::UnsetSpace) = zero(ConstantSpace())
evaluate(f::AbstractVector,::ConstantSpace,x...)=f[1]
evaluate(f::AbstractVector,::ZeroSpace,x...)=zero(eltype(f))


convert(::Type{T}, f::Fun{CS}) where {CS<:ConstantSpace,T<:Number} =
    strictconvert(T, f.coefficients[1])

Number(f::Fun) = strictconvert(Number, f)


# promoting numbers to Fun
# override promote_rule if the space type can represent constants
Base.promote_rule(::Type{Fun{CS}},::Type{T}) where {CS<:ConstantSpace,T<:Number} = Fun{CS,T}
Base.promote_rule(::Type{Fun{CS,V}},::Type{T}) where {CS<:ConstantSpace,T<:Number,V} =
    Fun{CS,promote_type(T,V)}


# we know multiplication by constants preserves types
Base.promote_op(::typeof(*),::Type{Fun{CS,T,VT}},::Type{F}) where {CS<:ConstantSpace,T,VT,F<:Fun} =
    promote_op(*,T,F)
Base.promote_op(::typeof(*),::Type{F},::Type{Fun{CS,T,VT}}) where {CS<:ConstantSpace,T,VT,F<:Fun} =
    promote_op(*,F,T)



Base.promote_op(::typeof(LinearAlgebra.matprod),::Type{Fun{S1,T1,VT1}},::Type{Fun{S2,T2,VT2}}) where {S1<:ConstantSpace,T1,VT1,S2<:ConstantSpace,T2,VT2} =
            VFun{promote_type(S1,S2),promote_type(T1,T2)}
Base.promote_op(::typeof(LinearAlgebra.matprod),::Type{Fun{S1,T1,VT1}},::Type{Fun{S2,T2,VT2}}) where {S1<:ConstantSpace,T1,VT1,S2,T2,VT2} =
            VFun{S2,promote_type(T1,T2)}
Base.promote_op(::typeof(LinearAlgebra.matprod),::Type{Fun{S1,T1,VT1}},::Type{Fun{S2,T2,VT2}}) where {S1,T1,VT1,S2<:ConstantSpace,T2,VT2} =
            VFun{S1,promote_type(T1,T2)}


# When the union of A and B is a ConstantSpace, then it contains a one
conversion_rule(A::ConstantSpace,B::UnsetSpace)=NoSpace()
conversion_rule(A::ConstantSpace,B::Space)=(union_rule(A,B)==B||union_rule(B,A)==B) ? A : NoSpace()

conversion_rule(A::ZeroSpace,B::Space) = A
maxspace_rule(A::ZeroSpace,B::Space) = B

Conversion(A::ZeroSpace,B::ZeroSpace) = ConversionWrapper(ZeroOperator(A,B))
Conversion(A::ZeroSpace,B::Space) = ConversionWrapper(ZeroOperator(A,B))

## Special Multiplication and Conversion for constantspace

#  TODO: this is a special work around but really we want it to be blocks
Conversion(a::ConstantSpace,b::Space{D}) where {D<:EuclideanDomain{2}} = ConcreteConversion{typeof(a),typeof(b),
        promote_type(real(prectype(a)),real(prectype(b)))}(a,b)

Conversion(a::ConstantSpace,b::Space) = ConcreteConversion(a,b)
bandwidths(C::ConcreteConversion{CS,S}) where {CS<:ConstantSpace,S<:Space} =
    ncoefficients(ones(rangespace(C)))-1,0
function getindex(C::ConcreteConversion{CS,S,T},k::Integer,j::Integer) where {CS<:ConstantSpace,S<:Space,T}
    if j != 1
        throw(BoundsError())
    end
    on=ones(rangespace(C))
    k ≤ ncoefficients(on) ? strictconvert(T,on.coefficients[k]) : zero(T)
end


coefficients(f::AbstractVector,sp::ConstantSpace{Segment{SVector{2,TT}}},
             ts::TensorSpace{SV,DD}) where {TT,SV,DD<:EuclideanDomain{2}} =
    f[1]*ones(ts).coefficients
coefficients(f::AbstractVector,sp::ConstantSpace{<:Domain{<:Number}},
             ts::TensorSpace{SV,DD}) where {SV,DD<:EuclideanDomain{2}} =
    f[1]*ones(ts).coefficients
coefficients(f::AbstractVector, sp::ConstantSpace{<:Domain{<:Number}}, ts::Space) =
    f[1]*ones(ts).coefficients
coefficients(f::AbstractVector, sp::ConstantSpace, ts::Space) =
    f[1]*ones(ts).coefficients


########
# Evaluation
########

#########
# Multiplication
#########


# this is identity operator, but we don't use MultiplicationWrapper to avoid
# ambiguity errors

defaultMultiplication(f::Fun{CS},b::ConstantSpace) where {CS<:ConstantSpace} =
    ConcreteMultiplication(f,b)
defaultMultiplication(f::Fun{CS},b::Space) where {CS<:ConstantSpace} =
    ConcreteMultiplication(f,b)
defaultMultiplication(f::Fun,b::ConstantSpace) = ConcreteMultiplication(f,b)

bandwidths(D::ConcreteMultiplication{CS1,CS2,T}) where {CS1<:ConstantSpace,CS2<:ConstantSpace,T} =
    0,0
getindex(D::ConcreteMultiplication{CS1,CS2,T},k::Integer,j::Integer) where {CS1<:ConstantSpace,CS2<:ConstantSpace,T} =
    k==j==1 ? strictconvert(T,D.f.coefficients[1]) : one(T)

rangespace(D::ConcreteMultiplication{CS1,CS2,T}) where {CS1<:ConstantSpace,CS2<:ConstantSpace,T} =
    D.space


rangespace(D::ConcreteMultiplication{F,UnsetSpace,T}) where {F<:ConstantSpace,T} =
    UnsetSpace()
bandwidths(D::ConcreteMultiplication{F,UnsetSpace,T}) where {F<:ConstantSpace,T} =
    (ℵ₀,ℵ₀)
getindex(D::ConcreteMultiplication{F,UnsetSpace,T},k::Integer,j::Integer) where {F<:ConstantSpace,T} =
    error("No range space attached to Multiplication")



bandwidths(D::ConcreteMultiplication{CS,F,T}) where {CS<:ConstantSpace,F<:Space,T} = 0,0
blockbandwidths(D::ConcreteMultiplication{CS,F,T}) where {CS<:ConstantSpace,F<:Space,T} = 0,0
subblockbandwidths(D::ConcreteMultiplication{CS,F,T}) where {CS<:ConstantSpace,F<:Space,T} = 0,0
subblockbandwidths(D::ConcreteMultiplication{CS,F,T}, k) where {CS<:ConstantSpace,F<:Space,T} = 0
isbandedblockbanded(D::ConcreteMultiplication{CS,F,T}) where {CS<:ConstantSpace,F<:Space,T} = true
isblockbanded(D::ConcreteMultiplication{CS,F,T}) where {CS<:ConstantSpace,F<:Space,T} = true
getindex(D::ConcreteMultiplication{CS,F,T},k::Integer,j::Integer) where {CS<:ConstantSpace,F<:Space,T} =
    k==j ? strictconvert(T, D.f) : zero(T)
rangespace(D::ConcreteMultiplication{CS,F,T}) where {CS<:ConstantSpace,F<:Space,T} = D.space


bandwidths(D::ConcreteMultiplication{F,CS,T}) where {CS<:ConstantSpace,F<:Space,T} = ncoefficients(D.f)-1,0
function getindex(D::ConcreteMultiplication{F,CS,T},k::Integer,j::Integer) where {CS<:ConstantSpace,F<:Space,T}
    k≤ncoefficients(D.f) && j==1 ? strictconvert(T,D.f.coefficients[k]) : zero(T)
end
rangespace(D::ConcreteMultiplication{F,CS,T}) where {CS<:ConstantSpace,F<:Space,T} = space(D.f)



# functionals always map to Constant space
function promoterangespace(P::Operator,A::ConstantSpace,cur::ConstantSpace)
    @assert isafunctional(P)
    domain(A)==domain(cur) ? P : SpaceOperator(P,domainspace(P),A)
end


for op = (:*,:/)
    @eval $op(f::Fun,c::Fun{CS}) where {CS<:ConstantSpace} = f*strictconvert(Number,c)
end



## Multivariate case
union_rule(a::TensorSpace,b::ConstantSpace{AnyDomain})=TensorSpace(map(sp->union(sp,b),a.spaces))
## Special spaces

function convert(::Type{T},f::Fun{TS}) where {TS<:TensorSpace,T<:Number}
    if all(sp->isa(sp,ConstantSpace),space(f).spaces)
        strictconvert(T,f.coefficients[1])
    else
        error("Cannot convert $f to type $T")
    end
end

convert(::Type{T},
            f::Fun{TensorSpace{Tuple{CS1,CS2},DD,RR}}) where {CS1<:ConstantSpace,CS2<:ConstantSpace,T<:Number,DD,RR} =
    strictconvert(T,f.coefficients[1])

isconstspace(sp::TensorSpace) = all(isconstspace,sp.spaces)


# Supports constants in operators
promoterangespace(M::ConcreteMultiplication{CS,UnsetSpace},
                             ps::UnsetSpace) where {CS<:ConstantSpace} = M
promoterangespace(M::ConcreteMultiplication{CS,UnsetSpace},
                             ps::Space) where {CS<:ConstantSpace} =
                        promoterangespace(Multiplication(M.f,space(M.f)),ps)

# Possible hack: we try uing constant space for [1 Operator()] \ z.
choosedomainspace(M::ConcreteMultiplication{D,UnsetSpace},sp::UnsetSpace) where {D<:ConstantSpace} = space(M.f)
choosedomainspace(M::ConcreteMultiplication{D,UnsetSpace},sp::Space) where {D<:ConstantSpace} = space(M.f)

Base.isfinite(f::Fun{CS}) where {CS<:ConstantSpace} = isfinite(Number(f))







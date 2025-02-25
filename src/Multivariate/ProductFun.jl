##
# ProductFun represents f(x,y) by Fun(.coefficients[k](x),.space[2])(y)
# where all coefficients are in the same space
##

export ProductFun


"""
    ProductFun(f, space::TensorSpace; [tol=eps()])

Represent a bivariate function `f(x,y)` as a univariate expansion over the second space,
with the coefficients being functions in the first space.
```math
f\\left(x,y\\right)=\\sum_{i}f_{i}\\left(x\\right)b_{i}\\left(y\\right),
```
where ``b_{i}\\left(y\\right)`` represents the ``i``-th basis function in the space over ``y``.

# Examples
```jldoctest
julia> P = ProductFun((x,y)->x*y, Chebyshev() ⊗ Chebyshev());

julia> P(0.1, 0.2) ≈ 0.1 * 0.2
true

julia> coefficients(P) # power only at the (1,1) Chebyshev mode
2×2 Matrix{Float64}:
 0.0  0.0
 0.0  1.0
```
"""

struct ProductFun{S<:UnivariateSpace,V<:UnivariateSpace,SS<:AbstractProductSpace,T} <: BivariateFun{T}
    coefficients::Vector{VFun{S,T}}     # coefficients are in x
    space::SS
end

ProductFun(cfs::Vector{VFun{S,T}},sp::AbstractProductSpace{Tuple{S,V},DD}) where {S<:UnivariateSpace,V<:UnivariateSpace,T<:Number,DD} =
    ProductFun{S,V,typeof(sp),T}(cfs,sp)
ProductFun(cfs::Vector{VFun{S,T}},sp::AbstractProductSpace{Tuple{W,V},DD}) where {S<:UnivariateSpace,V<:UnivariateSpace,
         W<:UnivariateSpace,T<:Number,DD} =
   ProductFun{W,V,typeof(sp),T}(VFun{W,T}[Fun(cfs[k],columnspace(sp,k)) for k=1:length(cfs)],sp)

size(f::ProductFun,k::Integer) =
    k==1 ? mapreduce(ncoefficients,max,f.coefficients) : length(f.coefficients)
size(f::ProductFun) = (size(f,1),size(f,2))

## Construction in an AbstractProductSpace via a Matrix of coefficients

"""
    ProductFun(coeffs::AbstractMatrix{T}, sp::AbstractProductSpace; [tol=100eps(T)], [chopping=false]) where {T<:Number}

Represent a bivariate function `f` in terms of the coefficient matrix `coeffs`,
where the coefficients are obtained using a bivariate
transform of the function `f` in the basis `sp`.

# Examples
```jldoctest
julia> P = ProductFun([0 0; 0 1], Chebyshev() ⊗ Chebyshev()) # corresponds to (x,y) -> x*y
ProductFun on Chebyshev() ⊗ Chebyshev()

julia> P(0.1, 0.2) ≈ 0.1 * 0.2
true
```
"""
function ProductFun(cfs::AbstractMatrix{T},sp::AbstractProductSpace{Tuple{S,V},DD};
    tol::Real=100eps(T),chopping::Bool=false) where {S<:UnivariateSpace,V<:UnivariateSpace,T<:Number,DD}

    kend = size(cfs, 2)
    if chopping
        ncfs = norm(cfs,Inf)
        kend -= ntrailingzerocols(cfs, ncfs*tol)
    end

    ret = if kend == 0
        VFun{S,T}[Fun(columnspace(sp,1), T[]) for k=1:1]
    else
        VFun{S,T}[Fun(columnspace(sp,k),
                    if chopping
                        chop(@view(cfs[:,k]), ncfs*tol)
                    else
                        cfs[:,k]
                    end
                )
            for k=1:kend
        ]
    end

    ProductFun{S,V,typeof(sp),T}(ret,sp)
end

## Construction in a ProductSpace via a Vector of Funs
"""
    ProductFun(M::AbstractVector{<:Fun{<:UnivariateSpace}}, sp::UnivariateSpace)

Represent a bivariate function `f(x,y)` in terms of the univariate coefficient functions from `M`.
The function `f` may be reconstructed as
```math
f\\left(x,y\\right)=\\sum_{i}M_{i}\\left(x\\right)b_{i}\\left(y\\right),
```
where ``b_{i}\\left(y\\right)`` represents the ``i``-th basis function for the space `sp`.

# Examples
```jldoctest
julia> P = ProductFun([zeros(Chebyshev()), Fun(Chebyshev())], Chebyshev()); # corresponds to (x,y)->x*y

julia> P(0.1, 0.2) ≈ 0.1 * 0.2
true
```
"""
function ProductFun(M::AbstractVector{VFun{S,T}}, dy::V) where {S<:UnivariateSpace,V<:UnivariateSpace,T<:Number}
    sp = mapreduce(space, maxspace, M)
    Msp = [Fun(f, sp) for f in M]
    prodsp = sp ⊗ dy
    ProductFun{S,V,typeof(prodsp),T}(Msp, prodsp)
end

## Adaptive construction

function ProductFun(f::Function, sp::AbstractProductSpace{Tuple{S,V}}; tol=100eps()) where {S<:UnivariateSpace,V<:UnivariateSpace}
    for n = 50:100:5000
        X = coefficients(ProductFun(f,sp,n,n;tol=tol))
        if size(X,1)<n && size(X,2)<n
            return ProductFun(X,sp;tol=tol)
        end
    end
    @warn "Maximum grid size of ("*string(5000)*","*string(5000)*") reached"
    ProductFun(f,sp,5000,5000;tol=tol,chopping=true)
end

## ProductFun values to coefficients

function ProductFun(f::Function,S::AbstractProductSpace,M::Integer,N::Integer;tol=100eps())
    xy = checkpoints(S)
    T = promote_type(eltype(f(first(xy)...)),rangetype(S))
    ptsx,ptsy=points(S,M,N)
    vals=T[f(ptsx[k,j],ptsy[k,j]) for k=1:size(ptsx,1), j=1:size(ptsx,2)]
    ProductFun(transform!(S,vals),S;tol=tol,chopping=true)
end
ProductFun(f::Function,S::TensorSpace) = ProductFun(LowRankFun(f,S))

ProductFun(f,dx::Space,dy::Space)=ProductFun(f,TensorSpace(dx,dy))

ProductFun(f::Function,dx::Space,dy::Space)=ProductFun(f,TensorSpace(dx,dy))

## Domains promoted to Spaces

ProductFun(f::Function,D::Domain,M::Integer,N::Integer) = ProductFun(f,Space(D),M,N)
ProductFun(f::Function,d::Domain) = ProductFun(f,Space(d))
ProductFun(f::Function, dx::Domain{<:Number}, dy::Domain{<:Number}) = ProductFun(f,Space(dx),Space(dy))
ProductFun(f::Function) = ProductFun(f,ChebyshevInterval(),ChebyshevInterval())

## Conversion from other 2D Funs

ProductFun(f::LowRankFun; kw...) = ProductFun(coefficients(f),space(f,1),space(f,2); kw...)
function nzerofirst(itr, tol=0.0)
    n = 0
    for v in itr
        if all(iszero, v) || (tol == 0 ? false : isempty(chop(v, tol)))
            n += 1
        else
            break
        end
    end
    n
end
function ntrailingzerocols(A, tol=0.0)
    itr = (view(A, :, i) for i in reverse(axes(A,2)))
    nzerofirst(itr, tol)
end
function ntrailingzerorows(A, tol=0.0)
    itr = (view(A, i, :) for i in reverse(axes(A,1)))
    nzerofirst(itr, tol)
end
function ProductFun(f::Fun{<:AbstractProductSpace}; kw...)
    M = coefficientmatrix(f)
    nc = ntrailingzerocols(M)
    nr = ntrailingzerorows(M)
    A = @view M[1:max(1,end-nr), 1:max(1,end-nc)]
    ProductFun(A, space(f); kw...)
end

## Conversion to other ProductSpaces with the same coefficients

ProductFun(f::ProductFun,sp::TensorSpace)=space(f)==sp ? f : ProductFun(coefficients(f,sp),sp)
ProductFun(f::ProductFun{S,V,SS},sp::ProductDomain) where {S,V,SS<:TensorSpace}=ProductFun(f,Space(sp))

function ProductFun(f::ProductFun,sp::AbstractProductSpace)
    u=Array{VFun{typeof(columnspace(sp,1)),cfstype(f)}}(length(f.coefficients))

    for k=1:length(f.coefficients)
        u[k]=Fun(f.coefficients[k],columnspace(sp,k))
    end

    ProductFun(u,sp)
end

## For specifying spaces by anonymous function

ProductFun(f::Function,SF::Function,T::Space,M::Integer,N::Integer) =
    ProductFun(f,typeof(SF(1))[SF(k) for k=1:N],T,M)

## Conversion of a constant to a ProductFun

ProductFun(c::Number,sp::BivariateSpace) = ProductFun([Fun(c,columnspace(sp,1))],sp)
ProductFun(f::Fun,sp::BivariateSpace) = ProductFun([Fun(f,columnspace(sp,1))],sp)



## Utilities



function funlist2coefficients(f::Vector{VFun{S,T}}) where {S,T}
    A=zeros(T,mapreduce(ncoefficients,max,f,init=0),length(f))
    for k=1:length(f)
        A[1:ncoefficients(f[k]),k]=f[k].coefficients
    end
    A
end


function pad(f::ProductFun{S,V,SS,T},n::Integer,m::Integer) where {S,V,SS,T}
    ret=Array{VFun{S,T}}(undef, m)
    cm=min(length(f.coefficients),m)
    for k=1:cm
        ret[k]=pad(f.coefficients[k],n)
    end

    for k=cm+1:m
        ret[k] = zeros(columnspace(f,k))
    end
    ProductFun{S,V,SS,T}(ret,f.space)
end

function pad!(f::ProductFun{S,V,SS,T},::Colon,m::Integer) where {S,V,SS,T}
    cm=length(f.coefficients)
    resize!(f.coefficients,m)

    for k=cm+1:m
        f.coefficients[k]=zeros(columnspace(f,k))
    end
    f
end


coefficients(f::ProductFun)=funlist2coefficients(f.coefficients)

function coefficients(f::ProductFun, ox::Space, oy::Space)
    T=cfstype(f)
    m=size(f,1)
    B = zeros(T, m, length(f.coefficients))
    # convert in x direction
    #TODO: adaptively grow in x?
    for k=1:length(f.coefficients)
        B[:,k] = pad(coefficients(f.coefficients[k],ox), m)
    end

    sp = space(f)
    spf2 = factor(sp, 2)

    # convert in y direction
    for k=1:size(B,1)
        ccfs=coefficients(view(B,k,:), spf2, oy)
        if length(ccfs)>size(B,2)
            B=pad(B,size(B,1),length(ccfs))
        end
        B[k,1:length(ccfs)]=ccfs
        for j=length(ccfs)+1:size(B,2)
            B[k,j]=zero(T)
        end
    end

    B
end

(f::ProductFun)(x,y) = evaluate(f,x,y)
# ProductFun does only support BivariateFunctions, this function below just does not work
# (f::ProductFun)(x,y,z) = evaluate(f,x,y,z)

coefficients(f::ProductFun, ox::TensorSpace) = coefficients(f, factors(ox)...)




values(f::ProductFun{S,V,SS,T}) where {S,V,SS,T} = itransform!(space(f),coefficients(f))


vecpoints(f::ProductFun{S,V,SS},k) where {S,V,SS<:TensorSpace} = points(f.space[k],size(f,k))

space(f::ProductFun) = f.space
columnspace(f::ProductFun,k) = columnspace(space(f),k)

domain(f::ProductFun) = domain(f.space)
#domain(f::ProductFun,k)=domain(f.space,k)
canonicaldomain(f::ProductFun) = canonicaldomain(space(f))



function canonicalevaluate(f::ProductFun{S,V,SS,T},x::Number,::Colon) where {S,V,SS,T}
    cd = canonicaldomain(f)
    Fun(setdomain(factor(space(f),2),factor(cd,2)),
                    [setdomain(fc,factor(cd,1))(x) for fc in f.coefficients])
end
canonicalevaluate(f::ProductFun,x::Number,y::Number) = canonicalevaluate(f,x,:)(y)
canonicalevaluate(f::ProductFun{S,V,SS},x::Colon,y::Number) where {S,V,SS<:TensorSpace} =
    evaluate(transpose(f),y,:)  # doesn't make sense For general product fon without specifying space

canonicalevaluate(f::ProductFun,xx::AbstractVector,yy::AbstractVector) =
    transpose(hcat([evaluate(f,x,:)(yy) for x in xx]...))


evaluate(f::ProductFun,x,y) = canonicalevaluate(f,tocanonical(f,x,y)...)

# TensorSpace does not use map
evaluate(f::ProductFun{S,V,SS,T},x::Number,::Colon) where {S<:UnivariateSpace,V<:UnivariateSpace,SS<:TensorSpace,T} =
    Fun(factor(space(f),2),[g(x) for g in f.coefficients])

evaluate(f::ProductFun{S,V,SS,T},x::Number,y::Number) where {S<:UnivariateSpace,V<:UnivariateSpace,SS<:TensorSpace,T} =
    evaluate(f,x,:)(y)



evaluate(f::ProductFun,x) = evaluate(f,x...)

*(c::Number,f::F) where {F<:ProductFun} = F(c*f.coefficients,f.space)
*(f::ProductFun,c::Number) = c*f


function chop(f::ProductFun{S},es...) where S
    kend=size(f,2)
    while kend > 1 && isempty(chop(f.coefficients[kend].coefficients,es...))
        kend-=1
    end
    ret=VFun{S,cfstype(f)}[Fun(space(f.coefficients[k]),chop(f.coefficients[k].coefficients,es...)) for k=1:max(kend,1)]

    typeof(f)(ret,f.space)
end


##TODO: following assumes f is never changed....maybe should be deepcopy?
function +(f::F,c::Number) where F<:ProductFun
    cfs=copy(f.coefficients)
    cfs[1]+=c
    F(cfs,f.space)
end
+(c::Number,f::ProductFun) = f+c
-(f::ProductFun,c::Number) = f+(-c)
-(c::Number,f::ProductFun) = c+(-f)


function +(f::ProductFun,g::ProductFun)
    if f.space == g.space
        if size(f,2) >= size(g,2)
            @assert f.space==g.space
            cfs = copy(f.coefficients)
            for k=1:size(g,2)
                cfs[k]+=g.coefficients[k]
            end

            ProductFun(cfs,f.space)
        else
            g+f
        end
    else
        s=conversion_type(f.space,g.space)
        ProductFun(f,s)+ProductFun(g,s)
    end
end

-(f::ProductFun) = (-1)*f
-(f::ProductFun,g::ProductFun) = f+(-g)

*(B::Fun,f::ProductFun) = ProductFun(map(c->B*c,f.coefficients),space(f))
*(f::ProductFun,B::Fun) = transpose(B*transpose(f))


LowRankFun(f::ProductFun{S,V,SS}) where {S,V,SS<:TensorSpace} = LowRankFun(f.coefficients,factor(space(f),2))
LowRankFun(f::Fun) = LowRankFun(ProductFun(f))

function differentiate(f::ProductFun{S,V,SS},j::Integer) where {S,V,SS<:TensorSpace}
    if j==1
        df=map(differentiate,f.coefficients)
        ProductFun(df,space(first(df)),factor(space(f),2))
    else
        transpose(differentiate(transpose(f),1))
    end
end

# If the transpose of the space exists, then the transpose of the ProductFun exists
Base.transpose(f::ProductFun{S,V,SS,T}) where {S,V,SS,T} =
    ProductFun(transpose(coefficients(f)),transpose(space(f)))





for op in (:(Base.sin),:(Base.cos))
    @eval ($op)(f::ProductFun) =
        Fun(space(f),transform!(space(f),$op(values(pad(f,size(f,1)+20,size(f,2))))))
end

^(f::ProductFun,k::Integer) =
    Fun(space(f),transform!(space(f),values(pad(f,size(f,1)+20,size(f,2))).^k))

for op = (:(Base.real),:(Base.imag),:(Base.conj))
    @eval ($op)(f::ProductFun{S,V,SS}) where {S,V<:RealSpace,SS<:TensorSpace} =
        ProductFun(map($op,f.coefficients),space(f))
end

#For complex bases
Base.real(f::ProductFun{S,V,SS}) where {S,V,SS<:TensorSpace} =
    transpose(real(transpose(ProductFun(real(u.coefficients),space(u)))))-transpose(imag(transpose(ProductFun(imag(u.coefficients),space(u)))))
Base.imag(f::ProductFun{S,V,SS}) where {S,V,SS<:TensorSpace} =
    transpose(real(transpose(ProductFun(imag(u.coefficients),space(u)))))+transpose(imag(transpose(ProductFun(real(u.coefficients),space(u)))))



## Call LowRankFun version
# TODO: should cumsum and integrate return TensorFun or lowrankfun?
for op in (:(Base.sum),:(Base.cumsum),:integrate)
    @eval $op(f::ProductFun{S,V,SS},n...) where {S,V,SS<:TensorSpace} = $op(LowRankFun(f),n...)
end


## ProductFun transform

# function transform{ST<:Space,N<:Number}(::Type{N},S::Vector{ST},T::Space,V::AbstractMatrix)
#     @assert length(S)==size(V,2)
#     # We assume all S spaces have same domain/points
#     C=Vector{N}(size(V)...)
#     for k=1:size(V,1)
#         C[k,:]=transform(T,vec(V[k,:]))
#     end
#     for k=1:size(C,2)
#         C[:,k]=transform(S[k],C[:,k])
#     end
#     C
# end
# transform{ST<:Space,N<:Real}(S::Vector{ST},T::Space{Float64},V::AbstractMatrix{N})=transform(Float64,S,T,V)
# transform{ST<:Space}(S::Vector{ST},T::Space,V::AbstractMatrix)=transform(Complex{Float64},S,T,V)




for op in (:tocanonical,:fromcanonical)
    @eval $op(f::ProductFun,x...) = $op(space(f),x...)
end

zero(P::ProductFun) = ProductFun((x...)->zero(cfstype(P)), space(P))
one(P::ProductFun) = ProductFun((x...)->one(cfstype(P)), space(P))

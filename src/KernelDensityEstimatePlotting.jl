module KernelDensityEstimatePlotting

using Gadfly, Colors, Cairo, Fontconfig, Compose

export
  # Gadfly plotting functions
  plotKDE,
  plotKDEContour,
  drawPair,
  drawAllPairs,
  stackMarginals,
  vstackedPlots,
  drawHorDens,
  toggleYTicks,
  DOYTICKS

# Guide.manual_color_key("Legend", ["Points", "Line"], ["green", "deepskyblue"])

    DOYTICKS=true

    function toggleYTicks()
      global DOYTICKS
      DOYTICKS = DOYTICKS ? false : true
      return DOYTICKS
    end

    function draw1D!{T <: AbstractString}(bd::BallTreeDensity,
          bins::AbstractArray{Float64,1},
          e,
          c::T="deepskyblue",
          myStyle::T="";
          xlbl="X",
          legend=nothing,
          title::VoidUnion{T}=nothing,
          fill=false )
      #
      global DOYTICKS

      yV = evaluateDualTree(bd,bins)
      # clamp max y values
      yV[3.0 .< yV] = 3.0
      if e == nothing
        ptArr = Any[]

        l1 = Gadfly.layer(x=bins,y=yV,Geom.line, Gadfly.Theme(default_color=parse(Colorant,c),line_width=2pt))
        push!(ptArr, l1)
        push!(ptArr, Guide.xlabel(xlbl))
        if !DOYTICKS
          # e=Gadfly.plot(x=bins,y=yV,Geom.line, Gadfly.Theme(default_color=parse(Colorant,c)),Guide.xlabel(xlbl))
        # else
          push!(ptArr, Guide.ylabel(""))
          push!(ptArr,Guide.yticks(ticks=nothing))
          # e=Gadfly.plot(x=bins,y=yV,Geom.line, Gadfly.Theme(default_color=parse(Colorant,c)),Guide.xlabel(xlbl),Guide.ylabel(""),Guide.yticks(ticks=nothing))
        end
        if legend != nothing
          push!(ptArr, legend)
        end
        if title != nothing
          push!(ptArr, Guide.title(title))
        end

        e = Gadfly.plot(ptArr...)
      else
        push!(e.layers, layer(x=bins, y=yV, Geom.line, Gadfly.Theme(default_color=parse(Colorant,c),line_width=2pt))[1])
      end

      #mx = maximum(y)
      #wts = getWeights(bd)
      return e
    end


    function plotKDEContour{T <: AbstractString}(pp::Vector{BallTreeDensity};
        xmin=-Inf,xmax=Inf,ymin=-Inf,ymax=Inf,
        xlbl::T="x", ylbl::T="y",
        N::Int=200,
        c::VoidUnion{Vector{T}}=nothing,
        legend=nothing,
        title::VoidUnion{T}=nothing,
        levels::VoidUnion{Int}=nothing,
        fill=false )

      rangeV = getKDERange(pp[1])
      size(rangeV,1) == 2 ? nothing : error("plotKDEContour must receive two dimensional kde, you gave $(Ndim(x))")
      xmin = xmin != -Inf ? xmin : rangeV[1,1]
      xmax = xmax != Inf ? xmax : rangeV[1,2]
      ymin = ymin != -Inf ? ymin : rangeV[2,1]
      ymax = ymax != Inf ? ymax : rangeV[2,2]
      for i in 2:length(pp)
        rangeV = getKDERange(pp[i])
        xmin = xmin <= rangeV[1,1] ? xmin : rangeV[1,1]
        xmax = xmax >= rangeV[1,2] ? xmax : rangeV[1,2]
        ymin = ymin <= rangeV[2,1] ? ymin : rangeV[2,1]
        ymax = ymax >= rangeV[2,2] ? ymax : rangeV[2,2]
      end

      PL = []

      # default options
      CO = levels == nothing ? Geom.contour : Geom.contour(levels=levels)
      if c == nothing
        c = ["deepskyblue" for i in 1:length(pp)]
      else
        push!(PL, Gadfly.Scale.color_none)
      end
      # Gadfly.plot(

      i = 0
      for p in pp
        i+=1
        push!(PL, layer(z=(x,y)->evaluateDualTree(p,([x;y]')')[1],
        x=linspace(xmin,xmax,N),
        y=linspace(ymin,ymax,N),
        CO,
        Theme(default_color=parse(Colorant,c[i])))[1] )
      end

      push!(PL,Coord.Cartesian(xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax))
      push!(PL,Guide.xlabel(xlbl), Guide.ylabel(ylbl))

      # Might be a per layer theme
      !fill ? nothing : push!(PL, Theme(background_color=colorant"white"))

      if legend != nothing
        push!(PL, legend)
      end

      if title != nothing
        push!(PL, Guide.title(title))
      end

      Gadfly.plot(PL...)
    end
    # p1 = plot(
    #        layer(z=ff,x=linspace(-5,5,100),y=linspace(-5,5,100), Geom.contour(levels=5),Theme(default_color=parse(Colorant,"blue"))),
    #        layer(z=ff2,x=linspace(-5,5,100),y=linspace(-5,5,100), Geom.contour(levels=5),Theme(default_color=parse(Colorant,"red"))),
    #        Scale.color_none)


    function plotKDEContour{T <: AbstractString}(p::BallTreeDensity;
        xmin=-Inf,xmax=Inf,ymin=-Inf,ymax=Inf,
        xlbl::T="x", ylbl::T="y",
        N::Int=200,
        c::VoidUnion{Vector{T}}=nothing,
        legend=nothing,
        title::VoidUnion{T}=nothing,
        levels::VoidUnion{Int}=nothing,
        fill=false )

        plotKDEContour([p],
          xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,
          xlbl=xlbl, ylbl=ylbl,
          N=N,
          c=c,
          legend=legend,
          title=title,
          levels=levels,
          fill=fill )
    end

    function drawPair{T <: AbstractString}(xx::Vector{BallTreeDensity}, dims::Vector{Int};
        axis::VoidUnion{Array{Float64,2}}=nothing,
        dimLbls::VoidUnion{Vector{T}}=nothing,
        legend=nothing,
        title::VoidUnion{T}=nothing,
        levels::VoidUnion{Int}=nothing,
        c::VoidUnion{Vector{T}}=nothing,
        fill=false )
      # pts = getPoints(x);
      xmin, xmax, ymin, ymax = -Inf,Inf,-Inf,Inf
      if axis != nothing
        xmin, xmax, ymin, ymax = axis[dims[1],1], axis[dims[1],2], axis[dims[2],1], axis[dims[2],2]
      end

      xlbl, ylbl = nothing, nothing
      if dimLbls!=nothing
        xlbl, ylbl = dimLbls[dims[1]], dimLbls[dims[2]]
      end

      X = BallTreeDensity[]
      for x in xx
        push!(X, marginal(x,dims))
      end
      plotKDEContour(X,
        xmin=xmin,xmax=xmax,ymin=ymin,ymax=ymax,
        xlbl=xlbl,ylbl=ylbl,
        legend=legend,
        title=title,
        levels=levels,c=c, fill=fill  )
    end

    function stacking(spp::Vector{Compose.Context})
      hstack(spp...)
    end

    # function to draw all pairs of mulitdimensional kernel density estimate
    # axis is matrix with rows as dimensions and two columns for min and max axis cutoffs
    function drawAllPairs{T <: AbstractString}(xx::Vector{BallTreeDensity};
          dims::VoidUnion{VectorRange{Int}}=nothing,
          axis::VoidUnion{Array{Float64,2}}=nothing,
          dimLbls::VoidUnion{Vector{T}}=nothing,
          legend=nothing,
          title::VoidUnion{T}=nothing,
          levels::VoidUnion{Int}=nothing,
          c::VoidUnion{Vector{T}}=nothing,
          fill=false )

      # pts = getPoints(xx[1]);
      # e = [];
      dims = dims != nothing ? collect(dims) : collect(1:Ndim(xx[1]))
      Nout = length(dims);
      PlotI2 = triu(repmat( (dims)' ,Nout, 1), 1);
      PlotI1 = triu(repmat((dims)' , Nout, 1)', 1);
      PlotI1, PlotI2 = PlotI1[find(PlotI1)],  PlotI2[find(PlotI2)];
      Ncol = round(Int, sqrt(length(PlotI2)));
      Nrow = ceil(Int, length(PlotI2)/Ncol);

      subplots = Array{Gadfly.Plot,2}(Nrow,Ncol)
      for iT=1:length(PlotI2)
        subplots[iT] = drawPair(xx,[PlotI1[iT];PlotI2[iT]], axis=axis, dimLbls=dimLbls, legend=legend, title=title, levels=levels, c=c, fill=fill);
      end;

      Nrow==1 && Ncol==1 ? nothing : println("Multiple planes stacked into Compose.Context, use Gadfly.draw(PNG(file.png,10cm,10cm),plothdl). Or PDF.")
      hh = Vector{Gadfly.Context}(Nrow)
      for i in 1:Nrow
        sp = Compose.Context[]
        for j in 1:Ncol
          if Nrow == 1 && Ncol==1

          else
            try
              push!(sp,hstack(subplots[i,j])) # very hacky line, but Compose.Context and Gadfly.Plot not playing nice together in hstack
            catch e
              print("KDEPlotting01.jl/drawAllPairs -- supressing all exceptions for stacking empty contour plots")
              println(e)
              push!(sp,Gadfly.context())
            end
          end
        end
        hh[i] = stacking(sp) #hstack(sp) #subplots[i,:])
      end

      return Nrow==1 && Ncol==1 ? subplots[1,1] : vstack(hh...)
    end

    # function to draw all pairs of mulitdimensional kernel density estimate
    # axis is matrix with rows as dimensions and two columns for min and max axis cutoffs
    function plotKDE{T <: AbstractString}(darr::Array{BallTreeDensity,1};
          c::VoidUnion{Vector{T}}=nothing,
          N::Int=200,
          rmax=-Inf,rmin=Inf,  # should be deprecated
          axis::VoidUnion{Array{Float64,2}}=nothing,
          dims::VoidUnion{VectorRange{Int}}=nothing,
          xlbl::T="X", # to be deprecated
          title::VoidUnion{T}=nothing,
          legend::VoidUnion{Vector{T}}=nothing,
          dimLbls::VoidUnion{Vector{T}}=nothing,
          levels::VoidUnion{Int}=nothing,
          fill=false )


        # defaults
        defaultcolor = false
        if c==nothing
          c, defaultcolor = ["black"], true
        end
        c = (length(c)>=2) ? c : repmat(c,length(darr))
        lg = (legend == nothing) ? nothing : Guide.manual_color_key("Legend", legend, c)

        H = nothing
        i = 0

        Ndims = Ndim(darr[1])
        dim = dims!=nothing ? dims : 1:Ndims #.bt.dims
        dimLbls = dimLbls!=nothing ? dimLbls : String["$(i)" for i in 1:Ndims]
        dim = collect(dim)
        if length(dim) == 1
          for bd in darr
              i+=1
              mbd = marginal(bd,dim)
              rangeV = getKDERange(mbd)
              if (length(dim) == 1) # Ndim(bd)
                if rangeV[1] > rmin  rangeV[1] = rmin end
                if rmax > rangeV[2]  rangeV[2] = rmax end
                if axis!=nothing
                  di = dim[1]
                  if rangeV[1] > axis[di,1]  rangeV[1] = axis[di,1] end
                  if axis[di,2] > rangeV[2]  rangeV[2] = axis[di,2] end
                end
                H=draw1D!(mbd,linspace(rangeV[1],rangeV[2],N), H, c[i],xlbl=xlbl,legend=lg, title=title, fill=fill) #,argsPlot,argsKDE
              else
                #
              end
          end
        else
          color = defaultcolor ? nothing : c
          H = drawAllPairs(darr, axis=axis, dims=dim, dimLbls=dimLbls, legend=lg, title=title, levels=levels, c=color, fill=fill)
        end
        return H
    end


    function plotKDE{T <: AbstractString}(bd::BallTreeDensity;
          c::VoidUnion{Vector{T}}=nothing,
          N::Int=200,
          rmax=-Inf,rmin=Inf,  # should be deprecated
          axis::VoidUnion{Array{Float64,2}}=nothing,
          dims::VoidUnion{VectorRange{Int}}=nothing,
          xlbl::T="X",
          legend::VoidUnion{Vector{T}}=nothing,
          title::VoidUnion{T}=nothing,
          dimLbls::VoidUnion{Vector{T}}=nothing,
          levels::VoidUnion{Int}=nothing,
          fill=false )

      plotKDE([bd],N=N,c=c,rmax=rmax,rmin=rmin,xlbl=xlbl,legend=legend, dims=dims, axis=axis, dimLbls=dimLbls, levels=levels, title=title, fill=fill)
    end


    macro ifund(exp)
        local e = :($exp)
        isdefined(e.args[1]) ? :($(e.args[1])) : :($(esc(exp)))
    end

    function drawHorDens(pDens::Array{BallTreeDensity,1}; N::Int=200,
                        gt=Union{}, lbls=String[], extend::Float64=0.1)
        len = length(pDens)
        h = Array{Gadfly.Plot,1}(len)
        # r = Array{Future,1}(len) #Array{RemoteRef,1}(len)

        if gt!=Union{}
          for i in 1:length(pDens)
            g = kde!(gt[i][1,:],[gt[i][2,1]])
            v = getKDERange(pDens[i],extend=extend)
            p = plotKDE([pDens[i];g],c=["black";"red"],rmin=v[1],rmax=v[2],xlbl=lbls[i])
            h[i] =p;
          end
        else
          for i in 1:length(pDens)
             h[i]=plotKDE([pDens[i]],xlbl=lbls[i])
          end
        end
        #println("draw $(len) plots")
        # [r[i] = @spawn plotKDE(pDens[i], N=N) for i in 1:len]
        # [h[i] = fetch(r[i]) for i in 1:len]

        hstack(h)
    end

    function stackMarginals(P::Array{BallTreeDensity,1}, m::Int64)
      ret = Array{BallTreeDensity,1}(length(P))
      for i in 1:length(P)
        ret[i] =  marginal(P[i],[m])#push!()
      end
      return ret
    end


    function vstackedPlots(plots::Array{Gadfly.Compose.Context,1})
        evalstr = ""
        for i in 1:length(plots)
            evalstr = string(evalstr, ",plots[$(i)]")
        end
        evalstr = string("vstack(",evalstr[2:end],")")
        eval(parse(evalstr))
    end


end  # module

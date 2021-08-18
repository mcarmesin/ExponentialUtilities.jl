using GraphMatFun, LinearAlgebra


rhov=[0; 0.015; 0.25; 0.95; 2.1; 5.4];
for s=1:8
    push!(rhov, rhov[end]*2);
end


#rhov=rhov[1:3]


for i=1:(size(rhov,1)-1)
    r=(rhov[i]+rhov[i+1])/2;
    (graph,_)=graph_exp_native_jl(r)
    compress_graph!(graph);
    A=randn(3,3); A=r*A/opnorm(A,1)
    E1=eval_graph(graph,A)
    E2=exp(A);
    @show norm(E1)
    @show norm(E2)
    @show norm(E1-E2)/norm(E1);
    alloc_function=k-> "getmem(cache,$k)";
    lang=LangJulia(true,true,true,false,alloc_function,true)

    fname="exp_$(i).jl";
    gen_code(fname,graph,
             lang=lang,funname="exp_$(i)",precomputed_nodes=[:A]);


    # Post-processing
    lines=[];
    open(fname, "r") do infile
        lines=readlines(infile);
    end

    open(fname,"w") do outfile
        for (j,line) in enumerate(lines)
            line=replace(line,"exp_$(i)!(A" => "exp_gen!(cache,A,::Val{$(i)}");
            if (contains(line,"ValueOne")) # Not needed functionality
                continue;
            end
            # Make a LAPACK call instead of backslash
            line=replace(line, r"memslots(\d+)\s*.?=\s*memslots(\d+)..?memslots(\d+)" => s"LAPACK.gesv!(memslots\2, memslots\3); memslots\1=memslots\3")

            # Make sure the output is in A
            line=replace(line, r"return memslots(\d+)" => s"copyto!(A,memslots\1)")


            println(outfile,line);
        end
    end



end

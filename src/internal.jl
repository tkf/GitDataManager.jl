#=
@static if isdefined(Base.Experimental, Symbol("@optlevel"))
    Base.Experimental.@optlevel 0
end
=#

struct ApplicationError <: Exception
    showerror::Any
    summary::String
end

Base.showerror(io::IO, e::ApplicationError) = e.showerror(io)

function Base.show(io::IO, e::ApplicationError)
    show(io, ApplicationError)
    print(io, "(")
    show(io, e.summary)
    print(io, ", …)")
end

function (cli::Types.CLI)(args...; verbose::Integer = 1, kwargs...)
    # TODO: set logger level using `verbose`
    ans = try
        cli.api(args...; kwargs...)
    catch err
        if err isa ApplicationError
            showerror(stderr, err)
            println(stderr)
            exit(1)
        else
            rethrow()
        end
    end
    if ans !== nothing
        if verbose > 0
            display(ans)
            println()
        end
    end
end

function check_toplevel(dir)
    cmd = setenv(`git rev-parse --show-toplevel`; dir = dir)
    toplevel = try
        read(cmd, String)
    catch err
        @debug("Failed to call `read(cmd, String)` in `check_toplevel($(repr(dir)))`", cmd)
        err isa Union{Base.IOError,ProcessFailedException} || rethrow()
        nothing
    end
    if toplevel !== nothing
        realpath(chomp(toplevel)) == realpath(dir) && return
    end
    git_dir = joinpath(dir, ".git")
    git_dir_exist = isfile(git_dir) || isdir(git_dir)
    err = ApplicationError("failed: check_toplevel") do io
        print(io, "Not a Git repository: ", dir)
        if !git_dir_exist
            println(io)
            print(io, "`.git` directory does not exist")
        end
    end
    throw(err)
end

default_message() = "Update @$(gethostname())"

function git_is_clean(dir)
    output = read(setenv(`git status --porcelain`; dir = dir), String)
    return all(isspace, output)
end

function commit_impl(dir; message::AbstractString)
    git(cmd) = setenv(`$git $cmd`; dir = dir)
    check_toplevel(dir)
    if git_is_clean(dir)
        @info "Git repository `$dir` is clean. Nothing to commit."
        return false
    end
    run(git(`add .`))
    run(git(`commit --allow-empty-message --message $message`))
    return true
end

function API.commit(dir; message::AbstractString = default_message())
    commit_impl(dir; message = message)
    return
end

function API.upload(dir; merge::Bool = true, message::AbstractString = default_message())
    git(cmd) = setenv(`$git $cmd`; dir = dir)
    commit_impl(dir; message = message) || return
    if merge
        run(git(`pull --strategy=ours --no-edit`))
    end
    run(git(`push`))
    return
end

function eachstring(f, buf::AbstractVector{UInt8})
    i = firstindex(buf)
    for j in eachindex(buf)
        if iszero(@inbounds buf[j])
            f(String(buf[i:j-1]))
            i = j + 1
        end
    end
    if i < lastindex(buf)
        f(String(buf[i:end]))
    end
    return
end

function API.empty(dir)
    check_toplevel(dir)
    git(cmd) = setenv(`$git $cmd`; dir = dir)
    buf = read(git(`ls-files -z`))
    eachstring(buf) do path
        fullpath = joinpath(dir, path)
        isfile(fullpath) || return
        println(stderr, "Remove: ", path)
        rm(fullpath)
    end
    return
end

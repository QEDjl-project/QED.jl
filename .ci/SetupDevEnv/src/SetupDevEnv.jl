module SetupDevEnv

using TOML
using Pkg

"""
    extract_env_vars_from_git_message!()

Parse the commit message, if set via variable (usual `CI_COMMIT_MESSAGE`) and set custom URLs.
"""
function extract_env_vars_from_git_message!(var_name="CI_COMMIT_MESSAGE")
    if haskey(ENV, var_name)
        @info "Found env variable $var_name"
        for line in split(ENV[var_name], "\n")
            line = strip(line)
            if startswith(line, "CI_UNIT_PKG_URL_")
                (var_name, url) = split(line, ":"; limit=2)
                @info "add " * var_name * "=" * strip(url)
                ENV[var_name] = strip(url)
            end
        end
    end
end

"""
    get_dependencies(project_toml_path::AbstractString, package_prefix::Union{AbstractString,Regex}=r".*")::Set{AbstractString}

Parses a Project.toml located at `project_toml_path` and returns all dependencies, matching the regex `package_prefix`.
By default, the regex allows all dependencies.
"""
function get_dependencies(
    project_toml_path::AbstractString, package_prefix::Union{AbstractString,Regex}=r".*"
)::Set{AbstractString}
    project_toml = TOML.parsefile(project_toml_path)
    if !haskey(project_toml, "deps")
        return Set()
    end
    filtered_deps = filter(
        (dep_name) -> startswith(dep_name, package_prefix), keys(project_toml["deps"])
    )
    return filtered_deps
end

"""
    add_develop_dep(dependencies::Set{AbstractString})

Add all dependencies listed in `dependencies` as development version. By default, it takes the current development branch.
If the environment variable "CI_UNIT_PKG_URL_<dependency_name>" is set, take the URL defined in the value to set 
develop version, instead the the default develop branch (see `Pkg.develop(url=)`). 
"""
function add_develop_dep(dependencies::Set{AbstractString})
    # check if specific url was set for a dependency
    env_prefix = "CI_UNIT_PKG_URL_"
    modified_urls = Dict{String,String}()
    for (env_key, env_var) in ENV
        if startswith(env_key, env_prefix)
            modified_urls[env_key[(length(env_prefix) + 1):end]] = env_var
        end
    end

    if !isempty(modified_urls)
        local info_str = "Found following env variables"
        for (pkg_name, url) in modified_urls
            info_str *= "\n  " * pkg_name * "=" * url
        end
        @info info_str
    end

    # add all dependencies as develop version to the current julia environment
    for dep in dependencies
        if haskey(modified_urls, dep)
            split_url = split(modified_urls[dep], "#")
            if length(split_url) > 2
                error("Ill formed url: $(url)")
            end

            if length(split_url) == 1
                @info "Pkg.develop(url=\"" * split_url[1] * "\")"
                Pkg.add(; url=split_url[1])
            else
                @info "Pkg.develop(url=\"" *
                    split_url[1] *
                    ";\" rev=\"" *
                    split_url[2] *
                    "\")"
                Pkg.add(; url=split_url[1], rev=split_url[2])
            end
        else
            @info "Pkg.develop(\"" * dep * "\")"
            Pkg.develop(dep)
        end
    end
end

if abspath(PROGRAM_FILE) == @__FILE__
    if length(ARGS) < 1
        error("Set path to Project.toml as first argument.")
    end

    project_toml_path = ARGS[1]

    # custom commit message variable can be set as second argument
    if length(ARGS) < 2
        extract_env_vars_from_git_message!()
    else
        extract_env_vars_from_git_message!(ARGS[2])
    end
    # get only dependencies, which starts with QED
    deps = get_dependencies(project_toml_path, r"(QED)")
    add_develop_dep(deps)
end

end

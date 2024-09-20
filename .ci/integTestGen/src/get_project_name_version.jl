using Pkg

"""
    get_project_version_name()::Tuple{String,String}

# Return

Returns project name and version number
"""
function get_project_version_name()::Tuple{String,String}
    return (Pkg.project().name, string(Pkg.project().version))
end

# the script be directly executed in bash to set the environment variables
# $(julia --project=/path/to/the/actual/project get_project_version_name)
if abspath(PROGRAM_FILE) == @__FILE__
    (name, version) = get_project_version_name()
    println("export CI_DEPENDENCY_NAME=$(name)")
    println("export CI_DEPENDENCY_VERSION=$(version)")
end

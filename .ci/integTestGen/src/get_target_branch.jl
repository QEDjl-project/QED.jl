module getTargetBranch

using HTTP
using JSON

"""
    get_target_branch()::AbstractString

Returns the name of the target branch of the pull request. The function is required for our special
setup where we mirror a PR from GitHub to GitLab CI. No merge request will be open on GitLab.
Instead, a feature branch will be created and the commit will be pushed. As a result, we lose
information about the original PR. So we need to use the GitHub Rest API to get the information
depending on the repository name and PR number.
"""
function get_target_branch()::AbstractString
    # GitLab CI provides the environemnt variable with the following pattern
    # # pr-<PR number>/<repo owner of the source branch>/<project name>/<source branch name> 
    # e.g. pr-41/SimeonEhrig/QED.jl/setDevDepDeps
    if !haskey(ENV, "CI_COMMIT_REF_NAME")
        error("Environment variable CI_COMMIT_REF_NAME is not set.")
    end

    splited_commit_ref_name = split(ENV["CI_COMMIT_REF_NAME"], "/")

    if (!startswith(splited_commit_ref_name[1], "pr-"))
        error("CI_COMMIT_REF_NAME does not start with pr-")
    end

    # parse to Int only to check if it is a number
    pr_number = parse(Int, splited_commit_ref_name[1][(length("pr-") + 1):end])
    if (pr_number <= 0)
        error(
            "a PR number always needs to be a positive integer number bigger than 0: $pr_number",
        )
    end

    repository_name = splited_commit_ref_name[3]

    try
        headers = (
            ("Accept", "application/vnd.github+json"),
            ("X-GitHub-Api-Version", "2022-11-28"),
        )
        # in all cases, we assume that the PR targets the repositories in QEDjl-project
        # there is no environment variable with the information, if the target repository is
        # the upstream repository or a fork.
        url = "https://api.github.com/repos/QEDjl-project/$repository_name/pulls/$pr_number"
        response = HTTP.get(url, headers)
        response_text = String(response.body)
        repository_data = JSON.parse(response_text)
        return repository_data["base"]["ref"]
    catch e
        # if for unknown reason, the PR does not exist, use fallback the dev branch
        if isa(e, HTTP.Exceptions.StatusError) && e.status == 404
            return "dev"
        else
            # Only the HTML code 404, page does not exist is handled. All other error will abort
            # the script.  
            throw(e)
        end
    end

    return "dev"
end

if abspath(PROGRAM_FILE) == @__FILE__
    target_branch = get_target_branch()
    println(target_branch)
end

end

baremodule GitDataManager

module Types
struct CLI{API <: Function} <: Function
    api::API
end
end

module API
function commit end
function upload end
function empty end
end

"""
    GitDataManager.commit(dir; <keyword arguments>)

Commit files in the Git repository `dir`.

# Keyword Arguments
- `message = "Update @HOSTNAME"`: Commit message.
"""
const commit = Types.CLI(API.commit)

"""
    GitDataManager.upload(dir; <keyword arguments>)

Commit files in the Git repository `dir` and push it to remote.

# Keyword Arguments
- `merge = true`: Merge remote head if required.
- `message = "Update @HOSTNAME"`: Commit message.
"""
const upload = Types.CLI(API.upload)

"""
    GitDataManager.empty(dir)

Remove all tracked files in `dir`.
"""
const empty = Types.CLI(API.empty)

module Internal

using ..GitDataManager: API, GitDataManager, Types
using Sockets: gethostname

include("internal.jl")

end  # module Internal

end  # baremodule GitDataManager

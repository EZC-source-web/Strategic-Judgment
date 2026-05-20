function root = project_root()
%PROJECT_ROOT Detect the repository root from this utility file.

here = fileparts(mfilename('fullpath'));
root = here;

while true
    has_run_all = exist(fullfile(root, 'run_all.m'), 'file') == 2;
    has_config = exist(fullfile(root, 'config'), 'dir') == 7;
    has_git = exist(fullfile(root, '.git'), 'dir') == 7;

    if has_run_all && has_config
        return;
    end

    parent = fileparts(root);
    if strcmp(parent, root)
        break;
    end
    root = parent;
end

if has_git
    return;
end

error('project_root:NotFound', 'Could not locate repository root.');
end

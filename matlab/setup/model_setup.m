function p = model_setup(p)
%% determines what kind of setup is needed and does it.

narginchk(1,1)

% this is a top-level script, so be sure environment is setup
cwd = fileparts(mfilename('fullpath'));
if ~exist('is_file', 'file')
  run(fullfile(cwd, '../../setup.m'))
end
%% parse input
narginchk(1,1)
if isstruct(p)
  % pass
elseif ischar(p)
  % path to config.nml
  p = read_nml(p);
else
  error('model_setup:value_error', 'need path to config.nml')
end

if ~isfield(p, 'outdir')
  p.outdir = absolute_path(fileparts(p.indat_size));
end
makedir(p.outdir)
fprintf('copying config.nml to %s\n', p.outdir);
copy_file(p.nml, p.outdir)
%% allow output to new directory
if isfield(p, 'prec_dir')
  p.prec_dir = fullfile(p.outdir, path_tail(p.prec_dir));
end
if isfield(p, 'E0_dir')
  p.E0_dir = fullfile(p.outdir, path_tail(p.E0_dir));
end
%% is this equilibrium or interpolated simulation
if isfield(p, 'eqdir')
  model_setup_interp(p)
else
  model_setup_equilibrium(p)
end

if ~nargout, clear('p'), end
end % function

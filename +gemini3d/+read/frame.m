function dat = frame(filename, opts)
% frame(filename, cfg, vars)
% load a single time step of data
%
% example use
% dat = gemini3d.read.frame(filename)
% dat = gemini3d.read.frame(folder, "time", datetime)
% dat = gemini3d.read.frame(filename, "config", cfg)
% dat = gemini3d.read.frame(filename, "vars", vars)
%
% The "vars" argument allows loading a subset of variables.
% for example:
%
% gemini3d.read.frame(..., "ne")
% gemini3d.read.frame(..., ["ne", "Te"])

arguments
  filename (1,1) string
  opts.time datetime = datetime.empty
  opts.cfg struct = struct.empty
  opts.vars (1,:) string = string.empty
end

filename = gemini3d.fileio.expanduser(gemini3d.posix(filename));

if isfile(filename)
  dat = gemini3d.vis.loadframe(filename, struct.empty, opts.vars);
  return
end

assert(isfolder(filename), filename + " is not a file or folder")

if ~isempty(opts.time)
  dat = gemini3d.vis.loadframe(filename, opts.time, opts.vars);
elseif ~isempty(opts.cfg)
  dat = gemini3d.vis.loadframe(filename, opts.cfg, opts.vars);
else
  error("read.frame:value_error", "please specify filename or filename, datetime")
end

end

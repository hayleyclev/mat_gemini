function mag_map(direc)
arguments
  direc (1,1) string
end

direc = gemini3d.fileio.expanduser(direc);

%SIMULATIONS LOCAITON
pdir = fullfile(direc, "plots");
gemini3d.fileio.makedir(pdir)
basemagdir = fullfile(direc, 'magfields');

%SIMULATION META-DATA
cfg = gemini3d.read.config(direc);

%LOAD/CONSTRUCT THE FIELD POINT GRID

switch cfg.file_format
case 'h5'
  fn = fullfile(direc,'inputs/magfieldpoints.h5');
  assert(isfile(fn), fn + " not found")

  lpoints = h5read(fn, "/lpoints");
  r = h5read(fn, "/r");
  theta = double(h5read(fn, "/theta"));
  phi = double(h5read(fn, "/phi"));
case 'dat'
  fn = fullfile(direc,'inputs/magfieldpoints.dat');
  assert(isfile(fn), fn + " not found")

  fid=fopen(fn, 'r');
  lpoints=fread(fid,1,'integer*4');
  r=fread(fid,lpoints,'real*8');
  theta=fread(fid,lpoints,'real*8');    %by default these are read in as a row vector, AGHHHH!!!!!!!!!
  phi=fread(fid,lpoints,'real*8');
  fclose(fid);
otherwise, error("not sure how to read " + cfg.file_format + " files")
end

%REORGANIZE THE FIELD POINTS (PROBLEM-SPECIFIC)
ltheta=10;
lphi=10;
r=reshape(r(:),[ltheta,lphi]);
theta=reshape(theta(:),[ltheta,lphi]);
phi=reshape(phi(:),[ltheta,lphi]);
mlat=90-theta*180/pi;
[~,ilatsort]=sort(mlat(:,1));    %mlat runs against theta...
cfg.mlat=mlat(ilatsort,1);
mlon=phi*180/pi;
[~,ilonsort]=sort(mlon(1,:));
cfg.mlon=mlon(1,ilonsort);


%THESE DATA ARE ALMOST CERTAINLY NOT LARGE SO LOAD THEM ALL AT ONCE (CAN
%CHANGE THIS LATER).
% NOTE THAT THE DATA NEED TO BE SORTED BY MLAT,MLON AS WE GO
Brt=zeros(1,ltheta,lphi, length(cfg.times));
Bthetat=zeros(1,ltheta,lphi, length(cfg.times));
Bphit=zeros(1,ltheta,lphi, length(cfg.times));

for it=2:length(cfg.times)-1    %starts at second time step due to weird magcalc quirk
  filename = gemini3d.datelab(cfg.times(it));

  switch cfg.file_format
  case 'dat'
    fid=fopen(fullfile(basemagdir, filename + ".dat"), 'r');
    data = fread(fid,lpoints,'real*8');
  case 'h5'
    data = h5read(fullfile(direc,'magfields', filename + ".h5"), '/magfields/Br');
  end

  Brt(:,:,:,it)=reshape(data,[1,ltheta,lphi]);
  Brt(:,:,:,it)=Brt(:,ilatsort,:,it);
  Brt(:,:,:,it)=Brt(:,:,ilonsort,it);

  switch cfg.file_format
  case 'dat'
    data = fread(fid,lpoints,'real*8');
  case 'h5'
    data = h5read(fullfile(direc, 'magfields', filename + ".h5"), '/magfields/Btheta');
  end

  Bthetat(:,:,:,it)=reshape(data,[1,ltheta,lphi]);
  Bthetat(:,:,:,it)=Bthetat(:,ilatsort,:,it);
  Bthetat(:,:,:,it)=Bthetat(:,:,ilonsort,it);

  switch cfg.file_format
  case 'dat'
    data=fread(fid,lpoints,'real*8');
  case 'h5'
    data = h5read(fullfile(direc,'magfields', filename + ".h5"), '/magfields/Bphi');
  end

  Bphit(:,:,:,it)=reshape(data,[1,ltheta,lphi]);
  Bphit(:,:,:,it)=Bphit(:,ilatsort,:,it);
  Bphit(:,:,:,it)=Bphit(:,:,ilonsort,it);

  if exist("fid", "var")
    fclose(fid);
  end
end

%STORE THE DATA IN A MATLAB FILE FOR LATER USE
% save([direc,'/magfields_fort.mat'],'times','mlat','mlon','Brt','Bthetat','Bphit');


%INTERPOLATE TO HIGHER SPATIAL RESOLUTION FOR PLOTTING
llonp=200;
llatp=200;
mlonp=linspace(min(mlon(:)),max(mlon(:)),llonp);
mlatp=linspace(min(mlat(:)),max(mlat(:)),llatp);
[MLONP,MLATP]=meshgrid(mlonp,mlatp);
for it=1:length(cfg.times)
  param=interp2(cfg.mlon, cfg.mlat,squeeze(Brt(:,:,:,it)),MLONP,MLATP);
  Brtp(:,:,:,it)=reshape(param,[1, llonp, llatp]);
  param=interp2(cfg.mlon, cfg.mlat,squeeze(Bthetat(:,:,:,it)),MLONP,MLATP);
  Bthetatp(:,:,:,it)=reshape(param,[1, llonp, llatp]);
  param=interp2(cfg.mlon, cfg.mlat,squeeze(Bphit(:,:,:,it)),MLONP,MLATP);
  Bphitp(:,:,:,it)=reshape(param,[1, llonp, llatp]);
end
disp('...Done interpolating')

% mlatsrc=cfg.sourcemlat;
mlonsrc=cfg.sourcemlon;


%TABULATE THE SOURCE OR GRID CENTER LOCATION
if ~isempty(cfg.sourcemlat)
  %thdist= pi/2 - deg2rad(cfg.sourcemlat);    %zenith angle of source location
  %phidist = deg2rad(cfg.sourcemlon);
else
  thdist=mean(theta(:));
  phidist=mean(phi(:));
  cfg.sourcemlat = 90 - rad2deg(thdist);
  cfg.sourcemlon = rad2deg(phidist);
end


%MAKE THE PLOTS AND SAVE TO A FILE
FS=8;

coast = load('coastlines', 'coastlat', 'coastlon');
[thetacoast,phicoast] = gemini3d.geog2geomag(coast.coastlat, coast.coastlon);
cfg.mlatcoast=90-thetacoast*180/pi;
cfg.mloncoast=phicoast*180/pi;

if (360-mlonsrc<20)
  inds=find(cfg.mloncoast>180);
  cfg.mloncoast(inds)=cfg.mloncoast(inds)-360;
end

mlatlim=[min(mlatp),max(mlatp)];
mlonlim=[min(mlonp),max(mlonp)];
[cfg.MLAT, cfg.MLON]=meshgrat(mlatlim,mlonlim,[llonp, llatp]);

for it=1:length(cfg.times)-1
  filename = gemini3d.datelab(cfg.times(it));
  ttxt = datestr(cfg.times(it));

  disp("write: B*-" + filename + ".png")

  f1 = plotBr(Brtp(:,:,:,it), cfg, ttxt);
  exportgraphics(f1, fullfile(pdir, "Br-" + filename + ".png"), "resolution", 300)

  f2 = plotBtheta(Bthetatp(:,:,:,it), cfg, ttxt);
  exportgraphics(f2, fullfile(pdir,"Bth-" + filename + ".png"), "resolution", 300)

  f3 = plotBphi(Bphitp(:,:,:,it), cfg, ttxt);
  exportgraphics(f3, fullfile(pdir,"Bphi-" + filename + ".png"), "resolution", 300)

end % for

end % function


function fig = plotBr(Brtp, cfg, ttxt)

fig = figure(1);
clf(fig)

ax=axesm('MapProjection','Mercator','MapLatLimit',[min(cfg.mlat)-0.5, max(cfg.mlat)+0.5],'MapLonLimit',[min(cfg.mlon)-0.5,max(cfg.mlon)+0.5]);
param=squeeze(Brtp)*1e9;

pcolorm(cfg.MLAT, cfg.MLON, param, "parent", ax)

colormap(fig, gemini3d.plot.bwr());
% set(ax,'FontSize',FS)
tightmap
caxlim=max(abs(param(:)));
caxlim=max(caxlim,0.001);
caxis(ax, [-caxlim,caxlim]);
c=colorbar("peer", ax);
% set(c,'FontSize',FS)
title(ax, "B_r (nT)  " + ttxt + sprintf('\n\n'))
xlabel(ax, 'magnetic long. (deg.)')
ylabel(ax, sprintf('magnetic lat. (deg.)\n\n'))

plotm(cfg.sourcemlat, cfg.sourcemlon, 'r^','MarkerSize',6,'LineWidth',2, "parent", ax)

%ADD A MAP OF COASTLINES

plotm(cfg.mlatcoast, cfg.mloncoast,'k-','LineWidth',1, "parent", ax)
setm(ax,'MeridianLabel','on','ParallelLabel','on','MLineLocation',2,'PLineLocation',1,'MLabelLocation',2,'PLabelLocation',1);
gridm('on')

end % function


function fig = plotBtheta(Bthetatp, cfg, ttxt)

fig=figure(2);
clf(fig)

ax=axesm('MapProjection','Mercator','MapLatLimit',[min(cfg.mlat)-0.5,max(cfg.mlat)+0.5],'MapLonLimit',[min(cfg.mlon)-0.5,max(cfg.mlon)+0.5]);
param=squeeze(Bthetatp)*1e9;
pcolorm(cfg.MLAT, cfg.MLON, param, "parent", ax)
%     cmap=lbmap(256,'redblue');
%     cmap=flipud(cmap);
%     colormap(cmap);
colormap(fig, gemini3d.plot.bwr())
%set(ax,'FontSize',FS)
tightmap
caxlim=max(abs(param(:)));
caxlim=max(caxlim,0.001);
caxis(ax, [-caxlim,caxlim]);
c=colorbar("peer", ax);
%set(c,'FontSize',FS)
title(ax, "B_\theta (nT)  " + ttxt + sprintf('\n\n'))
xlabel(ax, 'magnetic long. (deg.)')
ylabel(ax, sprintf('magnetic lat. (deg.)\n\n'))

plotm(cfg.sourcemlat, cfg.sourcemlon,'r^','MarkerSize',6,'LineWidth',2, "parent", ax)

plotm(cfg.mlatcoast, cfg.mloncoast,'k-','LineWidth',1, "parent", ax)
setm(ax,'MeridianLabel','on','ParallelLabel','on','MLineLocation',2,'PLineLocation',1,'MLabelLocation',2,'PLabelLocation',1);
gridm("on")

end % function


function fig = plotBphi(Bphitp, cfg, ttxt)
fig=figure(3);
clf(fig)
ax=axesm('MapProjection','Mercator','MapLatLimit',[min(cfg.mlat)-0.5,max(cfg.mlat)+0.5],'MapLonLimit',[min(cfg.mlon)-0.5,max(cfg.mlon)+0.5]);
param=squeeze(Bphitp)*1e9;
%imagesc(mlon,mlat,param);
pcolorm(cfg.MLAT, cfg.MLON, param, "parent", ax)
%     cmap=lbmap(256,'redblue');
%     cmap=flipud(cmap);
%     colormap(cmap);
colormap(fig, gemini3d.plot.bwr())
%set(ax,'FontSize',FS)
tightmap
caxlim=max(abs(param(:)));
caxlim=max(caxlim,0.001);
caxis(ax, [-caxlim,caxlim])

c=colorbar("peer", ax);
%set(c,'FontSize',FS)
title(ax, "B_\phi (nT)  " + ttxt + sprintf('\n\n'));
xlabel(ax, 'magnetic long. (deg.)')
ylabel(ax, sprintf('magnetic lat. (deg.)\n\n'))

plotm(cfg.sourcemlat, cfg.sourcemlon, 'r^','MarkerSize',6,'LineWidth',2, "parent", ax)

plotm(cfg.mlatcoast, cfg.mloncoast,'k-','LineWidth',1, "parent", ax)
setm(ax,'MeridianLabel','on','ParallelLabel','on','MLineLocation',2,'PLineLocation',1,'MLabelLocation',2,'PLabelLocation',1);
gridm("on")

end % function

function ds = read_netcdf(filename)
%%%%%%%%%%%%%%%%%%%%
%     Read NetCDF data structure.
%     
% Parameters
% ------------
%     filename: string
%         Filename of NetCDF file to read.
%
% Returns
% ---------
%     ds: structure 
%         Structure from the binary instrument data
%        
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    % check to see if the filename input is a string
    if ~ischar(filename)
        ME = MException('MATLAB:read_nortek',['filename must be a ' ...
            'character string']);
        throw(ME);
    end
    
    % check to see if the file exists
    if ~isfile(filename)
        ME = MException('MATLAB:read_nortek','file does not exist');
        throw(ME);
    end

    ds = struct();

    % Get NetCDF info to populate the variable names
    info = ncinfo(filename);
    
    % Start with collecting the coords names  
    dim_size = numel(info.Dimensions);
    coords = cell(dim_size,1);
    for qq = 1:dim_size
        name = info.Dimensions(qq).Name;
        coords{qq} = name;
    end

    % Loop through the variables once to get the coords
    var_size = numel(info.Variables);
    for qq = 1:var_size
        name = info.Variables(qq).Name;
        dimensions = info.Variables(qq).Dimensions;
        sz = info.Variables(qq).Size;
        dtype = info.Variables(qq).Datatype;
        attrs = info.Variables(qq).Attributes;
        if any(strcmp(name,coords))
            % variable is a coordinate
            if strcmp(dtype, 'string')
                % if its a string then we read a string array
                ds.coords.(name) = ...
                    convertStringsToChars(ncread(filename,name));
            else
                % if its numeric and its length is 3 we change it to 4 to
                % account for the different dimensions between numpy and
                % matlab
                if dimensions.Length == 3
                    ds.coords.(name) = 1:4;
                else
                    if strcmpi(dimensions.Name, 'x*')
                        ds.coords.x_star = ncread(filename,name);
                    else
                        ds.coords.(name) = ncread(filename,name);
                    end
                end
            end  
            if numel(fieldnames(ds.coords)) == dim_size
                break
            end
        end
    end

    % Loop through the variables again to get the remaining data
    for qq = 1:var_size
        name = info.Variables(qq).Name;
        dimensions = info.Variables(qq).Dimensions;
        sz = info.Variables(qq).Size;
        attrs = info.Variables(qq).Attributes;
        if ~any(strcmp(name,coords))
            % variable goes in the main structure field
            if numel(sz) == 1
                % no modifications needed (the read function does it)
                ds.(name).data = ncread(filename,name);
                ds.(name).dims = cell(numel(dimensions),1);
                for kk = 1:numel(dimensions)
                    ds.(name).dims{kk} = dimensions(kk).Name;
                    ds.(name).coords.(dimensions(kk).Name) = ...
                        ds.coords.(dimensions(kk).Name);
                end
                if ~isempty(attrs)
                    for ii = 1:numel(attrs)
                        if strcmpi(attrs(ii).Name,'units')
                            ds.(name).units = attrs(ii).Value;
                        end
                    end
                end
            elseif numel(sz) == 2
                if contains(name, 'orientmat')
                    % no modifications needed 
                    ds.(name).data = ncread(filename,name);
                else
                    % Need to reshape the data
                    temp_dat = ncread(filename,name); 
                    tmp_shape = size(temp_dat);
                    tmp_shape = [tmp_shape(1),1,tmp_shape(2)];
                    temp_dat = reshape(temp_dat,tmp_shape);
                    ds.(name).data = temp_dat;
                end
                ds.(name).dims = cell(numel(dimensions),1);
                for kk = 1:numel(dimensions)
                    if strcmpi(dimensions(kk).Name, 'x*')
                        ds.(name).dims{kk} = 'x_star';
                        ds.(name).coords.x_star = ds.coords.x_star;
                    else
                        ds.(name).dims{kk} = dimensions(kk).Name;
                        ds.(name).coords.(dimensions(kk).Name) = ...
                            ds.coords.(dimensions(kk).Name);
                    end
                end
                if ~isempty(attrs)
                    for ii = 1:numel(attrs)
                        if strcmpi(attrs(ii).Name,'units')
                            ds.(name).units = attrs(ii).Value;
                        end
                    end
                end
            else
                % Need to reshape the data
                temp_dat = ncread(filename,name); 
                tmp_shape = size(temp_dat);
                tmp_shape = [tmp_shape(1),1,tmp_shape(2:3)];
                temp_dat = reshape(temp_dat,tmp_shape);
                ds.(name).data = temp_dat;
                ds.(name).dims = cell(numel(dimensions),1);
                for kk = 1:numel(dimensions)
                    if strcmpi(dimensions(kk).Name, 'x*')
                        ds.(name).dims{kk} = 'x_star';
                    else
                        ds.(name).dims{kk} = dimensions(kk).Name;
                    end
                    ds.(name).coords.(dimensions(kk).Name) = ...
                        ds.coords.(dimensions(kk).Name);
                end
                if ~isempty(attrs)
                    for ii = 1:numel(attrs)
                        if strcmpi(attrs(ii).Name,'units')
                            ds.(name).units = attrs(ii).Value;
                        end
                    end
                end                
            end
        end
    end

    % Finally grab the attributes
    for qq = 1:numel(info.Attributes)
        name = info.Attributes(qq).Name;
        value = info.Attributes(qq).Value;
        ds.attrs.(name) = value;
    end
    ds.coord_sys = ds.attrs.coord_sys;
    ds.time = ds.coords.time;

end

